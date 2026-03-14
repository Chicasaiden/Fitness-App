import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../user.dart';

/// Service that wraps Firebase Auth and manages user authentication.
///
/// This replaces the old UserRepository. Firebase handles:
/// - Secure password storage (hashed + salted, never plaintext)
/// - Session persistence (stays logged in across app restarts)
/// - Email/password, Google Sign-In, and password reset flows
class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Reactive auth state ──────────────────────────────────────────────
  // This is a Stream that emits whenever the user logs in or out.
  // In main.dart we use a StreamBuilder on this to switch between
  // the login page and the home page automatically.
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// The currently logged-in Firebase user, or null.
  firebase_auth.User? get currentFirebaseUser => _auth.currentUser;

  /// Convenience: get our app's User model from the Firebase user.
  User? get currentUser {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return User(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ?? '',
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  // ── Email & Password ─────────────────────────────────────────────────

  /// Create a new account with email, password, and display name.
  /// Firebase automatically hashes the password — we never store it.
  /// On success, creates a user profile document in Firestore.
  Future<User?> createAccount(
    String email,
    String password,
    String displayName,
  ) async {
    // Firebase creates the account and immediately logs the user in
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Set the display name on the Firebase user profile
    await credential.user?.updateDisplayName(displayName);

    // Create a user document in Firestore for app-specific data
    if (credential.user != null) {
      await _createUserDocument(credential.user!, displayName);
    }

    return currentUser;
  }

  /// Update the display name for the current user.
  Future<void> updateDisplayName(String newName) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw Exception('No user logged in.');

    // Update Firebase Auth profile
    await fbUser.updateDisplayName(newName);

    // Update Firestore document
    await _createUserDocument(fbUser, newName);
  }

  /// Sign in with an existing email and password.
  Future<User?> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return currentUser;
  }

  // ── Google Sign-In ───────────────────────────────────────────────────
  // OAuth flow: Google confirms the user's identity and gives us a token.
  // We pass that token to Firebase Auth, which creates/links the account.

  /// Sign in with Google. Opens the Google Sign-In flow.
  Future<User?> signInWithGoogle() async {
    // Step 1: Google shows their sign-in screen
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    // Step 2: Get the authentication tokens from Google
    final googleAuth = await googleUser.authentication;

    // Step 3: Create a Firebase credential from Google's tokens
    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Step 4: Sign into Firebase with the Google credential
    final userCredential = await _auth.signInWithCredential(credential);

    // Create Firestore doc if this is a first-time Google sign-in
    if (userCredential.user != null) {
      await _createUserDocument(
        userCredential.user!,
        userCredential.user!.displayName ?? '',
      );
    }

    return currentUser;
  }

  // ── Apple Sign-In ────────────────────────────────────────────────────
  // Mandatory for iOS apps that offer alternative social logics (like Google)
  
  /// Sign in with Apple. Opens the native Apple Sign-In sheet.
  Future<User?> signInWithApple() async {
    // Step 1: Request credential from Apple
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    // Step 2: Create a Firebase credential from Apple's tokens
    final oauthCredential = firebase_auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    // Step 3: Sign into Firebase
    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Create Firestore doc if this is a first-time sign-in
    if (userCredential.user != null) {
      // Apple only gives the display name on the very first sign in.
      String displayName = userCredential.user!.displayName ?? '';
      if (displayName.isEmpty && appleCredential.givenName != null) {
        displayName = '${appleCredential.givenName} ${appleCredential.familyName}'.trim();
      }
      if (displayName.isEmpty) displayName = 'Apple User';

      await _createUserDocument(userCredential.user!, displayName);
    }

    return currentUser;
  }

  // ── Password Reset ───────────────────────────────────────────────────

  /// Send a password reset email. Firebase handles the email, the link,
  /// and the reset form — you don't need to build any of that.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Sign Out ─────────────────────────────────────────────────────────

  /// Sign out from both Firebase and Google (if they used Google Sign-In).
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Account Deletion ─────────────────────────────────────────────────
  //
  // Firebase requires the user to have authenticated recently before
  // deleting their account. If the token is stale we get a
  // requires-recent-login error — we re-authenticate first, then delete.

  /// Permanently deletes the account and all associated Firestore data.
  ///
  /// [password] should be provided for email/password accounts.
  /// For Google accounts, pass null — the method will re-authenticate via
  /// the Google Sign-In flow automatically.
  ///
  /// Throws a [DeleteAccountException] with a human-readable message on failure.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw DeleteAccountException('No user logged in.');

    try {
      // ── Step 1: Re-authenticate to satisfy Firebase's recency requirement
      await _reauthenticate(user, password: password);

      // ── Step 2: Delete all Firestore data for this user
      await _deleteAllUserData(user.uid);

      // ── Step 3: Delete the Firebase Auth account
      await user.delete();

      // ── Step 4: Sign out cleanly
      await _googleSignIn.signOut();
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw DeleteAccountException(_authErrorMessage(e.code));
    }
  }

  Future<void> _reauthenticate(
    firebase_auth.User user, {
    String? password,
  }) async {
    // Determine sign-in provider
    final providers = user.providerData.map((p) => p.providerId).toList();

    if (providers.contains('google.com')) {
      // Re-authenticate via Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw DeleteAccountException('Re-authentication cancelled.');
      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providers.contains('password')) {
      // Re-authenticate via email + password
      if (password == null || password.isEmpty) {
        throw DeleteAccountException('Please enter your password to confirm.');
      }
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      throw DeleteAccountException('Unknown sign-in provider.');
    }
  }

  /// Deletes all subcollections and the root user document.
  Future<void> _deleteAllUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    // Delete workouts subcollection
    await _deleteCollection(userRef.collection('workouts'));

    // Delete plans subcollection
    await _deleteCollection(userRef.collection('plans'));

    // Delete the user document itself
    await userRef.delete();
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> ref) async {
    const batchSize = 100;
    while (true) {
      final snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Create a user profile document in Firestore.
  Future<void> _createUserDocument(
    firebase_auth.User fbUser,
    String displayName,
  ) async {
    final userDoc = _firestore.collection('users').doc(fbUser.uid);
    await userDoc.set({
      'email': fbUser.email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Thrown by [AuthService.deleteAccount] with a user-readable message.
class DeleteAccountException implements Exception {
  final String message;
  const DeleteAccountException(this.message);
  @override
  String toString() => message;
}
