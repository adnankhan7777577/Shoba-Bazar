import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';
import '../controller/otp_verification/cubit.dart';
import '../controller/otp_verification/state.dart';
import '../controller/auth_session/cubit.dart';
import 'auth_wrapper.dart';
import 'account_verification_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CodeVerificationScreen extends StatefulWidget {
  final String role;
  final String email;
  
  const CodeVerificationScreen({
    super.key,
    required this.role,
    required this.email,
  });

  @override
  State<CodeVerificationScreen> createState() => _CodeVerificationScreenState();
}

class _CodeVerificationScreenState extends State<CodeVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    // Automatically send OTP when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_otpSent) {
        _sendOtpAutomatically();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendOtpAutomatically() {
    if (!_otpSent) {
      _otpSent = true;
      context.read<OtpVerificationCubit>().resendOtp(
        email: widget.email,
      );
    }
  }

  bool _validateCode() {
    if (_codeController.text.trim().isEmpty) {
      _showError('Please enter the verification code');
      return false;
    } else if (_codeController.text.trim().length != 8) {
      _showError('Please enter a valid 8-digit code');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    CustomSnackBar.showError(context, message);
  }

  void _showSuccess(String message) {
    CustomSnackBar.showSuccess(context, message);
  }

  void _verifyCode() {
    if (!_validateCode()) return;

    final role = widget.role.toLowerCase(); // 'Customer' -> 'customer', 'Seller' -> 'seller'
    context.read<OtpVerificationCubit>().verifyOtp(
      email: widget.email,
      otp: _codeController.text.trim(),
      role: role,
    );
  }

  void _resendCode() {
    context.read<OtpVerificationCubit>().resendOtp(
      email: widget.email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<OtpVerificationCubit, OtpVerificationState>(
          listener: (context, state) async {
            if (state is OtpVerificationSuccess) {
              _showSuccess(state.message);
              
              // For sellers, check admin approval after email verification
              if (state.role.toLowerCase() == 'seller') {
                final supabase = Supabase.instance.client;
                try {
                  // Get seller approval status using the userId from state (which is the database user ID)
                  final sellerResponse = await supabase
                      .from('sellers')
                      .select('approval_status')
                      .eq('user_id', state.userId)
                      .maybeSingle();
                  
                  final approvalStatus = sellerResponse?['approval_status'] as String?;
                  
                  // If seller is not approved, redirect to waiting screen
                  if (approvalStatus != 'approved') {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const AccountVerificationScreen(),
                        ),
                        (route) => false,
                      );
                    }
                    return;
                  }
                } catch (e) {
                  print('Error checking approval status: $e');
                }
              }
              
              // Trigger session check to ensure AuthWrapper updates
              context.read<AuthSessionCubit>().checkSession();
              // Navigate to root and remove all previous routes
              // AuthWrapper will handle navigation based on role
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const AuthWrapper(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              }
            } else if (state is OtpVerificationError) {
              _showError(state.message);
            } else if (state is OtpResendSuccess) {
              _showSuccess(state.message);
            } else if (state is OtpResendError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is OtpVerificationLoading;
            final isResending = state is OtpResendLoading;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Back Arrow
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Code Verification Image
                  Image.asset(
                    'assets/images/password.png',
                    fit: BoxFit.cover,
                    height: 300,
                    width: double.infinity,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'Code verification',
                    style: AppTextStyles.loginTitle,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Text(
                    isResending 
                        ? 'Sending verification code to your email...'
                        : 'We sent an 8-digit code to your email.\nEnter the code to verify your account.',
                    style: AppTextStyles.roleSelectionDescription,
                    textAlign: TextAlign.center,
                  ),
                  
                  // Email display
                  const SizedBox(height: 16),
                  Text(
                    widget.email,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Code Input Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Code Input Field
                        CustomTextField(
                          title: 'Verification Code',
                          hintText: 'Enter 8-digit code',
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          borderColor: AppColors.primary,
                          textInputAction: TextInputAction.done,
                          focusNode: _focusNode,
                          onFieldSubmitted: (_) => _verifyCode(),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Verify Button
                        _buildVerifyButton(isLoading),
                        
                        const SizedBox(height: 16),
                        
                        // Resend Code Button
                        _buildResendButton(isResending),
                        
                        const SizedBox(height: 16),
                        
                        // Cancel Button
                        _buildCancelButton(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerifyButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _verifyCode,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.grey : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  'Verify',
                  style: AppTextStyles.primaryButton,
                ),
        ),
      ),
    );
  }

  Widget _buildResendButton(bool isResending) {
    return GestureDetector(
      onTap: isResending ? null : _resendCode,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isResending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Resend',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Cancel',
            style: AppTextStyles.secondaryButton,
          ),
        ),
      ),
    );
  }
}
