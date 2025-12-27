import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';
import '../controller/login/cubit.dart';
import '../controller/login/state.dart';
import '../controller/auth_session/cubit.dart';
import 'role_selection_screen.dart';
import 'forgot_password_screen.dart';
import 'auth_wrapper.dart';
import 'account_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return false;
    } else if (!_emailController.text.contains('@')) {
      _showError('Please enter a valid email');
      return false;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return false;
    } else if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    // Check if it's a network error and show appropriate message
    if (message.contains('No internet connection') || 
        message.contains('network') ||
        message.contains('connection')) {
      CustomSnackBar.showNoNetwork(context, message: message);
    } else {
      CustomSnackBar.showError(context, message);
    }
  }

  void _showSuccess(String message) {
    CustomSnackBar.showSuccess(context, message);
  }

  void _login() {
    if (!_validateForm()) return;

    context.read<LoginCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor = AppColors.primary;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            if (state is LoginSuccess) {
              _showSuccess(state.message);
              // Trigger session check to ensure AuthWrapper updates
              context.read<AuthSessionCubit>().checkSession();
              // Navigate to root and remove all previous routes
              // AuthWrapper will handle navigation based on role
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const AuthWrapper(),
                ),
                (route) => false, // Remove all previous routes
              );
            } else if (state is LoginSellerPendingApproval) {
              // Navigate to admin approval waiting screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const AccountVerificationScreen(),
                ),
              );
            } else if (state is LoginEmailUnverified) {
              // Treat unverified email the same as success and continue
              _showSuccess('Login successful!');
              context.read<AuthSessionCubit>().checkSession();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const AuthWrapper(),
                ),
                (route) => false,
              );
            } else if (state is LoginError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is LoginLoading;
            
            return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      
                      // Back Arrow
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Login Image
                      Image.asset(
                        'assets/images/loginImage.png',
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Login Title
                      Text(
                        'User login',
                        style: AppTextStyles.loginTitle,
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            CustomTextField(
                              title: 'Email',
                              hintText: 'Enter your email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              borderColor: primaryColor,
                              textInputAction: TextInputAction.next,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Password Field
                            CustomTextField(
                              title: 'Password',
                              hintText: 'Enter your password',
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              borderColor: primaryColor,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                _login();
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.textLight,
                                ),
                                onPressed: () {
                                  // Use SchedulerBinding to delay setState and prevent keyboard glitches
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot password?',
                                  style: AppTextStyles.forgotPassword,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 18),
                            
                            // Login Button
                            _buildLoginButton(primaryColor, isLoading),
                            
                            const SizedBox(height: 12),
                            
                            // Create Account Button
                            _buildCreateAccountButton(primaryColor),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Support Section
                      _buildSupportSection(),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                );
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton(Color primaryColor, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _login,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.grey : primaryColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  'Login',
                  style: AppTextStyles.primaryButton,
                ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton(Color primaryColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RoleSelectionScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Create Account',
            style: AppTextStyles.secondaryButton.copyWith(color: primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Column(
      children: [
        // Support Title
        Text(
          'For support',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        // WhatsApp Contact Button
        GestureDetector(
          onTap: () {
            _openWhatsApp('+92 329 9508708');
          },
          child: Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0DC143),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/whatsapp.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Contact with us',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Clean the number: remove all non-numeric characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Remove any spaces, dashes, parentheses, etc.
    cleanNumber = cleanNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    
    // If number doesn't start with +, handle local format
    if (!cleanNumber.startsWith('+')) {
      // If it starts with 0, remove it (local format like 0912345678)
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }
    }
    
    if (cleanNumber.isEmpty) {
      CustomSnackBar.showError(context, 'Invalid WhatsApp number');
      return;
    }

    // Create default message for login screen support
    const defaultMessage = 'Hello! I need help with Shoba Bazar app.';
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    
    // Use whatsapp:// scheme to open personal WhatsApp (not WhatsApp Business)
    final whatsappUrl = 'whatsapp://send?phone=$cleanNumber&text=$encodedMessage';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // Fallback to wa.me if whatsapp:// scheme fails
        final fallbackUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
        final fallbackUri = Uri.parse(fallbackUrl);
        final fallbackLaunched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!fallbackLaunched && mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    } catch (e) {
      // Try fallback to wa.me if whatsapp:// scheme throws an error
      try {
        final fallbackUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
        final fallbackUri = Uri.parse(fallbackUrl);
        await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (fallbackError) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    }
  }
}
