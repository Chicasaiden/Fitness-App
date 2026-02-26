/// App user model — maps to a Firebase Auth user + Firestore profile.
///
/// Notice there's NO password field anymore!
/// Firebase Auth stores passwords securely on their servers.
/// We only keep the info we need to display in the UI.
class User {
  /// Firebase UID — automatically assigned when the account is created.
  /// This is the unique key used throughout Firestore (users/{id}/...).
  final String id;

  /// User's email address — used for login and password reset.
  final String email;

  /// Display name shown in the app (e.g., "Hi Aiden,").
  final String displayName;

  /// When the account was created.
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  /// Convert to a Map for Firestore storage.
  /// Firestore stores documents as key-value maps — essentially JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a User from a Firestore document map.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
