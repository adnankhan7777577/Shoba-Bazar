import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../controller/password_change/cubit.dart';
import '../controller/password_change/state.dart';
import 'custom_text_field.dart';
import 'custom_snackbar.dart';

class PasswordChangeDialog extends StatefulWidget {
  final bool isAdmin;
  
  const PasswordChangeDialog({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Get primary color based on user type
  Color get _primaryColor => widget.isAdmin ? AppColors.adminPrimary : AppColors.primary;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<PasswordChangeCubit>(),
      child: BlocConsumer<PasswordChangeCubit, PasswordChangeState>(
        listener: (context, state) {
          if (state is PasswordChangeSuccess) {
            Navigator.of(context).pop();
            _showSuccessDialog(context);
            // Reset the cubit state
            context.read<PasswordChangeCubit>().reset();
          } else if (state is PasswordChangeError) {
            CustomSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is PasswordChangeLoading;
          
          return Dialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button and password icon on same line
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: isLoading ? null : () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: isLoading ? AppColors.textLight : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/images/password.png',
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(width: 40), // Spacer to center the image
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'Change Password',
                    style: AppTextStyles.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Old Password Field
                        IgnorePointer(
                          ignoring: isLoading,
                          child: Opacity(
                            opacity: isLoading ? 0.6 : 1.0,
                            child: CustomTextField(
                              hintText: 'Old password',
                              controller: _oldPasswordController,
                              obscureText: !_isOldPasswordVisible,
                              borderColor: _primaryColor,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                            icon: Icon(
                              _isOldPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {
                              // Use SchedulerBinding to delay setState and prevent keyboard glitches
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _isOldPasswordVisible = !_isOldPasswordVisible;
                                  });
                                }
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your old password';
                            }
                            return null;
                          },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // New Password Field
                        IgnorePointer(
                          ignoring: isLoading,
                          child: Opacity(
                            opacity: isLoading ? 0.6 : 1.0,
                            child: CustomTextField(
                              hintText: 'New password',
                              controller: _newPasswordController,
                              obscureText: !_isNewPasswordVisible,
                              borderColor: _primaryColor,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                            icon: Icon(
                              _isNewPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {
                              // Use SchedulerBinding to delay setState and prevent keyboard glitches
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _isNewPasswordVisible = !_isNewPasswordVisible;
                                  });
                                }
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Confirm Password Field
                        IgnorePointer(
                          ignoring: isLoading,
                          child: Opacity(
                            opacity: isLoading ? 0.6 : 1.0,
                            child: CustomTextField(
                              hintText: 'Confirm new password',
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              borderColor: _primaryColor,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                              },
                              suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {
                              // Use SchedulerBinding to delay setState and prevent keyboard glitches
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                  });
                                }
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your new password';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
            
                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => _handlePasswordChange(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: AppColors.white,
                        elevation: 4,
                        shadowColor: AppColors.shadow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Done',
                              style: AppTextStyles.primaryButton.copyWith(color: AppColors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePasswordChange(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    // Call the password change cubit
    context.read<PasswordChangeCubit>().changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Image.asset(
                  'assets/images/password.png',
                  width: 80,
                  height: 80,
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'Password Changed',
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Your password has been successfully changed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // OK Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: AppColors.white,
                      elevation: 4,
                      shadowColor: AppColors.shadow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: AppTextStyles.primaryButton.copyWith(color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
