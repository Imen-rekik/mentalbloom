import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/name_entry_screen.dart';
import 'screens/main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // provider to inject the auth service
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FirebaseService())],
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

//
//
//
// controls what screen to return based on auth data
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseService?>(context);

    if (authService == null) {
      return const LoginScreen();
    }

    if (!authService.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authService.isUnverified) {
      return const EmailVerificationScreen();
    }

    if (authService.isLoggedIn && authService.currentUserName.isEmpty) {
      // user recognized, no name
      return const NameEntryScreen();
    } else if (authService.isLoggedIn) {
      // logged in + named
      return const MainLayout();
    } else {
      // not logged in
      return const LoginScreen();
    }
  }
}
