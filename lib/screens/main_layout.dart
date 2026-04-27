import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_prompt_service.dart';
import 'dashboard_screen.dart';
import 'journal_screen.dart';
import 'relax_screen.dart';
import 'chatbot_screen.dart';
import 'podcast_screen.dart';
import 'notification_permission_prompt.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<FirebaseService>().loadJournals();
      _maybeShowNotificationPrompt();
      NotificationScheduler.instance.scheduleDailyReminders();
      _consumePendingNotificationTarget();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingNotificationTarget();
    }
  }

  Future<void> _maybeShowNotificationPrompt() async {
    final shouldShow = await NotificationPromptService.shouldShowPrompt();
    if (!mounted || !shouldShow) {
      return;
    }

    final action = await showDialog<NotificationPromptAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NotificationPermissionPrompt(),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == NotificationPromptAction.granted) {
      await NotificationPromptService.clearDeferral();
      if (!mounted) {
        return;
      }

      await NotificationScheduler.instance.scheduleDailyReminders();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications are on. Gentle reminders are enabled.'),
        ),
      );
      return;
    }

    await NotificationPromptService.deferForOneDay();
  }

  Future<void> _consumePendingNotificationTarget() async {
    final target = await NotificationScheduler.instance.consumePendingTarget();
    if (!mounted || target == null) {
      return;
    }

    if (target == NotificationTarget.moodCheckIn) {
      setState(() {
        _currentIndex = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dashboardKey.currentState?.scrollToMoodCheckIn();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(key: _dashboardKey),
      const ChatbotScreen(),
      const PodcastScreen(),
      const JournalScreen(),
      const RelaxScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
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
        unselectedItemColor: AppColors.textLight.withValues(alpha: 0.5),
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
            icon: Icon(Icons.forum_outlined),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.headphones),
            label: 'Podcasts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spa),
            label: 'Relax',
          ),
        ],
      ),
    );
  }
}
