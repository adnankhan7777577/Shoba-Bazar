import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_snackbar.dart';

class SellerSupportScreen extends StatefulWidget {
  const SellerSupportScreen({super.key});

  @override
  State<SellerSupportScreen> createState() => _SellerSupportScreenState();
}

class _SellerSupportScreenState extends State<SellerSupportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
          
            children: [
              // Title
              Text(
                'Seller Support',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 30),
              
              Image.asset('assets/images/support.png',height: 150,),
              
              const SizedBox(height: 25),
              
              // Instructional Text
              Text(
                'Contact us for in case of help needed',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Contact Button
              GestureDetector(
                onTap: () {
                  _openWhatsApp('+92 329 9508708');
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0DC143),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                     color: const Color(0xFF0DC143),
                      width: 1,
                    ),
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
                        'Contact',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Contact Information Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Email Row (clickable)
                    _buildContactRow(
                      icon: Icons.email_outlined,
                      text: 'Shobabazar250000@gmail.com',
                      iconColor: AppColors.primary,
                      onTap: () => _launchEmail('Shobabazar250000@gmail.com'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Phone Row (clickable)
                    _buildContactRow(
                      icon: Icons.phone_outlined,
                      text: '+92 329 9508708',
                      iconColor: AppColors.primary,
                      onTap: () => _launchPhone('+92 329 9508708'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // WhatsApp Row (clickable)
                    _buildWhatsAppRow(
                      text: '+92 329 9508708',
                      onTap: () {},
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

  Widget _buildContactRow({
    required IconData icon,
    required String text,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final rowWidget = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: onTap != null ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: rowWidget,
        ),
      );
    }

    return rowWidget;
  }

  Widget _buildWhatsAppRow({
    required String text,
    VoidCallback? onTap,
  }) {
    final rowWidget = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/whatsapp.png',
              width: 24,
              height: 24,
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: onTap != null ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: rowWidget,
        ),
      );
    }

    return rowWidget;
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

    // Create default message indicating seller is contacting for support
    const defaultMessage = 'Hello! I need help with seller support on Shoba Bazar app.';
    
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

  Future<void> _launchPhone(String phoneNumber) async {
    // Clean the number: remove all non-numeric characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (cleanNumber.isEmpty) {
      CustomSnackBar.showError(context, 'Invalid phone number');
      return;
    }

    final phoneUrl = 'tel:$cleanNumber';
    
    try {
      final uri = Uri.parse(phoneUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not make phone call.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error making phone call: ${e.toString()}');
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final emailUrl = 'mailto:$email';
    
    try {
      final uri = Uri.parse(emailUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not open email client.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error opening email: ${e.toString()}');
      }
    }
  }
}
