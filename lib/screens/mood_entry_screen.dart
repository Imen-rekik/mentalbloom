import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';

class MoodEntryScreen extends StatefulWidget {
  const MoodEntryScreen({super.key});

  @override
  State<MoodEntryScreen> createState() => _MoodEntryScreenState();
}

class _MoodEntryScreenState extends State<MoodEntryScreen> {
  // default mood
  String selectedMood = 'Neutral';
  double intensity = 5;

  // The list of moods
  final List<Map<String, String>> moods = [
    {'label': 'Happy', 'emoji': '😊'},
    {'label': 'Neutral', 'emoji': '😐'},
    {'label': 'Sad', 'emoji': '😢'},
    {'label': 'Anxious', 'emoji': '😟'},
    {'label': 'Angry', 'emoji': '😠'},
  ];

  void _saveMood() {
    Provider.of<FirebaseServiceMock>(
      context,
      listen: false,
    ).saveMood(selectedMood, intensity.toInt());
    final currentStreak = Provider.of<FirebaseServiceMock>(
      context,
      listen: false,
    ).moodStreak;

    // dialog for the streak
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 20,
        backgroundColor: const Color(0xFFFF8A65),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🔥", style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text(
                "Streak Increased!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You are on a $currentStreak day fire streak!\nKeep tracking your feelings.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Awesome!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8A65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Track Mood',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How are you feeling?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Emoji Selection Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: moods.map((mood) {
                final isSelected = selectedMood == mood['label'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedMood = mood['label']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Text(
                      mood['emoji']!,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Text(
              selectedMood,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            // Intensity Slider
            const Text(
              'Intensity (1 - 10)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            Slider(
              value: intensity,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.white,
              label: intensity.toInt().toString(),
              onChanged: (double newValue) {
                setState(() {
                  intensity = newValue;
                });
              },
            ),

            const Spacer(),

            // Save Button
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveMood,
                child: const Text(
                  'Save Mood',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
