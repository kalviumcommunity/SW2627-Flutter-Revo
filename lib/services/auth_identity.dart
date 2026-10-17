import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import 'auth_service.dart';

class AuthIdentity {
  const AuthIdentity({
    required this.userId,
    required this.role,
    this.isFirebaseAuthenticated = false,
  });

  final String userId;
  final UserRole? role;
  final bool isFirebaseAuthenticated;
}

abstract class AuthIdentityProvider {
  Future<AuthIdentity?> currentIdentity();
}

String normalizeRole(Object? value) {
  switch (value?.toString().trim().toUpperCase()) {
    case 'DIRECTOR':
      return 'DIRECTOR';
    case 'ADMIN':
      return 'ADMIN';
    case 'CAST':
    case 'CAST_MEMBER':
      return 'CAST_MEMBER';
    default:
      return '';
  }
}

UserRole? userRoleFromValue(Object? value) {
  switch (normalizeRole(value)) {
    case 'DIRECTOR':
      return UserRole.director;
    case 'ADMIN':
      return UserRole.admin;
    case 'CAST_MEMBER':
      return UserRole.cast;
    default:
      return null;
  }
}

AuthIdentity firebaseIdentityFromProfile({
  required String userId,
  required bool exists,
  required Map<String, dynamic>? data,
}) {
  final role = userRoleFromValue(data?['role']);
  if (!exists || data == null || role == null) {
    throw RevoException(
      RevoErrorCode.permissionDenied,
      'Authenticated user profile is missing or has an invalid role.',
    );
  }
  return AuthIdentity(
    userId: userId,
    role: role,
    isFirebaseAuthenticated: true,
  );
}

class AuthServiceIdentityProvider implements AuthIdentityProvider {
  const AuthServiceIdentityProvider(this.authService);

  final AuthService authService;

  @override
  Future<AuthIdentity?> currentIdentity() async {
    final user = await authService.currentUser();
    if (user == null) {
      return null;
    }
    return AuthIdentity(userId: user.userId, role: user.role);
  }
}

class FirebaseAuthIdentityProvider implements AuthIdentityProvider {
  const FirebaseAuthIdentityProvider({
    required this.auth,
    required this.firestore,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  @override
  Future<AuthIdentity?> currentIdentity() async {
    final user = auth.currentUser;
    if (user == null) {
      return null;
    }
    final profile = await firestore.collection('users').doc(user.uid).get();
    return firebaseIdentityFromProfile(
      userId: user.uid,
      exists: profile.exists,
      data: profile.data(),
    );
  }
}
