import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'journal_screen.dart';
import 'mood_entry_screen.dart';
import 'relax_screen.dart';
import 'chatbot_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // list of screens for the bottom navigation
  final List<Widget> _screens = [
    const DashboardScreen(),
    const JournalScreen(),
    const MoodEntryScreen(),
    const RelaxScreen(), // Will contain breathe and sound
    const ChatbotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // all labels always visible
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight.withOpacity(0.5),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sentiment_satisfied_alt),
            label: 'Mood',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spa), // Swapped from self_improvement to spa
            label: 'Relax',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
