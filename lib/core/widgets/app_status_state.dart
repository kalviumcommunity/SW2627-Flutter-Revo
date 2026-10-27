import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_spacing.dart';
import '../constants/revo_typography.dart';
import 'primary_button.dart';

/// Reusable Empty, Error, and Informational State Component.
/// Provides consistent messaging, iconography, and optional retry/action buttons.
class AppStatusState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  const AppStatusState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackgroundColor,
  });

  /// Factory for empty states (e.g., no auditions, no rehearsals)
  factory AppStatusState.empty({
    Key? key,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return AppStatusState(
      key: key,
      icon: Icons.inbox_outlined,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: RevoColors.textTertiary,
      iconBackgroundColor: RevoColors.surfaceContainerLow,
    );
  }

  /// Factory for error states (e.g., connection failure, invalid auth)
  factory AppStatusState.error({
    Key? key,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return AppStatusState(
      key: key,
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: RevoColors.errorCrimson,
      iconBackgroundColor: RevoColors.errorSurface,
    );
  }

  /// Factory for unauthenticated guard state
  factory AppStatusState.unauthenticated({
    Key? key,
    String title = 'Authentication Required',
    String message = 'Please sign in to view your profile and theatre commitments.',
    String actionLabel = 'Go to Sign In',
    VoidCallback? onAction,
  }) {
    return AppStatusState(
      key: key,
      icon: Icons.lock_outline_rounded,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: RevoColors.primary,
      iconBackgroundColor: RevoColors.primarySubtle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RevoSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? RevoColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? RevoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: RevoTypography.title2.copyWith(
                fontWeight: FontWeight.w700,
                color: RevoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: RevoTypography.bodyMedium.copyWith(
                  color: RevoColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                child: PrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: 44,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
