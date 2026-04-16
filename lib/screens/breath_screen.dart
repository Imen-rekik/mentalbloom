import 'dart:math';
import 'package:flutter/material.dart';

class BreathScreen extends StatefulWidget {
  const BreathScreen({super.key});

  @override
  State<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends State<BreathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  int _currentRound = 1;
  final int _maxRounds = 5;
  bool _isSessionComplete = false;

  final double _inhaleTimeSec = 4.0;
  final double _holdTimeSec = 7.0;
  final double _exhaleTimeSec = 8.0;
  late final double _totalTimeSec;

  @override
  void initState() {
    super.initState();
    _totalTimeSec = _inhaleTimeSec + _holdTimeSec + _exhaleTimeSec;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalTimeSec * 1000).toInt()),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_currentRound < _maxRounds) {
          setState(() {
            _currentRound++;
          });
          _controller.forward(from: 0.0);
        } else {
          setState(() {
            _isSessionComplete = true;
          });
        }
      }
    });

    _controller.addListener(() {
      setState(() {});
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPhaseText(double t) {
    if (t < _inhaleTimeSec / _totalTimeSec) return "Breathe In";
    if (t < (_inhaleTimeSec + _holdTimeSec) / _totalTimeSec) return "Hold";
    return "Breathe Out";
  }

  double _getPhaseProgress(double t) {
    double inhaleEnd = _inhaleTimeSec / _totalTimeSec;
    double holdEnd = (_inhaleTimeSec + _holdTimeSec) / _totalTimeSec;

    if (t < inhaleEnd) {
      return t / inhaleEnd;
    } else if (t < holdEnd) {
      return (t - inhaleEnd) / (holdEnd - inhaleEnd);
    } else {
      return (t - holdEnd) / (1.0 - holdEnd);
    }
  }

  double _getOrbScale(double t) {
    double inhaleEnd = _inhaleTimeSec / _totalTimeSec;
    double holdEnd = (_inhaleTimeSec + _holdTimeSec) / _totalTimeSec;

    if (t <= inhaleEnd) {
      return 1.0 + (0.35 * (t / inhaleEnd));
    } else if (t <= holdEnd) {
      return 1.35;
    } else {
      double exhaleProgress = (t - holdEnd) / (1.0 - holdEnd);
      double curve = Curves.easeInOutSine.transform(exhaleProgress);
      return 1.35 - (0.35 * curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF1B2A30);
    final orbGradient = const RadialGradient(
      colors: [Color(0xFF67B5B6), Color(0xFF337980)],
      radius: 0.8,
    );
    final hilightColor = const Color(0xFFA3D5D3);
    final orbShadowColor = const Color(0xFF337980);

    double t = _controller.value;
    String phaseText = _isSessionComplete ? "Done" : _getPhaseText(t);
    double phaseProgress = _isSessionComplete ? 1.0 : _getPhaseProgress(t);
    double orbScale = _isSessionComplete ? 1.0 : _getOrbScale(t);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              Stack(
                alignment: Alignment.center,
                children: [
                  // Radial Background Glow
                  Transform.scale(
                    scale: orbScale * 1.5,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            hilightColor.withValues(alpha: 0.15),
                            Colors.transparent
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Concentric Outer Rings
                  Transform.scale(
                    scale: orbScale * 1.25,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: hilightColor.withValues(alpha: 0.1),
                            width: 1.5),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: orbScale * 1.12,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: hilightColor.withValues(alpha: 0.25),
                            width: 2),
                      ),
                    ),
                  ),

                  // Main Orb and Progress Arc
                  Transform.scale(
                    scale: orbScale,
                    child: CustomPaint(
                      painter: ProgressArcPainter(
                        progress: phaseProgress,
                        arcColor: hilightColor,
                        bgColor: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: orbGradient,
                          boxShadow: [
                            BoxShadow(
                              color: orbShadowColor.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 8,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            phaseText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              const Text(
                "4 · 7 · 8 method",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              if (!_isSessionComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    "Round $_currentRound of $_maxRounds",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hilightColor,
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                  ),
                  child: const Text("Session Complete - Return",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color bgColor;

  ProgressArcPainter({
    required this.progress,
    required this.arcColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 8; // Rendered slightly outside the container

    final trackPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final progressPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
