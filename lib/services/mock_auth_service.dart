import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

/// Mock Authentication Service implementing [AuthService].
/// Provides isolated, in-memory credential verification, session management,
/// and predictable test states for Login, Register, and Profile screens without
/// requiring live Firebase connectivity.
class MockAuthService implements AuthService {
  static final MockAuthService _instance = MockAuthService._internal();
  factory MockAuthService() => _instance;

  /// Default Admin authorization code required for Admin self-registration.
  /// Prevents unrestricted elevated privilege creation in accordance with PRD and Issue #8.
  static const String validAdminPasscode = 'ADMIN-2026';

  AppUser? _currentUser;
  final Map<String, AppUser> _usersByEmail = {};
  final Map<String, String> _passwordsByEmail = {};

  final StreamController<AppUser?> _authStreamController =
      StreamController<AppUser?>.broadcast();

  MockAuthService._internal() {
    _seedDefaultAccounts();
    // Default initial state is unauthenticated (null), requiring explicit login.
    _currentUser = null;
  }

  void _seedDefaultAccounts() {
    // 1. Director Account
    const dirEmail = 'director@revo.in';
    final dirUser = AppUser(
      userId: 'usr_dir_101',
      name: 'Sarah Jenkins',
      email: dirEmail,
      role: UserRole.director,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    );
    _usersByEmail[dirEmail] = dirUser;
    _passwordsByEmail[dirEmail] = '1234567890';

    // 2. Cast Member Account
    const castEmail = 'cast@revo.in';
    final castUser = AppUser(
      userId: 'usr_cast_201',
      name: 'Alex Rivera',
      email: castEmail,
      role: UserRole.cast,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );
    _usersByEmail[castEmail] = castUser;
    _passwordsByEmail[castEmail] = '1234567890';

    // 3. Theatre Admin Account
    const adminEmail = 'admin@revo.in';
    final adminUser = AppUser(
      userId: 'usr_admin_301',
      name: 'Elena Rostova',
      email: adminEmail,
      role: UserRole.admin,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );
    _usersByEmail[adminEmail] = adminUser;
    _passwordsByEmail[adminEmail] = '1234567890';
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authStreamController.stream;
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
    // Simulate brief network latency for testing loading states (100ms)
    await Future.delayed(const Duration(milliseconds: 150));

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Email address and password cannot be empty.',
      );
    }

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Please enter a valid email address.',
      );
    }

    final user = _usersByEmail[cleanEmail];
    final storedPassword = _passwordsByEmail[cleanEmail];

    if (user == null || storedPassword != cleanPassword) {
      throw RevoException(
        RevoErrorCode.unauthorized,
        'Invalid email or password. Please verify your credentials and try again.',
      );
    }

    _currentUser = user;
    _authStreamController.add(_currentUser);
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle({UserRole defaultRole = UserRole.cast}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final defaultEmail = switch (defaultRole) {
      UserRole.director => 'director@revo.com',
      UserRole.admin => 'admin@revo.com',
      UserRole.cast => 'cast@revo.com',
    };
    final user = _usersByEmail[defaultEmail] ?? _usersByEmail.values.first;
    _currentUser = user;
    _authStreamController.add(_currentUser);
    return user;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.cast,
    String? adminPasscode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanName.isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Full name cannot be empty.',
      );
    }

    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Please enter a valid email address.',
      );
    }

    if (cleanPassword.length < 6) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Password must be at least 6 characters long.',
      );
    }

    // Duplicate email validation
    if (_usersByEmail.containsKey(cleanEmail)) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'An account with this email address already exists. Please sign in instead.',
      );
    }

    // Role-based admin restriction check
    if (role == UserRole.admin) {
      final code = (adminPasscode ?? '').trim();
      if (code != validAdminPasscode) {
        throw RevoException(
          RevoErrorCode.unauthorized,
          'Admin self-registration requires the valid administrative authorization code ($validAdminPasscode).',
        );
      }
    }

    final newUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = AppUser(
      userId: newUserId,
      name: cleanName,
      email: cleanEmail,
      role: role,
      createdAt: DateTime.now(),
    );

    _usersByEmail[cleanEmail] = newUser;
    _passwordsByEmail[cleanEmail] = cleanPassword;

    _currentUser = newUser;
    _authStreamController.add(_currentUser);
    return newUser;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 50));
    _currentUser = null;
    _authStreamController.add(null);
  }

  /// Switch the active user's role in-memory for testing role-based UI transitions.
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

  /// Helper to reset in-memory state to unauthenticated baseline for tests.
  void reset() {
    _currentUser = null;
    _usersByEmail.clear();
    _passwordsByEmail.clear();
    _seedDefaultAccounts();
    _authStreamController.add(null);
  }
}
