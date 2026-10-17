import 'package:flutter/material.dart';

import '../../core/enums/revo_enums.dart';
import '../../models/app_user.dart';
import '../../services/firebase_auth_service.dart';
import '../admin/admin_dashboard.dart';
import '../cast/cast_dashboard.dart';
import '../director/director_dashboard.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class RoleBasedRouter extends StatefulWidget {
  final Widget Function(BuildContext context, AppUser user)? customDirectorView;
  final Widget Function(BuildContext context, AppUser user)? customCastView;
  final FirebaseAuthService? authService;

  const RoleBasedRouter({
    super.key,
    this.customDirectorView,
    this.customCastView,
    this.authService,
  });

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  late final FirebaseAuthService _authService =
      widget.authService ?? FirebaseAuthService();
  bool _showRegisterScreen = false;

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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Unauthenticated guard
        if (user == null) {
          if (_showRegisterScreen) {
            return RegisterScreen(
              onNavigateToLogin: _toggleAuthScreen,
              authService: _authService,
            );
          }
          return LoginScreen(
            onNavigateToRegister: _toggleAuthScreen,
            authService: _authService,
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
