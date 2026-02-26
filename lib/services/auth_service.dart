import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Create a user profile document in Firestore.
  /// Uses `set` with merge so it won't overwrite if it already exists
  /// (important for Google Sign-In where user might sign in again).
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
