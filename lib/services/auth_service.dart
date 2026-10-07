import '../core/enums/revo_enums.dart';
import '../models/app_user.dart';

abstract class AuthService {
  Stream<AppUser?> authStateChanges(); // null = signed out
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.cast,
  });
  Future<AppUser> login({
    required String email,
    required String password,
  });
  Future<void> logout();
  Future<AppUser?> currentUser(); // includes role from users/{uid}
}
