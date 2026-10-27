import 'package:flutter/material.dart';

/// REVO Design System Color Palette & Semantic Token System.
/// Strictly conforms to DESIGN.md §2 ("Calm Repertory Precision").
class RevoColors {
  RevoColors._();

  // ── Brand & Primary ────────────────────────────────────────────────────────
  /// Deep Indigo — Core brand color, primary actions, active bottom tabs.
  static const Color primary = Color(0xFF3B4A9A);

  /// Pressed / hover state for primary action buttons.
  static const Color primaryHover = Color(0xFF2D3977);

  /// Very light indigo tint used for active role toggles and row highlights.
  static const Color primarySubtle = Color(0xFFEEF1FB);

  /// Text / icon color on primary surfaces.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Theatre Accent / Secondary ─────────────────────────────────────────────
  /// Deep Burgundy / Theatre Wine — Secondary accent for theatrical distinction.
  static const Color secondary = Color(0xFF8B263E);

  /// Subtle wine container tint for badge accents.
  static const Color secondarySubtle = Color(0xFFF7ECEF);

  // ── Semantic State Tokens ──────────────────────────────────────────────────
  /// Stage Amber — Alert banners, detected clashes, pending notifications.
  static const Color warningAmber = Color(0xFFF2B33D);

  /// Soft amber container background for warning callouts and banner cards.
  static const Color warningSurface = Color(0xFFFEF8EC);

  /// High-contrast accessible text on warning surfaces.
  static const Color warningText = Color(0xFF946300);

  /// Confirmed Green — Verified rehearsal slots, conflict resolved state.
  static const Color successGreen = Color(0xFF3FA672);

  /// Soft green container background for confirmed bookings.
  static const Color successSurface = Color(0xFFEBF7F1);

  /// Dark green readable typography on green pills.
  static const Color successText = Color(0xFF1A633F);

  /// Double-booking clash banners, cancelled old calls, error states.
  static const Color errorCrimson = Color(0xFFD9383A);

  /// Background for collision alert sheets and error banners.
  static const Color errorSurface = Color(0xFFFDF2F2);

  // ── Neutrals & Surfaces ────────────────────────────────────────────────────
  /// Primary viewport background (crisp, light cool surface tint).
  static const Color surfaceBase = Color(0xFFF9F9FF);

  /// Pure white cards, modal bodies, top app bars, bottom tab bar.
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  /// Secondary card backgrounds, timeline grid lines, inactive pill backgrounds.
  static const Color surfaceContainerLow = Color(0xFFF1F3FF);

  /// Borders, subtle dividers, timeline vertical time rules.
  static const Color surfaceDim = Color(0xFFE2E6F2);

  /// High-emphasis body, headlines, production titles, actor names.
  static const Color textPrimary = Color(0xFF171B26);

  /// Medium-emphasis labels, timestamps, metadata, venue names.
  static const Color textSecondary = Color(0xFF586074);

  /// Low-emphasis breadcrumbs, struck-through old call times, idle icons.
  static const Color textTertiary = Color(0xFF8C95A8);

  /// Disabled button and control surfaces.
  static const Color disabled = Color(0xFFC8CDD8);

  // ── Semantic Aliases & Card Tokens ─────────────────────────────────────────
  /// Card background surface.
  static const Color cardBackground = surfaceContainerLowest;

  /// Default border color.
  static const Color borderDefault = surfaceDim;

  /// Low emphasis / muted text.
  static const Color textMuted = textTertiary;

  /// High container surface tint.
  static const Color surfaceContainerHigh = surfaceContainerLow;
}
