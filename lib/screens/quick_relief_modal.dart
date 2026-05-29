import 'package:flutter/material.dart';
import 'chatbot_screen.dart';
import 'journal_screen.dart';
import 'relax_screen.dart';
import 'podcast_screen.dart';

void showQuickReliefModal(BuildContext context) {
  showDialog(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (BuildContext context) {
      return const QuickReliefOverlay();
    },
  );
}

class QuickReliefOverlay extends StatelessWidget {
  const QuickReliefOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Quick Relief',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 40),

                // Central circle area
                Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _OptionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Talk it out',
                        color: const Color(0xFF5B9EF4), // App blue
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatbotScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _OptionButton(
                        icon: Icons.edit_note,
                        label: 'Write it down',
                        color: const Color(0xFFF472B6), // App pink
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const JournalScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _OptionButton(
                        icon: Icons.self_improvement,
                        label: 'Relax',
                        color: const Color(0xFF8EB4F8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RelaxScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _OptionButton(
                        icon: Icons.headphones,
                        label: 'Listen to a podcast',
                        color: const Color(0xFFC9A8F1),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PodcastScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // White X button at bottom
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF2F8AE5), // Primary App color
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
