import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'mock_auth_service.dart';

/// Firebase Authentication Service adapter.
/// Currently delegates to [MockAuthService] for Issue #8 isolated mock auth
/// workflows, and serves as the designated injection point for future
/// production Firebase Authentication integration without touching UI screens.
class FirebaseAuthService implements AuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final MockAuthService _mockAuth = MockAuthService();

  @override
  Stream<AppUser?> authStateChanges() {
    return _mockAuth.authStateChanges();
  }

  @override
  Future<AppUser?> currentUser() async {
    return _mockAuth.currentUser();
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    return _mockAuth.login(email: email, password: password);
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.cast,
    String? adminPasscode,
  }) async {
    return _mockAuth.register(
      name: name,
      email: email,
      password: password,
      role: role,
      adminPasscode: adminPasscode,
    );
  }

  @override
  Future<void> logout() async {
    await _mockAuth.logout();
  }

  /// Helper method for UI role switching during testing & baseline evidence review
  void switchUserRole(UserRole newRole) {
    _mockAuth.switchUserRole(newRole);
  }
}
