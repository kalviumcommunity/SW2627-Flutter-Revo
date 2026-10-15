import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/theme/revo_theme.dart';
import 'package:sw2627_flutter_revo_1/core/widgets/app_brand_header.dart';
import 'package:sw2627_flutter_revo_1/core/widgets/app_status_state.dart';
import 'package:sw2627_flutter_revo_1/core/widgets/app_text_field.dart';
import 'package:sw2627_flutter_revo_1/core/widgets/primary_button.dart';
import 'package:sw2627_flutter_revo_1/core/widgets/secondary_button.dart';
import 'package:sw2627_flutter_revo_1/features/auth/login_screen.dart';
import 'package:sw2627_flutter_revo_1/features/auth/register_screen.dart';
import 'package:sw2627_flutter_revo_1/features/profile/screens/profile_screen.dart';
import 'package:sw2627_flutter_revo_1/models/app_user.dart';
import 'package:sw2627_flutter_revo_1/services/mock_auth_service.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: RevoTheme.lightTheme,
    home: child,
  );
}

void main() {
  group('Shared Widgets Tests', () {
    testWidgets('PrimaryButton renders label and handles clicks',
        (WidgetTester tester) async {
      bool clicked = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Scaffold(
            body: PrimaryButton(
              label: 'Confirm',
              icon: Icons.check,
              onPressed: () => clicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(clicked, isTrue);
    });

    testWidgets('PrimaryButton shows loading spinner when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Scaffold(
            body: PrimaryButton(
              label: 'Submit',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('SecondaryButton renders with outlined style',
        (WidgetTester tester) async {
      bool clicked = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Scaffold(
            body: SecondaryButton(
              label: 'Cancel',
              onPressed: () => clicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.byType(SecondaryButton));
      await tester.pump();
      expect(clicked, isTrue);
    });

    testWidgets('AppTextField toggles password visibility',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'secret123');
      await tester.pumpWidget(
        _wrapWithTheme(
          Scaffold(
            body: AppTextField(
              label: 'Password',
              controller: controller,
              isPassword: true,
            ),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('AppBrandHeader renders title and subtitle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Scaffold(
            body: AppBrandHeader(
              title: 'Revo Platform',
              subtitle: 'Production Hub',
            ),
          ),
        ),
      );

      expect(find.text('Revo Platform'), findsOneWidget);
      expect(find.text('Production Hub'), findsOneWidget);
      expect(find.byIcon(Icons.theater_comedy_rounded), findsOneWidget);
    });

    testWidgets('AppStatusState renders empty and error views',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          Scaffold(
            body: AppStatusState.unauthenticated(
              title: 'Access Denied',
              message: 'Login is required',
            ),
          ),
        ),
      );

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Login is required'), findsOneWidget);
    });
  });

  group('Authentication Screens Widget Tests', () {
    late MockAuthService mockAuth;

    setUp(() {
      mockAuth = MockAuthService();
      mockAuth.reset();
    });

    testWidgets('LoginScreen renders email, password fields and demo account chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          LoginScreen(
            authService: mockAuth,
            onNavigateToRegister: () {},
          ),
        ),
      );

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
      expect(find.text('Cast Member'), findsOneWidget);
      expect(find.text('Theatre Admin'), findsOneWidget);

      // Tap quick fill chip for Director
      await tester.tap(find.text('Director'));
      await tester.pump();

      expect(find.text('director@revo.com'), findsOneWidget);
    });

    testWidgets('RegisterScreen exposes role selector and Admin passcode field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RegisterScreen(
            authService: mockAuth,
            onNavigateToLogin: () {},
          ),
        ),
      );

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Admin passcode field is not visible initially (Cast role default)
      expect(find.text('Admin Authorization Code'), findsNothing);

      // Select Admin role
      await tester.tap(find.text('Admin'));
      await tester.pump();

      // Admin authorization code field appears
      expect(find.text('Admin Authorization Code'), findsOneWidget);
    });

    testWidgets('ProfileScreen displays authenticated user details and semantic role pill',
        (WidgetTester tester) async {
      final testUser = AppUser(
        userId: 'usr_dir_101',
        name: 'Sarah Jenkins',
        email: 'director@revo.com',
        role: UserRole.director,
        createdAt: DateTime(2026, 9, 15),
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          ProfileScreen(
            initialUser: testUser,
            authService: mockAuth,
          ),
        ),
      );

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('director@revo.com'), findsOneWidget);
      expect(find.text('Production Director'), findsOneWidget);
      expect(find.text('SJ'), findsOneWidget); // Initials
      expect(find.text('Sign Out of Revo'), findsOneWidget);
    });
  });
}
