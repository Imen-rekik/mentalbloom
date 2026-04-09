import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

//state class
class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final TextEditingController userEmailInput = TextEditingController();
  final TextEditingController userPasswordInput = TextEditingController();
  bool isLoading = false;
  bool isLoginMode = true;

  void _handleSubmit() async {
    setState(() {
      isLoading = true;
    });

    // Access our fake Firebase auth
    final authService = Provider.of<FirebaseServiceMock>(
      context,
      listen: false,
    );

    // Choose behavior based on mode
    if (isLoginMode) {
      await authService.login(userEmailInput.text, userPasswordInput.text);
    } else {
      await authService.signup(userEmailInput.text, userPasswordInput.text);
    }

    // Checking mounted is a good practice when dealing with async functions
    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // mentalbloom logo
              const Icon(
                Icons.local_florist,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'MentalBloom',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your personal space to grow.',
                style: TextStyle(fontSize: 16, color: AppColors.textLight),
              ),
              const SizedBox(height: 48),

              // Email Field
              TextField(
                controller: userEmailInput,
                decoration: InputDecoration(
                  hintText: 'Email',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                controller: userPasswordInput,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleSubmit,
                        child: Text(
                          isLoginMode ? 'Log In' : 'Sign Up',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // Toggle Mode Button
              TextButton(
                onPressed: () {
                  setState(() {
                    isLoginMode = !isLoginMode;
                  });
                },
                child: Text(
                  isLoginMode
                      ? "Don't have an account? Sign Up"
                      : "Already have an account? Log In",
                  style: const TextStyle(color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
