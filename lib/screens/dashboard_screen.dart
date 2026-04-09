import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';
import 'history_analytics_screen.dart';
import 'gratitude_jar_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseServiceMock>(context);
    final userName = authService.currentUserName.isNotEmpty ? authService.currentUserName : 'Friend';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Top Banner
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
                      children: [
                        const Icon(Icons.spa, color: AppColors.white, size: 40),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.textMain),
                          onPressed: () => authService.logout(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back,',
                      style: TextStyle(fontSize: 18, color: AppColors.textMain.withOpacity(0.7)),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take a deep breath. You are doing great.',
                      style: TextStyle(fontSize: 16, color: AppColors.textMain),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quote of the Day Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textLight.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.format_quote, color: AppColors.accent, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Inspiration',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '"Peace comes from within. Do not seek it without."',
                                  style: TextStyle(fontSize: 16, color: AppColors.textMain, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      'Explore',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 16),

                    // Elegant Grid Navigation
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      children: [
                        _buildFeatureCard(
                          context,
                          title: 'My History',
                          subtitle: 'View your journey',
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.secondary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryAnalyticsScreen())),
                        ),
                        _buildFeatureCard(
                          context,
                          title: 'Gratitude',
                          subtitle: 'Daily drops of joy',
                          icon: Icons.volunteer_activism,
                          color: AppColors.accent.withOpacity(0.5),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GratitudeJarScreen())),
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

  Widget _buildFeatureCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.textMain),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
