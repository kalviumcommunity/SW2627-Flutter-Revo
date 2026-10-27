import '../core/enums/revo_enums.dart';
import '../models/app_user.dart';

abstract class UserRepository {
  Stream<List<AppUser>> watchUsers({UserRole? role}); // Admin
  Future<void> setRole(String userId, UserRole role); // Admin
  Future<AppUser> getUser(String userId);
}
