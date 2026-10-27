import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_typography.dart';

/// Reusable Revo Brand Header & Logo component.
/// Pure Flutter implementation avoiding broken image asset links.
class AppBrandHeader extends StatelessWidget {
  final double iconSize;
  final String? title;
  final String? subtitle;
  final bool showSubtitle;
  final CrossAxisAlignment alignment;

  const AppBrandHeader({
    super.key,
    this.iconSize = 48.0,
    this.title,
    this.subtitle,
    this.showSubtitle = true,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        // Brand Aperture Icon Container
        Container(
          width: iconSize + 20,
          height: iconSize + 20,
          decoration: BoxDecoration(
            color: RevoColors.primarySubtle,
            shape: BoxShape.circle,
            border: Border.all(color: RevoColors.surfaceDim, width: 1.5),
          ),
          child: Center(
            child: Icon(
              Icons.theater_comedy_rounded,
              size: iconSize,
              color: RevoColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Title
        Text(
          title ?? 'Revo',
          style: RevoTypography.display.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: RevoColors.primary,
          ),
          textAlign: alignment == CrossAxisAlignment.center
              ? TextAlign.center
              : TextAlign.start,
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'Theatre Production Management System',
            style: RevoTypography.bodyMedium.copyWith(
              color: RevoColors.textSecondary,
              letterSpacing: 0.1,
            ),
            textAlign: alignment == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
          ),
        ],
      ],
    );
  }
}
