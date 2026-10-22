import 'package:flutter/material.dart';
import 'revo_colors.dart';

/// REVO Design System Typography Tokens.
/// Conforms to DESIGN.md §3 (DM Sans font family & tabular numerals).
class RevoTypography {
  RevoTypography._();

  static const String fontFamily = 'DM Sans';

  /// Display / Title 1: 22px Bold (700), line height 1.25
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: RevoColors.textPrimary,
  );

  /// Title 2: 18px SemiBold (600), line height 1.3
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: RevoColors.textPrimary,
  );

  /// Headline: 15px SemiBold (600), line height 1.35
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: RevoColors.textPrimary,
  );

  /// Body Large: 14px Medium (500), line height 1.4
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: RevoColors.textPrimary,
  );

  /// Body Medium: 13px Regular (400), line height 1.45
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: RevoColors.textSecondary,
  );

  /// Caption / Badge: 11px SemiBold (600), line height 1.2
  static const TextStyle captionBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: RevoColors.textSecondary,
  );

  /// Caption: 12px Regular (400), line height 1.3
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: RevoColors.textSecondary,
  );

  /// Headline 1 / Display: 22px Bold (700)
  static const TextStyle headline1 = display;

  /// Headline 2: 18px Bold (700), line height 1.3
  static const TextStyle headline2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: RevoColors.textPrimary,
  );

  /// Tabular font features for numbers, dates, and times
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];
}
