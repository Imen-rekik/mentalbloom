import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_colors.dart';
import 'services/firebase_service_mock.dart';
import 'screens/login_screen.dart';
import 'screens/name_entry_screen.dart';
import 'screens/main_layout.dart';

void main() {
  // We use Provider to inject the auth service to the whole app.
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FirebaseServiceMock())],
      child: const MentalBloomApp(),
    ),
  );
}

// main app widget (app structure):  theme, app name, first screen
class MentalBloomApp extends StatelessWidget {
  const MentalBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MentalBloom',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// controls what screen to return based on auth data
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Look at isLoggedIn and current name status
    final authService = Provider.of<FirebaseServiceMock>(context);

    if (authService.isLoggedIn && authService.currentUserName.isEmpty) {
      // Step 2: User is recognized, but we don't know their name yet
      return const NameEntryScreen();
    } else if (authService.isLoggedIn) {
      // Step 3: Fully logged in and named
      return const MainLayout();
    } else {
      // Step 1: Not logged in
      return const LoginScreen();
    }
  }
}
