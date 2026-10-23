import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/enums/revo_enums.dart';

class AppUser {
  final String userId;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': switch (role) {
        UserRole.director => 'DIRECTOR',
        UserRole.admin => 'ADMIN',
        UserRole.cast => 'CAST_MEMBER',
      },
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    final parsedRole = switch (map['role']?.toString().trim().toUpperCase()) {
      'DIRECTOR' => UserRole.director,
      'ADMIN' => UserRole.admin,
      'CAST' || 'CAST_MEMBER' => UserRole.cast,
      _ => throw FormatException('User profile has an invalid role.'),
    };
    return AppUser(
      userId: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: parsedRole,
      createdAt: _parseCreatedAt(map['createdAt']),
    );
  }

  static DateTime _parseCreatedAt(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value == null) return DateTime.now();
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }
}
