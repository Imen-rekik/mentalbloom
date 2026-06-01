import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import 'history_analytics_screen.dart';
import 'mood_details_screen.dart';
import 'quick_relief_modal.dart';

class MoodCheckInSection extends StatefulWidget {
  const MoodCheckInSection({super.key, required this.userName});

  final String userName;

  @override
  State<MoodCheckInSection> createState() => _MoodCheckInSectionState();
}

class _MoodCheckInSectionState extends State<MoodCheckInSection>
    with SingleTickerProviderStateMixin {
  // Arc goes from roughly 8-o'clock to 4-o'clock (≈ 200°)
  static const double _dialStartAngle = -math.pi * 0.78;
  static const double _dialSweepAngle = math.pi * 1.1;

  static const List<_MoodOption> _moods = [
    _MoodOption(
      label: 'Happy',
      headlineWord: 'HAPPY',
      submitWord: 'happy',
      faceGradient: [Color(0xFFFFD89E), Color(0xFFFFB347)],
    ),
    _MoodOption(
      label: 'Neutral',
      headlineWord: 'NEUTRAL',
      submitWord: 'neutral',
      faceGradient: [Color(0xFFC9A8F1), Color(0xFF8EB4F8)],
    ),
    _MoodOption(
      label: 'Sad',
      headlineWord: 'SAD',
      submitWord: 'sad',
      faceGradient: [Color(0xFF9EC5F8), Color(0xFF5B9EF4)],
    ),
    _MoodOption(
      label: 'Anxious',
      headlineWord: 'ANXIOUS',
      submitWord: 'anxious',
      faceGradient: [Color(0xFFD4A8F5), Color(0xFFAA6DD6)],
    ),
    _MoodOption(
      label: 'Angry',
      headlineWord: 'ANGRY',
      submitWord: 'angry',
      faceGradient: [Color(0xFFFFB0AD), Color(0xFFE86B6B)],
    ),
  ];

  static const Color _accentBlue = Color(0xFF2F8AE5);
  // How far to shift the dial center to the right (px)
  static const double _dialCenterXOffset = 40;

  int _selectedIndex = 1; // default to Neutral
  final GlobalKey _dialAreaKey = GlobalKey();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  late Timer _clockTimer;

  _MoodOption get _selectedMood => _moods[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
    );

    // Update the clock every 15 seconds to ensure it catches minute changes promptly
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  double _normalizeAngle(double angle) {
    var normalized = angle % (math.pi * 2);
    if (normalized < 0) {
      normalized += math.pi * 2;
    }
    return normalized;
  }

  double _clampToDialArc(double angle) {
    final start = _normalizeAngle(_dialStartAngle);
    final normalized = _normalizeAngle(angle);
    var relative = normalized - start;
    if (relative < 0) {
      relative += math.pi * 2;
    }

    if (relative > _dialSweepAngle) {
      final distanceToStart = relative;
      final distanceToEnd = (math.pi * 2 - relative) + _dialSweepAngle;
      relative = distanceToStart < distanceToEnd ? 0 : _dialSweepAngle;
    }

    return relative;
  }

  void _updateFromLocalPosition(Offset localPosition, Size size) {
    final center = Offset(size.width / 2 + _dialCenterXOffset, size.height / 2);
    final vector = localPosition - center;

    if (vector.distance < 40) {
      return;
    }

    final angle = math.atan2(vector.dy, vector.dx);
    final relative = _clampToDialArc(angle);
    final step = _dialSweepAngle / (_moods.length - 1);
    final rawIndex = (relative / step).round();
    final selectedIndex = (rawIndex as int).clamp(0, _moods.length - 1);

    if (selectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = selectedIndex;
      });
      // Trigger a little bounce on mood change
      _bounceAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
      );
      _bounceController.forward(from: 0);
    }
  }

  Widget _buildDateTimeWidget() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = 'Today, ${now.day} ${months[now.month - 1]}';
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    // A teal-blue color inspired by the photo and the dashboard's palette
    const color = Color(0xFF28B491);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildDatePicker(Icons.calendar_month_outlined, dateStr, color),
        const SizedBox(width: 12),
        _buildDatePicker(Icons.access_time_rounded, timeStr, color),
      ],
    );
  }

  Widget _buildDatePicker(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: color.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMoodDetails() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoodDetailsScreen(moodLabel: _selectedMood.label),
      ),
    );

    if (result == true && mounted) {
      showQuickReliefModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'How are you today?',
                  style: TextStyle(
                    fontSize: 22, // Slightly reduced to fit elements
                    fontWeight: FontWeight.w800,
                    color: _accentBlue,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _buildDateTimeWidget(),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the slider to describe how you\'re feeling.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E99A4),
              fontWeight: FontWeight.w400,
            ),
          ),

          // ── Dial Area ──
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final box =
                  _dialAreaKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null) return;
              _updateFromLocalPosition(details.localPosition, box.size);
            },
            onPanUpdate: (details) {
              final box =
                  _dialAreaKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null) return;
              _updateFromLocalPosition(details.localPosition, box.size);
            },
            child: SizedBox(
              key: _dialAreaKey,
              height: 260,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, 260);
                  // Where the face left edge starts
                  final faceLeftEdge = size.width / 2 + _dialCenterXOffset - 72;
                  return Stack(
                    children: [
                      // ── Background headline word (left of circle) ──
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: faceLeftEdge - 4,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: FittedBox(
                              key: ValueKey(_selectedMood.headlineWord),
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _selectedMood.headlineWord,
                                style: const TextStyle(
                                  fontSize: 68,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEDE5F5),
                                  letterSpacing: 1,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Arc track ──
                      CustomPaint(
                        size: size,
                        painter: _MoodDialPainter(
                          selectedIndex: _selectedIndex,
                          activeColor: _accentBlue,
                        ),
                      ),

                      // ── Emoji face with bounce (shifted right) ──
                      Positioned(
                        left: size.width / 2 + _dialCenterXOffset - 72.5,
                        top: 260 / 2 - 72.5,
                        child: AnimatedBuilder(
                          animation: _bounceAnim,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _bounceAnim.value,
                              child: child,
                            );
                          },
                          child: _MoodFace(mood: _selectedMood),
                        ),
                      ),

                      // ── Thumb ──
                      Positioned.fill(
                        child: _MoodDialThumb(
                          selectedIndex: _selectedIndex,
                          activeColor: _accentBlue,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Submit button ──
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: _openMoodDetails,
              child: Container(
                constraints: const BoxConstraints(minWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _accentBlue.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _accentBlue,
                    ),
                    children: [
                      TextSpan(
                        text: 'I\'m feeling ${_selectedMood.submitWord}. ',
                      ),
                      const TextSpan(
                        text: 'Submit →',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ── Streak Row ──
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              final service = context.watch<FirebaseService>();
              final streak = service.moodStreak;
              final longest = service.longestStreak;

              // Robust formatting to handle potential nulls during initialization
              String _formatDays(dynamic n) {
                final count = n is int ? n : 0;
                return count == 1 ? '1 day' : '$count days';
              }

              return Row(
                children: [
                  // ── Current Streak 🔥 ──
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFB74D,
                            ).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("🔥", style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            _formatDays(streak),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "Current",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── Best Streak 🏆 ──
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFB74D,
                            ).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("🏆", style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            _formatDays(longest),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "Best",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Thumb indicator on the arc
// ─────────────────────────────────────────────────────────
class _MoodDialThumb extends StatelessWidget {
  const _MoodDialThumb({
    required this.selectedIndex,
    required this.activeColor,
  });

  final int selectedIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(
          size.width / 2 + _MoodCheckInSectionState._dialCenterXOffset,
          size.height / 2,
        );
        final radius = size.shortestSide / 2 - 30;
        const step = _MoodCheckInSectionState._dialSweepAngle / 4;
        final angle =
            _MoodCheckInSectionState._dialStartAngle + selectedIndex * step;
        final thumbOffset = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );

        return Stack(
          children: [
            // Glow behind thumb
            Positioned(
              left: thumbOffset.dx - 18,
              top: thumbOffset.dy - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            // Solid thumb
            Positioned(
              left: thumbOffset.dx - 13,
              top: thumbOffset.dy - 13,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  The big gradient circle face in the center
// ─────────────────────────────────────────────────────────
class _MoodFace extends StatelessWidget {
  const _MoodFace({required this.mood});

  final _MoodOption mood;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: 145,
      height: 145,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: mood.faceGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: mood.faceGradient.last.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: CustomPaint(painter: _MoodFacePainter(mood: mood)),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Custom-painted face expressions
// ─────────────────────────────────────────────────────────
class _MoodFacePainter extends CustomPainter {
  const _MoodFacePainter({required this.mood});

  final _MoodOption mood;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final eyePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final mouthPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final browPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leftEye = Offset(center.dx - 22, center.dy - 8);
    final rightEye = Offset(center.dx + 22, center.dy - 8);

    switch (mood.label) {
      case 'Happy':
        // Squinty happy arcs for eyes
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 18, height: 12),
          math.pi,
          math.pi,
          false,
          eyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 18, height: 12),
          math.pi,
          math.pi,
          false,
          eyePaint,
        );
        // Smile
        canvas.drawArc(
          Rect.fromCenter(
            center: center + const Offset(0, 16),
            width: 38,
            height: 26,
          ),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          mouthPaint,
        );
        break;

      case 'Neutral':
        // Closed eyes – gentle downward arcs (like the photo)
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 18, height: 10),
          math.pi,
          math.pi,
          false,
          eyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 18, height: 10),
          math.pi,
          math.pi,
          false,
          eyePaint,
        );
        // Straight mouth
        canvas.drawLine(
          center + const Offset(-13, 18),
          center + const Offset(13, 18),
          mouthPaint,
        );
        break;

      case 'Sad':
        // Slightly downward eyes
        canvas.drawLine(
          leftEye + const Offset(-8, 1),
          leftEye + const Offset(8, -1),
          eyePaint,
        );
        canvas.drawLine(
          rightEye + const Offset(-8, -1),
          rightEye + const Offset(8, 1),
          eyePaint,
        );
        // Frown
        canvas.drawArc(
          Rect.fromCenter(
            center: center + const Offset(0, 26),
            width: 32,
            height: 22,
          ),
          math.pi,
          math.pi - 0.1,
          false,
          mouthPaint,
        );
        break;

      case 'Anxious':
        // Worried open eyes
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 16, height: 10),
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.82)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 16, height: 10),
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.82)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        // Wavy mouth
        final wavePath = Path()
          ..moveTo(center.dx - 14, center.dy + 18)
          ..cubicTo(
            center.dx - 7,
            center.dy + 14,
            center.dx + 7,
            center.dy + 22,
            center.dx + 14,
            center.dy + 18,
          );
        canvas.drawPath(wavePath, mouthPaint);
        // Worried brows
        canvas.drawLine(
          leftEye + const Offset(-6, -12),
          leftEye + const Offset(6, -17),
          browPaint,
        );
        canvas.drawLine(
          rightEye + const Offset(-6, -17),
          rightEye + const Offset(6, -12),
          browPaint,
        );
        break;

      case 'Angry':
        // Angry narrow eyes
        canvas.drawLine(
          leftEye + const Offset(-8, 1),
          leftEye + const Offset(8, -1),
          eyePaint,
        );
        canvas.drawLine(
          rightEye + const Offset(-8, -1),
          rightEye + const Offset(8, 1),
          eyePaint,
        );
        // Tight mouth
        canvas.drawLine(
          center + const Offset(-11, 20),
          center + const Offset(11, 20),
          mouthPaint,
        );
        // Angry V-brows
        canvas.drawLine(
          leftEye + const Offset(-7, -15),
          leftEye + const Offset(7, -8),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawLine(
          rightEye + const Offset(-7, -8),
          rightEye + const Offset(7, -15),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MoodFacePainter oldDelegate) {
    return oldDelegate.mood != mood;
  }
}

// ─────────────────────────────────────────────────────────
//  The semicircular arc + tick marks
// ─────────────────────────────────────────────────────────
class _MoodDialPainter extends CustomPainter {
  const _MoodDialPainter({
    required this.selectedIndex,
    required this.activeColor,
  });

  final int selectedIndex;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2 + _MoodCheckInSectionState._dialCenterXOffset,
      size.height / 2,
    );
    final radius = size.shortestSide / 2 - 30;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const step = _MoodCheckInSectionState._dialSweepAngle / 4;

    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFFE8EAF0)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      _MoodCheckInSectionState._dialStartAngle,
      _MoodCheckInSectionState._dialSweepAngle,
      false,
      trackPaint,
    );

    // Active portion of arc
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = activeColor.withValues(alpha: 0.30);
    canvas.drawArc(
      rect,
      _MoodCheckInSectionState._dialStartAngle,
      selectedIndex * step,
      false,
      activePaint,
    );

    // Tick marks at each mood position
    for (var index = 0; index < 5; index++) {
      final angle = _MoodCheckInSectionState._dialStartAngle + index * step;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final isSelected = index == selectedIndex;

      canvas.drawCircle(
        point,
        isSelected ? 5 : 3,
        Paint()..color = isSelected ? activeColor : const Color(0xFFD3D8E5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoodDialPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.activeColor != activeColor;
  }
}

// ─────────────────────────────────────────────────────────
//  Mood option data class
// ─────────────────────────────────────────────────────────
class _MoodOption {
  const _MoodOption({
    required this.label,
    required this.headlineWord,
    required this.submitWord,
    required this.faceGradient,
  });

  final String label;
  final String headlineWord;
  final String submitWord;
  final List<Color> faceGradient;
}
