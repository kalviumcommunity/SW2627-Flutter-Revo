import 'package:flutter/material.dart';
import '../../../core/constants/revo_colors.dart';
import '../../../core/constants/revo_spacing.dart';
import '../../../core/constants/revo_typography.dart';
import '../../../core/enums/revo_enums.dart';
import '../../../core/widgets/app_status_state.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/mock_auth_service.dart';

/// FR-18 & Issue #8: Revo Profile Screen.
/// Displays the currently authenticated mock user's identity, role permissions,
/// and provides session logout actions.
class ProfileScreen extends StatefulWidget {
  final AppUser? initialUser;
  final AuthService? authService;
  final VoidCallback? onSignedOut;

  const ProfileScreen({
    super.key,
    this.initialUser,
    this.authService,
    this.onSignedOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _auth;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? MockAuthService();
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    try {
      await _auth.logout();
      if (mounted) {
        widget.onSignedOut?.call();
        // If opened as a modal or pushed route, pop it
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatRoleName(UserRole role) {
    switch (role) {
      case UserRole.director:
        return 'Production Director';
      case UserRole.cast:
        return 'Cast Member';
      case UserRole.admin:
        return 'Theatre Administrator';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.director:
        return RevoColors.primary;
      case UserRole.cast:
        return RevoColors.successGreen;
      case UserRole.admin:
        return RevoColors.warningAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _auth.authStateChanges(),
      initialData: widget.initialUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? widget.initialUser;

        return Scaffold(
          backgroundColor: RevoColors.surfaceBase,
          appBar: AppBar(
            title: const Text('My Profile'),
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
          ),
          body: user == null
              ? _buildUnauthenticatedState(context)
              : _buildProfileContent(context, user),
        );
      },
    );
  }

  Widget _buildUnauthenticatedState(BuildContext context) {
    return AppStatusState.unauthenticated(
      title: 'Session Signed Out',
      message: 'You are currently not signed in. Please sign in to view your profile and productions.',
      actionLabel: 'Return to Sign In',
      onAction: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, AppUser user) {
    final roleColor = _getRoleColor(user.role);
    final roleLabel = _formatRoleName(user.role);
    final initials = _getInitials(user.name);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(RevoSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card with Avatar
              Container(
                padding: const EdgeInsets.all(RevoSpacing.xl),
                decoration: BoxDecoration(
                  color: RevoColors.surfaceContainerLowest,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.surfaceDim),
                  boxShadow: RevoSpacing.cardShadow,
                ),
                child: Column(
                  children: [
                    // Initials Avatar with Role border
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: roleColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: roleColor,
                            fontFamily: RevoTypography.fontFamily,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // User Name
                    Text(
                      user.name.isNotEmpty ? user.name : 'Theatre Member',
                      style: RevoTypography.title2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    // User Email
                    Text(
                      user.email.isNotEmpty ? user.email : 'No email linked',
                      style: RevoTypography.bodyMedium.copyWith(
                        color: RevoColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Semantic Role Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: RevoSpacing.borderRadiusPill,
                        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.role == UserRole.director
                                ? Icons.movie_creation_outlined
                                : user.role == UserRole.admin
                                    ? Icons.admin_panel_settings_outlined
                                    : Icons.person_outline_rounded,
                            size: 15,
                            color: roleColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            roleLabel,
                            style: RevoTypography.captionBadge.copyWith(
                              color: roleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Account & System Info Section
              Container(
                padding: const EdgeInsets.all(RevoSpacing.lg),
                decoration: BoxDecoration(
                  color: RevoColors.surfaceContainerLowest,
                  borderRadius: RevoSpacing.borderRadiusCard,
                  border: Border.all(color: RevoColors.surfaceDim),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Details',
                      style: RevoTypography.headline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: Icons.badge_outlined,
                      label: 'User Identifier',
                      value: user.userId,
                    ),
                    const Divider(color: RevoColors.surfaceDim, height: 20),
                    _infoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Registered On',
                      value: '${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              SecondaryButton(
                label: _isLoggingOut ? 'Signing out...' : 'Sign Out of Revo',
                icon: Icons.logout_rounded,
                color: RevoColors.errorCrimson,
                onPressed: _isLoggingOut ? null : _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: RevoColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: RevoTypography.captionBadge.copyWith(
                  color: RevoColors.textTertiary,
                ),
              ),
              Text(
                value,
                style: RevoTypography.bodyMedium.copyWith(
                  color: RevoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (badgeColor ?? RevoColors.primary).withValues(alpha: 0.1),
              borderRadius: RevoSpacing.borderRadiusPill,
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? RevoColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

