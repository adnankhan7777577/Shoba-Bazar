import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';
import '../controller/forgot_password/cubit.dart';
import '../controller/forgot_password/state.dart';
import 'password_reset_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final bool isAdmin;
  
  const ForgotPasswordScreen({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _emailError;

  // Get primary color based on user type
  Color get _primaryColor => widget.isAdmin ? AppColors.adminPrimary : AppColors.primary;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<ForgotPasswordCubit>(),
      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordEmailSent) {
            // Navigate to password reset screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PasswordResetScreen(
                  email: _emailController.text.trim(),
                  isAdmin: widget.isAdmin,
                ),
              ),
            );
            CustomSnackBar.showSuccess(context, state.message);
          } else if (state is ForgotPasswordError) {
            setState(() {
              _emailError = state.message;
            });
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
                    
                    const SizedBox(height: 10),
                    
                    // Forgot Password Image
                    Image.asset(
                      'assets/images/password.png',
                      height: 250,
                      
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Title
                    Text(
                      'Forgot Password',
                      style: AppTextStyles.loginTitle,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    Text(
                      'Enter your email address and we will send\n you a code to reset your password.',
                      style: AppTextStyles.roleSelectionDescription,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Email Input Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Input Field
                          IgnorePointer(
                            ignoring: isLoading,
                            child: Opacity(
                              opacity: isLoading ? 0.6 : 1.0,
                              child: CustomTextField(
                                title: 'Email',
                                hintText: 'Enter your email',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                borderColor: _primaryColor,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email address';
                                  }
                                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          
                          // Email Error
                          if (_emailError != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _emailError!,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 30),
                          
                          // Send Reset Code Button
                          _buildSendButton(isLoading),
                          
                          const SizedBox(height: 16),
                          
                          // Cancel Button
                          _buildCancelButton(isLoading),
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

  Widget _buildSendButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          if (_formKey.currentState!.validate()) {
            setState(() {
              _emailError = null;
            });
            context.read<ForgotPasswordCubit>().sendPasswordResetEmail(
              _emailController.text.trim(),
            );
          }
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
                'Send Reset Code',
                style: AppTextStyles.primaryButton,
              ),
      ),
    );
  }

  Widget _buildCancelButton(bool isLoading) {
    return SizedBox(
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
    );
  }
}

