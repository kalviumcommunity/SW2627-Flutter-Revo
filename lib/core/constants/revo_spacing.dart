import 'package:flutter/material.dart';

/// REVO Design System Spacing, Radii, and Elevation Tokens.
/// Conforms to DESIGN.md §4.
class RevoSpacing {
  RevoSpacing._();

  // ── Spacing Scale ──────────────────────────────────────────────────────────
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0; // Standard mobile page gutter
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // ── Radii ──────────────────────────────────────────────────────────────────
  /// Buttons & Input Fields: 8px
  static const double radiusButton = 8.0;
  static const BorderRadius borderRadiusButton =
      BorderRadius.all(Radius.circular(radiusButton));

  /// Cards & Banners: 12px to 16px
  static const double radiusCard = 14.0;
  static const BorderRadius borderRadiusCard =
      BorderRadius.all(Radius.circular(radiusCard));

  /// Modals & Bottom Sheets: 20px
  static const double radiusModal = 20.0;
  static const BorderRadius borderRadiusModal = BorderRadius.vertical(
    top: Radius.circular(radiusModal),
  );

  /// Pill Badges: 9999px (full rounded)
  static const double radiusPill = 9999.0;
  static const BorderRadius borderRadiusPill =
      BorderRadius.all(Radius.circular(radiusPill));

  // ── Shadows ────────────────────────────────────────────────────────────────
  /// Subtle card elevation shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(23, 27, 38, 0.05),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color.fromRGBO(23, 27, 38, 0.03),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Floating action button and dialog shadow
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color.fromRGBO(59, 74, 154, 0.12),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color.fromRGBO(23, 27, 38, 0.06),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}
