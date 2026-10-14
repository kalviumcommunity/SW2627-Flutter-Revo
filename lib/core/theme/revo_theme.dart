import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_spacing.dart';
import '../constants/revo_typography.dart';

/// Centralized Revo Application ThemeData.
/// Encapsulates the "Calm Repertory Precision" aesthetic specification from DESIGN.md.
class RevoTheme {
  RevoTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: RevoColors.primary,
      onPrimary: RevoColors.onPrimary,
      primaryContainer: RevoColors.primarySubtle,
      onPrimaryContainer: RevoColors.primary,
      secondary: RevoColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: RevoColors.secondarySubtle,
      onSecondaryContainer: RevoColors.secondary,
      error: RevoColors.errorCrimson,
      onError: Colors.white,
      errorContainer: RevoColors.errorSurface,
      onErrorContainer: RevoColors.errorCrimson,
      surface: RevoColors.surfaceContainerLowest,
      onSurface: RevoColors.textPrimary,
      onSurfaceVariant: RevoColors.textSecondary,
      outline: RevoColors.surfaceDim,
      outlineVariant: RevoColors.surfaceContainerLow,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RevoColors.surfaceBase,
      fontFamily: RevoTypography.fontFamily,

      // ── App Bar Theme ──────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: RevoColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: RevoColors.textPrimary),
        titleTextStyle: RevoTypography.title2,
      ),

      // ── Button Themes ──────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RevoColors.primary,
          foregroundColor: RevoColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: const RoundedRectangleBorder(
            borderRadius: RevoSpacing.borderRadiusButton,
          ),
          textStyle: RevoTypography.headline.copyWith(
            color: RevoColors.onPrimary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RevoColors.primary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: RevoColors.surfaceDim, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: RevoSpacing.borderRadiusButton,
          ),
          textStyle: RevoTypography.headline.copyWith(
            color: RevoColors.primary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RevoColors.primary,
          textStyle: RevoTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: RevoColors.primary,
          ),
        ),
      ),

      // ── Input Decoration Theme ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RevoColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: RevoTypography.bodyMedium,
        hintStyle: RevoTypography.bodyMedium.copyWith(
          color: RevoColors.textTertiary,
        ),
        errorStyle: const TextStyle(
          color: RevoColors.errorCrimson,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        border: const OutlineInputBorder(
          borderRadius: RevoSpacing.borderRadiusButton,
          borderSide: BorderSide(color: RevoColors.surfaceDim),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: RevoSpacing.borderRadiusButton,
          borderSide: BorderSide(color: RevoColors.surfaceDim),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: RevoSpacing.borderRadiusButton,
          borderSide: BorderSide(color: RevoColors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: RevoSpacing.borderRadiusButton,
          borderSide: BorderSide(color: RevoColors.errorCrimson, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: RevoSpacing.borderRadiusButton,
          borderSide: BorderSide(color: RevoColors.errorCrimson, width: 2.0),
        ),
      ),

      // ── Card Theme ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: RevoColors.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: RevoSpacing.borderRadiusCard,
          side: const BorderSide(color: RevoColors.surfaceDim),
        ),
      ),

      // ── Modal & Dialog Themes ──────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: RevoColors.surfaceContainerLowest,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: RevoColors.surfaceContainerLowest,
        elevation: 8,
        shape: RevoSpacing.borderRadiusModal,
      ),

      // ── Typography ─────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: RevoTypography.display,
        headlineMedium: RevoTypography.title2,
        headlineSmall: RevoTypography.headline,
        titleLarge: RevoTypography.title2,
        titleMedium: RevoTypography.headline,
        titleSmall: RevoTypography.bodyLarge,
        bodyLarge: RevoTypography.bodyLarge,
        bodyMedium: RevoTypography.bodyMedium,
        bodySmall: RevoTypography.captionBadge,
        labelLarge: RevoTypography.headline,
        labelMedium: RevoTypography.bodyMedium,
        labelSmall: RevoTypography.captionBadge,
      ),
    );
  }
}
