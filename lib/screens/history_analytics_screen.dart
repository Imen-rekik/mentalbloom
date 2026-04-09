import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';

class HistoryAnalyticsScreen extends StatelessWidget {
  const HistoryAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final streak = Provider.of<FirebaseServiceMock>(context).moodStreak;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Statistics', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Past 7 Days Card (Charts)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Past 7 days", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                   const SizedBox(height: 32),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       _buildBar('Mon', 4, AppColors.accent),
                       _buildBar('Tue', 6, AppColors.accent),
                       _buildBar('Wed', 3, AppColors.accent),
                       _buildBar('Thu', 7, AppColors.accent),
                       _buildBar('Fri', 5, AppColors.accent),
                       _buildBar('Sat', 8, AppColors.primary), // Highlighted current day
                       _buildBar('Sun', 6, AppColors.accent),
                     ],
                   )
                ]
              )
            ),
            const SizedBox(height: 24),
            
            // Mood Distribution
            const Align(
               alignment: Alignment.centerLeft, 
               child: Text("Mood Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain))
            ),
            const SizedBox(height: 12),
            Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: AppColors.white, 
                 borderRadius: BorderRadius.circular(24),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
               ),
               child: Column(
                  children: [
                     _buildMoodRow('😊', 0.7, '4x', const Color(0xFFFFCA28)), // Golden Yellow
                     const SizedBox(height: 16),
                     _buildMoodRow('😐', 0.4, '2x', const Color(0xFFB0BEC5)), // Grey
                     const SizedBox(height: 16),
                     _buildMoodRow('😢', 0.2, '1x', const Color(0xFF90CAF9)), // Light Blue
                  ]
               )
            ),
            const SizedBox(height: 24),
            
            // Insights Footer
            Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2), // Soft background tint
                  borderRadius: BorderRadius.circular(24),
               ),
               child: Column(
                  children: [
                     Row(
                       children: [
                         const Text("🔥", style: TextStyle(fontSize: 18)), 
                         const SizedBox(width: 12), 
                         Expanded(child: Text("You've logged your mood $streak days in a row!", style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w500)))
                       ]
                     ),
                     const SizedBox(height: 16),
                     const Row(
                       children: [
                         Text("😊", style: TextStyle(fontSize: 18)), 
                         SizedBox(width: 12), 
                         Expanded(child: Text("You feel happier on days with longer journal entries", style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w500)))
                       ]
                     ),
                  ]
               )
            ),
            const SizedBox(height: 40),
          ]
        )
      )
    );
  }

  // Helper for Bar Chart
  Widget _buildBar(String day, int heightMult, Color color) {
     final bool isHighest = color == AppColors.primary;
     
     return Column(
        children: [
           Container(
              width: 35, 
              height: heightMult * 12.0, 
              decoration: BoxDecoration(
                color: isHighest ? color : color.withOpacity(0.5), 
                borderRadius: BorderRadius.circular(8),
              )
           ),
           const SizedBox(height: 12),
           Text(day, style: TextStyle(fontSize: 12, color: isHighest ? AppColors.primary : AppColors.textLight, fontWeight: isHighest ? FontWeight.bold : FontWeight.normal))
        ]
     );
  }

  // Helper for Progress Bars
  Widget _buildMoodRow(String emoji, double percent, String count, Color color) {
     return Row(
        children: [
           Text(emoji, style: const TextStyle(fontSize: 22)),
           const SizedBox(width: 16),
           Expanded(
              child: Stack(
                 children: [
                    Container(height: 12, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6))),
                    FractionallySizedBox(
                       widthFactor: percent,
                       child: Container(height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                    )
                 ]
              )
           ),
           const SizedBox(width: 16),
           Text(count, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 16)),
        ]
     );
  }
}
