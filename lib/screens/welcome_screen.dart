import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_texts.dart';
import '../constants/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Welcome text
              Text(
                AppTexts.welcomeTitle,
                style: AppTextStyles.welcomeTitle,
              ),
              
            
              const SizedBox(height: 20),
              
              // App logo
              Image.asset(
                'assets/images/transparentLogo.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
              
              const SizedBox(height: 20),
              
              // App name
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Shoba ',
                      style: AppTextStyles.appNameBold,
                    ),
                    TextSpan(
                      text: 'Bazar',
                      style: AppTextStyles.appNameRegular,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 5),
              
              // Tagline
              Text(
                AppTexts.appTagline,
                style: AppTextStyles.tagline,
                textAlign: TextAlign.center,
              ),
              
            Spacer(),
              
              // Description
              Text(
                AppTexts.appDescription,
                style: AppTextStyles.description,
                textAlign: TextAlign.center,
              ),
              
          
              const SizedBox(height: 20),
              // Get started button
              AppButton.primary(
                text: AppTexts.welcomeButton,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
