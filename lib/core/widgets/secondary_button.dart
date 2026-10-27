import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_spacing.dart';
import '../constants/revo_typography.dart';

/// Reusable Secondary Button adhering to Revo Design System.
/// Distinct from PrimaryButton with an outlined style or subtle tinted background.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double? width;
  final bool isOutlined;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 48.0,
    this.width,
    this.isOutlined = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? RevoColors.primary;
    final bool isInteractive = onPressed != null;

    if (isOutlined) {
      return SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: OutlinedButton(
          onPressed: isInteractive ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: effectiveColor,
            disabledForegroundColor: RevoColors.textTertiary,
            side: BorderSide(
              color: isInteractive ? RevoColors.surfaceDim : RevoColors.surfaceDim.withValues(alpha: 0.5),
              width: 1.5,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: isInteractive ? effectiveColor : RevoColors.textTertiary),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: RevoTypography.headline.copyWith(
                    color: isInteractive ? effectiveColor : RevoColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: TextButton(
        onPressed: isInteractive ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: isInteractive ? RevoColors.primarySubtle : RevoColors.surfaceContainerLow,
          foregroundColor: effectiveColor,
          disabledForegroundColor: RevoColors.textTertiary,
          shape: const RoundedRectangleBorder(
            borderRadius: RevoSpacing.borderRadiusButton,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isInteractive ? effectiveColor : RevoColors.textTertiary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: RevoTypography.headline.copyWith(
                  color: isInteractive ? effectiveColor : RevoColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
