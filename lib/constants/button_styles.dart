import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class ButtonStyles {
  // Primary Button Style
  static ButtonStyle get primary => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 60),
    textStyle: AppTextStyles.primaryButton,
  );

  // Primary Button Style - Small
  static ButtonStyle get primarySmall => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    minimumSize: const Size(120, 48),
    textStyle: AppTextStyles.primaryButton.copyWith(fontSize: 14),
  );

  // Secondary Button Style (Outlined)
  static ButtonStyle get secondary => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 60),
    textStyle: AppTextStyles.secondaryButton,
  );

  // Secondary Button Style - Small
  static ButtonStyle get secondarySmall => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    minimumSize: const Size(120, 48),
    textStyle: AppTextStyles.secondaryButton.copyWith(fontSize: 14),
  );

  // Disabled Button Style
  static ButtonStyle get disabled => ElevatedButton.styleFrom(
    backgroundColor: AppColors.lightGrey,
    foregroundColor: AppColors.grey,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 60),
    textStyle: AppTextStyles.primaryButton.copyWith(color: AppColors.grey),
  );

  // Success Button Style
  static ButtonStyle get success => ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: AppColors.white,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 60),
    textStyle: AppTextStyles.primaryButton,
  );

  // Error Button Style
  static ButtonStyle get error => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.white,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(double.infinity, 60),
    textStyle: AppTextStyles.primaryButton,
  );
}
