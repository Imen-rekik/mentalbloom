import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isLoading = false;

  void _checkStatus() async {
    setState(() => isLoading = true);
    final service = Provider.of<FirebaseService>(context, listen: false);
    try {
      await service.refreshAuthStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _resendEmail() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    try {
      await service.resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Please check your inbox.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification link to:\n${service.currentUserEmail}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your inbox and click the link to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 48),

              // Check Status Button
              isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _checkStatus,
                        child: const Text(
                          'I\'ve Verified',
                          style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // Resend Button
              TextButton(
                onPressed: _resendEmail,
                child: const Text(
                  'Resend verification email',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Back to Login / Logout
              IconButton(
                onPressed: () => service.logout(),
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: AppColors.textLight),
                    SizedBox(width: 8),
                    Text(
                      'Back to Login',
                      style: TextStyle(color: AppColors.textLight),
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
}
