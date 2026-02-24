class User {
  final String id;
  final String username;
  final String password;
  final String? email; // Placeholder for future authentication
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.password,
    this.email,
    required this.createdAt,
  });

  /// Convert User to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
