import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/errors/revo_exception.dart';
import 'package:sw2627_flutter_revo_1/services/mock_auth_service.dart';

void main() {
  group('MockAuthService Unit Tests', () {
    late MockAuthService authService;

    setUp(() {
      authService = MockAuthService();
      authService.reset();
    });

    test('Initial state is unauthenticated (null currentUser)', () async {
      final user = await authService.currentUser();
      expect(user, isNull);
    });

    test('Valid mock login succeeds for Director', () async {
      final user = await authService.login(
        email: 'director@revo.com',
        password: 'password123',
      );

      expect(user.email, 'director@revo.com');
      expect(user.role, UserRole.director);
      expect(user.name, 'Sarah Jenkins');

      final current = await authService.currentUser();
      expect(current?.userId, user.userId);
    });

    test('Valid mock login succeeds for Cast Member and Admin', () async {
      final cast = await authService.login(
        email: 'cast@revo.com',
        password: 'password123',
      );
      expect(cast.role, UserRole.cast);

      final admin = await authService.login(
        email: 'admin@revo.com',
        password: 'password123',
      );
      expect(admin.role, UserRole.admin);
    });

    test('Login with empty email or password throws RevoException', () async {
      expect(
        () => authService.login(email: '', password: 'password123'),
        throwsA(isA<RevoException>()),
      );
      expect(
        () => authService.login(email: 'director@revo.com', password: ''),
        throwsA(isA<RevoException>()),
      );
    });

    test('Login with invalid credentials throws unauthorized RevoException', () async {
      expect(
        () => authService.login(
          email: 'unknown@theatre.org',
          password: 'password123',
        ),
        throwsA(isA<RevoException>()),
      );

      expect(
        () => authService.login(
          email: 'director@revo.com',
          password: 'wrongpassword',
        ),
        throwsA(isA<RevoException>()),
      );
    });

    test('Registration creates new user and sets currentUser', () async {
      final newUser = await authService.register(
        name: 'David Tennant',
        email: 'david@theatre.org',
        password: 'secret123',
        role: UserRole.cast,
      );

      expect(newUser.name, 'David Tennant');
      expect(newUser.email, 'david@theatre.org');
      expect(newUser.role, UserRole.cast);

      final current = await authService.currentUser();
      expect(current?.email, 'david@theatre.org');
    });

    test('Registration rejects duplicate email addresses', () async {
      expect(
        () => authService.register(
          name: 'Imposter',
          email: 'director@revo.com',
          password: 'password123',
          role: UserRole.director,
        ),
        throwsA(isA<RevoException>()),
      );
    });

    test('Registration rejects password shorter than 6 characters', () async {
      expect(
        () => authService.register(
          name: 'Short Pass',
          email: 'short@theatre.org',
          password: '123',
          role: UserRole.cast,
        ),
        throwsA(isA<RevoException>()),
      );
    });

    test('Admin registration requires valid authorization passcode', () async {
      // Missing or wrong passcode fails
      expect(
        () => authService.register(
          name: 'Unauthorized Admin',
          email: 'unauth@theatre.org',
          password: 'secret123',
          role: UserRole.admin,
          adminPasscode: 'WRONG_CODE',
        ),
        throwsA(isA<RevoException>()),
      );

      // Correct passcode succeeds
      final adminUser = await authService.register(
        name: 'Authorized Admin',
        email: 'auth_admin@theatre.org',
        password: 'secret123',
        role: UserRole.admin,
        adminPasscode: MockAuthService.validAdminPasscode,
      );
      expect(adminUser.role, UserRole.admin);
    });

    test('Logout clears authenticated session and emits null', () async {
      await authService.login(
        email: 'director@revo.com',
        password: 'password123',
      );
      expect(await authService.currentUser(), isNotNull);

      await authService.logout();
      expect(await authService.currentUser(), isNull);
    });

    test('switchUserRole changes the active user role', () async {
      await authService.login(
        email: 'director@revo.com',
        password: 'password123',
      );
      expect((await authService.currentUser())?.role, UserRole.director);

      authService.switchUserRole(UserRole.cast);
      expect((await authService.currentUser())?.role, UserRole.cast);
    });
  });
}
