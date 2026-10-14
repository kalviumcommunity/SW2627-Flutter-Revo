import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_spacing.dart';
import '../constants/revo_typography.dart';
import 'loading_indicator.dart';

/// Reusable Primary Button strictly adhering to Revo Design System.
/// Features Deep Indigo background, loading indicator without layout shift,
/// leading icon support, and accessibility contrast standards.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 48.0,
    this.width,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? RevoColors.primary;
    final effectiveTextColor = textColor ?? RevoColors.onPrimary;
    final bool isInteractive = onPressed != null && !isLoading;

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isInteractive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          disabledBackgroundColor: RevoColors.disabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: RevoSpacing.borderRadiusButton,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isLoading
              ? AppLoadingIndicator.small(
                  key: const ValueKey('button_loading'),
                  color: effectiveTextColor,
                )
              : Row(
                  key: const ValueKey('button_content'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: effectiveTextColor),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: RevoTypography.headline.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
