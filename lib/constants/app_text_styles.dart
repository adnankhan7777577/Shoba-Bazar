import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Welcome Screen Styles
  static TextStyle get welcomeTitle => GoogleFonts.raleway(
    fontSize: 41,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
  );

  static TextStyle get badgeText => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static TextStyle get appNameBold => GoogleFonts.raleway(
    fontSize: 29,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get appNameRegular => GoogleFonts.raleway(
    fontSize: 29,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
  );

  static TextStyle get tagline => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get description => GoogleFonts.raleway(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get buttonText => GoogleFonts.raleway(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );

  // Common Text Styles
  static TextStyle get heading1 => GoogleFonts.raleway(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading2 => GoogleFonts.raleway(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading3 => GoogleFonts.raleway(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.raleway(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.raleway(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.raleway(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
  );

  // Button Styles
  static TextStyle get primaryButton => GoogleFonts.raleway(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );

  static TextStyle get secondaryButton => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );

  // Navigation Styles
  static TextStyle get navigationLabel => GoogleFonts.raleway(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get navigationLabelActive => GoogleFonts.raleway(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  // Login Screen Styles
  static TextStyle get loginTitle => GoogleFonts.raleway(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get forgotPassword => GoogleFonts.raleway(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );

  static TextStyle get textFieldHint => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
  );

  // Role Selection Screen Styles
  static TextStyle get roleSelectionTitle => GoogleFonts.raleway(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get roleSelectionDescription => GoogleFonts.raleway(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get roleButtonText => GoogleFonts.raleway(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );
}
