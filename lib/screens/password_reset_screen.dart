import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';
import '../controller/forgot_password/cubit.dart';
import '../controller/forgot_password/state.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final bool isAdmin;
  
  const PasswordResetScreen({
    super.key,
    required this.email,
    this.isAdmin = false,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isOtpVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Get primary color based on user type
  Color get _primaryColor => widget.isAdmin ? AppColors.adminPrimary : AppColors.primary;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<ForgotPasswordCubit>(),
      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordEmailSent) {
            // Check if this is a password reset success or just a resend
            if (state.message.contains('reset successfully')) {
              // Password reset successful, navigate to login
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            // Show success message for both reset and resend
            CustomSnackBar.showSuccess(context, state.message);
          } else if (state is ForgotPasswordError) {
            CustomSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is ForgotPasswordLoading;
          
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Back Arrow
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: isLoading ? null : () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: isLoading ? AppColors.textLight : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Password Reset Image
                    Image.asset(
                      'assets/images/password.png',
                      height: 250,
                      width: 200,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Title
                    Text(
                      'Reset Password',
                      style: AppTextStyles.loginTitle,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    Text(
                      'Enter the verification code sent to your email\nand create a new password.',
                      style: AppTextStyles.roleSelectionDescription,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // OTP Input Field
                          IgnorePointer(
                            ignoring: isLoading,
                            child: Opacity(
                              opacity: isLoading ? 0.6 : 1.0,
                              child: CustomTextField(
                                title: 'Verification Code',
                                hintText: 'Enter verification code',
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                borderColor: _primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isOtpVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textLight,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isOtpVisible = !_isOtpVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter the verification code';
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
                                title: 'New Password',
                                hintText: 'Enter new password',
                                controller: _newPasswordController,
                                obscureText: !_isNewPasswordVisible,
                                borderColor: _primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isNewPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textLight,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isNewPasswordVisible = !_isNewPasswordVisible;
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
                                title: 'Confirm Password',
                                hintText: 'Confirm new password',
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                borderColor: _primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textLight,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                          
                          const SizedBox(height: 30),
                          
                          // Reset Password Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _handlePasswordReset,
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
                                      'Reset Password',
                                      style: AppTextStyles.primaryButton,
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Resend Code Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading ? null : () {
                                context.read<ForgotPasswordCubit>().resendPasswordResetEmail(
                                  widget.email,
                                );
                              },
                              child: Text(
                                'Resend Code',
                                style: AppTextStyles.forgotPassword.copyWith(
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Cancel Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton(
                              onPressed: isLoading ? null : () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _primaryColor, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.secondaryButton.copyWith(
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePasswordReset() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    context.read<ForgotPasswordCubit>().verifyOtpAndResetPassword(
      email: widget.email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}

