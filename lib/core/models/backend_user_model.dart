import 'package:equatable/equatable.dart';

class BackendUser extends Equatable {
  final int id;
  final String email;
  final String name;
  final String? photoUrl;
  final bool isEmailVerified;
  final String authProvider;
  final String role;
  final String? createdAt;
  final String? lastLogin;

  const BackendUser({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.isEmailVerified,
    required this.authProvider,
    required this.role,
    this.createdAt,
    this.lastLogin,
  });

  // For compatibility with existing code expecting Firebase User
  String get uid => id.toString();
  String get displayName => name;
  String? get photoURL => photoUrl;
  bool get emailVerified => isEmailVerified;

  // Create from JSON data
  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      photoUrl: json['photoUrl'],
      isEmailVerified: json['isEmailVerified'] ?? false,
      authProvider: json['authProvider'] ?? 'email',
      role: json['role'] ?? 'user',
      createdAt: json['createdAt'],
      lastLogin: json['lastLogin'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'authProvider': authProvider,
      'role': role,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
    };
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        photoUrl,
        isEmailVerified,
        authProvider,
        role,
        createdAt,
        lastLogin,
      ];

  @override
  String toString() {
    return 'BackendUser(id: $id, email: $email, name: $name, role: $role)';
  }
}