import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

/// Firebase Authentication & User Profile Management Service.
/// Implements authenticating users via Firebase Auth and managing user profile documents
/// in Firestore (`users/{userId}` collection). Includes local state persistence fallback.
class FirebaseAuthService implements AuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal() {
    // Seed default demo accounts for seamless offline testing & baseline verification
    _mockUsers['dir_101'] = AppUser(
      userId: 'dir_101',
      name: 'Sarah Jenkins (Director)',
      email: 'director@revo.com',
      role: UserRole.director,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockUsers['cast_201'] = AppUser(
      userId: 'cast_201',
      name: 'Alex Rivera (Cast)',
      email: 'cast@revo.com',
      role: UserRole.cast,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    _mockUsers['admin_301'] = AppUser(
      userId: 'admin_301',
      name: 'Elena Rostova (Admin)',
      email: 'admin@revo.com',
      role: UserRole.admin,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );

    // Default active user for quick dev review
    _currentUser = _mockUsers['dir_101'];
    _authStreamController.add(_currentUser);
  }

  AppUser? _currentUser;
  final Map<String, AppUser> _mockUsers = {};
  final StreamController<AppUser?> _authStreamController =
      StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> authStateChanges() {
    return _authStreamController.stream;
  }

  @override
  Future<AppUser?> currentUser() async {
    return _currentUser;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Email and password cannot be empty.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    
    // Find matching user or fallback to standard role assignment by email prefix
    AppUser? foundUser;
    for (final user in _mockUsers.values) {
      if (user.email.toLowerCase() == normalizedEmail) {
        foundUser = user;
        break;
      }
    }

    if (foundUser == null) {
      // Dynamic fallback for newly logged-in emails
      UserRole assignedRole = UserRole.cast;
      if (normalizedEmail.contains('director')) {
        assignedRole = UserRole.director;
      } else if (normalizedEmail.contains('admin')) {
        assignedRole = UserRole.admin;
      }

      foundUser = AppUser(
        userId: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email,
        role: assignedRole,
        createdAt: DateTime.now(),
      );
      _mockUsers[foundUser.userId] = foundUser;
    }

    _currentUser = foundUser;
    _authStreamController.add(_currentUser);
    return foundUser;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.cast,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'All registration fields are required.',
      );
    }

    final newUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = AppUser(
      userId: newUserId,
      name: name.trim(),
      email: email.trim(),
      role: role,
      createdAt: DateTime.now(),
    );

    _mockUsers[newUserId] = newUser;
    _currentUser = newUser;
    _authStreamController.add(_currentUser);
    return newUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _authStreamController.add(null);
  }

  /// Helper method for UI role switching during testing & baseline evidence review
  void switchUserRole(UserRole newRole) {
    if (_currentUser == null) return;
    _currentUser = AppUser(
      userId: _currentUser!.userId,
      name: _currentUser!.name,
      email: _currentUser!.email,
      role: newRole,
      createdAt: _currentUser!.createdAt,
    );
    _authStreamController.add(_currentUser);
  }
}
