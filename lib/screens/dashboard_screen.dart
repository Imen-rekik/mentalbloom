import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import 'history_analytics_screen.dart';
import 'gratitude_jar_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseService>(context);
    final userName = authService.currentUserName.isNotEmpty
        ? authService.currentUserName
        : 'Friend';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //
                      //
                      // logo and logout
                      children: [
                        const Icon(Icons.spa, color: AppColors.white, size: 40),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.textMain,
                          ),
                          onPressed: () async {
                            await authService.logout();
                          },
                        ),
                      ],
                    ),
                    //
                    //
                    //
                    // welcome message
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textMain.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //
                    //
                    //
                    // quote
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textLight.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.format_quote,
                              color: AppColors.accent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Inspiration',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '"Some days you bloom, some days you rest—both matter"',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textMain,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    //
                    //
                    //
                    // explore
                    const SizedBox(height: 32),
                    const Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // history and graditude
                    GridView.count(
                      shrinkWrap:
                          true, // Let the grid take only the space it needs
                      physics:
                          const NeverScrollableScrollPhysics(), //disables scrolling for this grid.
                      crossAxisCount: 2, // number of columns
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      children: [
                        //
                        //
                        // mood tracker
                        _buildFeatureCard(
                          context,
                          title: 'Mood Tracker',
                          subtitle: 'See how your week shaped up',
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.secondary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistoryAnalyticsScreen(),
                            ),
                          ),
                        ),
                        //
                        //
                        // gratitude jar
                        _buildFeatureCard(
                          context,
                          title: 'Gratitude',
                          subtitle: 'Daily drops of joy',
                          icon: Icons.favorite,
                          color: AppColors.accent.withValues(alpha: 0.5),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GratitudeJarScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //
  //
  // make the card toppable
  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            //
            //
            //
            // icon background
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.textMain),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
