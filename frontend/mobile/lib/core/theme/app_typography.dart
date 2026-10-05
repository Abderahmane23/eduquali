import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typographie large, forte hierarchie visuelle (§54).
abstract final class AppTypography {
  static const String _family = 'Roboto';

  static const TextTheme textTheme = TextTheme(
    // Titres d'accroche (onboarding, ecrans vitrine).
    displaySmall: TextStyle(
      fontFamily: _family,
      fontSize: 34,
      height: 1.18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: AppColors.textPrimary,
    ),
    // Titres d'écran.
    headlineMedium: TextStyle(
      fontFamily: _family,
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _family,
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.textPrimary,
    ),
    // Titres de section / cartes.
    titleLarge: TextStyle(
      fontFamily: _family,
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Corps.
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: _family,
      fontSize: 12,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
    ),
    labelLarge: TextStyle(
      fontFamily: _family,
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: _family,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: _family,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppColors.textTertiary,
    ),
  );

  /// Chiffre de mise en avant (score, pourcentage).
  static const TextStyle metric = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    color: AppColors.textPrimary,
  );
}
