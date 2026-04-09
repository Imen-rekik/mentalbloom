import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_colors.dart';

class GratitudeJarScreen extends StatefulWidget {
  const GratitudeJarScreen({super.key});

  @override
  State<GratitudeJarScreen> createState() => _GratitudeJarScreenState();
}

class _GratitudeJarScreenState extends State<GratitudeJarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _shakeAnimation;

  final List<String> _quotes = [
    "You are capable of amazing things.",
    "Breathe in courage, exhale doubt.",
    "Every day is a fresh start.",
    "Your feelings are valid.",
    "Progress, not perfection.",
    "You are stronger than you think.",
    "Be kind to your mind.",
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Creates a rigid physical shake effect for a heavy jar
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _revealGratitude() async {
    await _animController.forward(from: 0.0);
    final randomQuote = _quotes[Random().nextInt(_quotes.length)];

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🍬", style: TextStyle(fontSize: 60)),
              const SizedBox(height: 24),
              const Text(
                "A Sweet Message",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 16),
              Text(
                '"$randomQuote"',
                style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: AppColors.textLight, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily Gratitude', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Need a little boost?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 12),
            const Text(
              "Tap the jar to pick a candy thought.",
              style: TextStyle(fontSize: 16, color: AppColors.textLight),
            ),
            const SizedBox(height: 60),
            
            // Cute, recognizable Mason Jar layout
            GestureDetector(
              onTap: _revealGratitude,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _shakeAnimation.value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Jar Lid
                    Container(
                      width: 140,
                      height: 35,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB0BEC5), // Silver/Grey metal lid
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        border: Border.all(color: const Color(0xFF90A4AE), width: 2),
                      ),
                      child: Center(
                        child: Container(width: 120, height: 4, color: Colors.black.withOpacity(0.05)), // Line texture
                      ),
                    ),
                    
                    // Jar Neck
                    Container(
                      width: 120,
                      height: 15,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.5),
                        border: const Border(
                          left: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                    
                    // Jar Body
                    Container(
                      width: 220,
                      height: 250,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15), // Very light soft turquoise glass
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: [
                           BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 30, spreadRadius: 5)
                        ]
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow reflection for glass
                          Positioned(
                            left: 10,
                            top: 20,
                            child: Container(
                              width: 15,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10)
                              ),
                            )
                          ),

                          // Candies physically residing at the bottom
                          const Positioned(bottom: 10, left: 30, child: Text("🍬", style: TextStyle(fontSize: 45))),
                          const Positioned(bottom: 15, right: 35, child: Text("🍭", style: TextStyle(fontSize: 40))),
                          const Positioned(bottom: 55, left: 55, child: Text("🍫", style: TextStyle(fontSize: 35))),
                          const Positioned(bottom: 60, right: 30, child: Text("🍬", style: TextStyle(fontSize: 45))),
                          const Positioned(bottom: 25, child: Text("🍭", style: TextStyle(fontSize: 48))),
                          const Positioned(bottom: 75, left: 80, child: Text("🍬", style: TextStyle(fontSize: 40))),

                          // Vintage Label "Gratitude"
                          Positioned(
                            top: 60,
                            child: Container(
                              width: 130,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                "Gratitude",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain, letterSpacing: 1.2),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
