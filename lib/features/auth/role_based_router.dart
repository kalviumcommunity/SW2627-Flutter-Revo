import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/mock_auth_service.dart';
import '../admin/admin_dashboard.dart';
import '../cast/cast_dashboard.dart';
import '../director/director_dashboard.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// FR-01 & Issue #8: Centralized Role-Based Router.
/// Manages authentication guards and role navigation between
/// unauthenticated flows (Login/Register) and protected dashboards.
class RoleBasedRouter extends StatefulWidget {
  final AuthService? authService;
  final Widget Function(BuildContext context, AppUser user)? customDirectorView;
  final Widget Function(BuildContext context, AppUser user)? customCastView;

  const RoleBasedRouter({
    super.key,
    this.authService,
    this.customDirectorView,
    this.customCastView,
  });

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  late final AuthService _authService;
  bool _showRegisterScreen = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ??
        (Firebase.apps.isNotEmpty ? FirebaseAuthService() : MockAuthService());
  }

  void _toggleAuthScreen() {
    setState(() {
      _showRegisterScreen = !_showRegisterScreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: AppLoadingIndicator.fullScreen(
                message: 'Initializing Revo session...',
              ),
            ),
          );
        }

        final user = snapshot.data;

        // Unauthenticated guard (FR-01)
        if (user == null) {
          if (_showRegisterScreen) {
            return RegisterScreen(
              authService: _authService,
              onNavigateToLogin: _toggleAuthScreen,
            );
          }
          return LoginScreen(
            authService: _authService,
            onNavigateToRegister: _toggleAuthScreen,
          );
        }

        // Role-based navigation guard (FR-01)
        switch (user.role) {
          case UserRole.director:
            if (widget.customDirectorView != null) {
              return widget.customDirectorView!(context, user);
            }
            return DirectorDashboard(user: user);

          case UserRole.cast:
            if (widget.customCastView != null) {
              return widget.customCastView!(context, user);
            }
            return CastDashboard(user: user);

          case UserRole.admin:
            return AdminDashboard(user: user);
        }
      },
    );
  }
}
