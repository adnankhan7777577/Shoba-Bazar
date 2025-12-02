import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../controller/auth_session/cubit.dart';
import '../widgets/custom_snackbar.dart';
import 'auth_wrapper.dart';

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() => _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isRejected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    ));
    
    // Start loading animation
    _loadingController.repeat();
    
    // Start checking approval status
    _checkApprovalStatus();
    
    // Set up periodic check every 10 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isChecking) {
        _checkApprovalStatus();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app comes back to foreground, check approval status immediately
    if (state == AppLifecycleState.resumed && mounted && !_isChecking) {
      _checkApprovalStatus();
      // Also trigger session check to ensure auth state is up to date
      context.read<AuthSessionCubit>().checkSession();
    }
  }

  Future<void> _checkApprovalStatus() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isChecking = false;
        });
        return;
      }

      // Get user ID from users table
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (userResponse == null) {
        setState(() {
          _isChecking = false;
        });
        return;
      }

      final userId = userResponse['id'] as String;

      // Check seller approval status
      final sellerResponse = await _supabase
          .from('sellers')
          .select('approval_status')
          .eq('user_id', userId)
          .maybeSingle();

      if (sellerResponse != null) {
        final approvalStatus = sellerResponse['approval_status'] as String?;
        
        if (approvalStatus == 'approved') {
          // Stop the timer and loading animation
          _checkTimer?.cancel();
          _loadingController.stop();
          
          setState(() {
            _isChecking = false;
          });
          
          // Show success dialog
          if (mounted) {
            _showSuccessDialog();
          }
          return;
        } else if (approvalStatus == 'rejected') {
          // Handle rejection case
          _checkTimer?.cancel();
          _loadingController.stop();
          
          setState(() {
            _isChecking = false;
            _isRejected = true;
          });
          return;
        }
      }
    } catch (e) {
      print('Error checking approval status: $e');
    }
    
    setState(() {
      _isChecking = false;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              
                // Verification icon
                Container(
                  width: 120,
                  height: 100,
                  
                  child: Padding(
                    padding: const EdgeInsets.all(9.0),
                    child: Image.asset(
                    'assets/images/Logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'Account Verified',
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Your account has been verified.\nLet\'s start selling products.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Background illustration area
                Container(
                
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/codeVerification.png',
                      width: 200,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Let's Go button
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateToDashboard();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Let\'s Go',
                        style: AppTextStyles.primaryButton.copyWith(
                          color: Colors.white,
                        ),
                      ),
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

  void _navigateToDashboard() async {
    // Trigger session check to ensure AuthWrapper updates with latest approval status
    // This ensures the session state is properly updated before navigation
    context.read<AuthSessionCubit>().checkSession();
    
    // Navigate to AuthWrapper which will handle routing based on session state
    // If approved -> SellerMainScreen, if not approved -> AccountVerificationScreen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthWrapper(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error logging out: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show rejection screen if account is rejected
    if (_isRejected) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rejection icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: AppColors.error,
                    size: 50,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Account Rejected',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Message
                Text(
                  'Your seller account request has been rejected.\n\nPlease contact our support team for more information or assistance.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 60),
                
                // Support Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.lightGrey,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Need help? Contact our support',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      // WhatsApp Support Button
                      GestureDetector(
                        onTap: () => _openWhatsAppSupport(),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0DC143),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowLight,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/whatsapp.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Contact Support',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Logout Button
                GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show normal verification waiting screen
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                'Account verification',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Verification message
              Text(
                'Your account is being verified.\nYou will be notified when your\naccount is verified.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Time estimate
              Text(
                'it will take around 24 Hours',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Loading animation
              Center(
                child: AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(60, 60),
                      painter: LoadingSpinnerPainter(
                        progress: _loadingAnimation.value,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Car illustration
              Center(
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/images/car.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Support Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Need help?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // WhatsApp Support Button
                    GestureDetector(
                      onTap: () => _openWhatsAppSupport(),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0DC143),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/whatsapp.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Contact Support',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsAppSupport() async {
    const supportNumber = '+92 329 9508708';
    
    // Clean the number: remove all non-numeric characters except +
    String cleanNumber = supportNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
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

    // Create default message indicating seller is contacting for account approval/help
    const defaultMessage = 'Hello! I need help with my seller account approval on Shoba Bazar app.';
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error opening WhatsApp: ${e.toString()}');
      }
    }
  }
}

// Custom painters for illustrations
class LoadingSpinnerPainter extends CustomPainter {
  final double progress;
  
  LoadingSpinnerPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10.0;
    
    // Draw 8 dashes in a circle
    for (int i = 0; i < 8; i++) {
      final angle = (i * 2.0 * 3.14159) / 8.0;
      final startAngle = angle + (progress * 2.0 * 3.14159);
      
      final startX = center.dx + radius * 0.7 * cos(startAngle);
      final startY = center.dy + radius * 0.7 * sin(startAngle);
      final endX = center.dx + radius * cos(startAngle);
      final endY = center.dy + radius * sin(startAngle);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


