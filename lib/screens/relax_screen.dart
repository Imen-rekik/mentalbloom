import 'package:flutter/material.dart';

class RelaxScreen extends StatefulWidget {
  const RelaxScreen({super.key});

  @override
  State<RelaxScreen> createState() => _RelaxScreenState();
}

class _RelaxScreenState extends State<RelaxScreen> with TickerProviderStateMixin {
  AnimationController? _breathingController;
  late Animation<double> _breatheAnimation;
  
  String _activeSound = "";
  double _volume = 0.70;
  String _activeMode = "Focus";
  String _breathingText = "Breathe In...";

  final List<Map<String, String>> _sounds = [
    {'name': 'Rain', 'icon': '🌧️'},
    {'name': 'Storm', 'icon': '⛈️'},
    {'name': 'Forest', 'icon': '🌲'},
    {'name': 'Fire', 'icon': '🔥'},
    {'name': 'Birds', 'icon': '🐦'},
    {'name': 'Wind', 'icon': '💨'},
    {'name': 'River', 'icon': '🏞️'},
    {'name': 'Quran', 'icon': '🕌'},
  ];

  @override
  void initState() {
    super.initState();
    _setupBreathingMode("Focus"); // Start with Box Breathing
  }

  void _setupBreathingMode(String mode) {
    if (_breathingController != null) {
      _breathingController!.dispose();
    }

    _activeMode = mode;
    int durationSecs = 16; 
    TweenSequence<double> sequence = TweenSequence([]);

    if (mode == "Focus") {
      durationSecs = 16;
      sequence = TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 25), 
        TweenSequenceItem(tween: ConstantTween(1.2), weight: 25), 
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.6).chain(CurveTween(curve: Curves.easeInOut)), weight: 25), 
        TweenSequenceItem(tween: ConstantTween(0.6), weight: 25), 
      ]);
    } else if (mode == "Relax") {
      durationSecs = 19;
      sequence = TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 21.1),
        TweenSequenceItem(tween: ConstantTween(1.2), weight: 36.8),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.6).chain(CurveTween(curve: Curves.easeInOut)), weight: 42.1),
      ]);
    } else if (mode == "Sleep") {
      durationSecs = 12;
      sequence = TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.6).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      ]);
    }

    _breathingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSecs),
    );

    _breatheAnimation = sequence.animate(_breathingController!);

    _breathingController!.addListener(() {
      if (!mounted) return;
      double t = _breathingController!.value;
      String nextText = _calculateBreathingPhase(t, mode);
      if (nextText != _breathingText) {
        setState(() {
          _breathingText = nextText;
        });
      }
    });

    _breathingController!.repeat();
    if (mounted) setState(() {});
  }

  String _calculateBreathingPhase(double t, String mode) {
    if (mode == "Focus") {
      if (t < 0.25) return "Breathe In...";
      if (t < 0.5) return "Hold...";
      if (t < 0.75) return "Breathe Out...";
      return "Hold...";
    } else if (mode == "Relax") {
      if (t < 0.211) return "Breathe In...";
      if (t < 0.579) return "Hold...";
      return "Breathe Out...";
    } else if (mode == "Sleep") {
      if (t < 0.5) return "Deep Breathe In...";
      return "Deep Breathe Out...";
    }
    return "";
  }

  String _getModeDescription(String mode) {
    if (mode == "Focus") return "Box breathing: 4s in · 4s hold · 4s out · 4s hold";
    if (mode == "Relax") return "4-7-8 method: 4s in · 7s hold · 8s out";
    return "Deep sleep rhythm: 6s in · 6s out";
  }

  @override
  void dispose() {
    _breathingController?.dispose();
    super.dispose();
  }

  void _playSound(String soundName) {
    setState(() {
      if (_activeSound == soundName) {
        _activeSound = "";
      } else {
        _activeSound = soundName;
      }
    });
  }

  // Helper widget for Top Buttons
  Widget _buildTopButton(String title, String emoji, bool isSelected) {
    final bgColor = const Color(0xFF26363B);
    final hilightColor = const Color(0xFFA3D5D3);
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _setupBreathingMode(title),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? hilightColor : Colors.transparent, width: 2),
            boxShadow: [
              if (isSelected) BoxShadow(color: hilightColor.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF1B2A30);
    final cardColor = const Color(0xFF26363B);
    final hilightColor = const Color(0xFFA3D5D3);
    final circleDark = const Color(0xFF22343B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Relax & Breathe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              
              // Top Mode Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopButton("Relax", "😌", _activeMode == "Relax"),
                  _buildTopButton("Focus", "🎯", _activeMode == "Focus"),
                  _buildTopButton("Sleep", "🌙", _activeMode == "Sleep"),
                ],
              ),
              
              const SizedBox(height: 40),

              // Breathing Circle
              Center(
                child: ScaleTransition(
                  scale: _breatheAnimation,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleDark,
                      boxShadow: [
                        BoxShadow(
                           color: circleDark,
                           blurRadius: 20,
                           spreadRadius: 20,
                        )
                      ]
                    ),
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFF67B5B6), Color(0xFF337980)],
                            radius: 0.6,
                          )
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("🌬️", style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              _breathingText,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _getModeDescription(_activeMode),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              
              const SizedBox(height: 32),
              Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
              const SizedBox(height: 20),

              // Ambient Sounds Section
              const Text(
                'Ambient Sounds',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: _sounds.length,
                itemBuilder: (context, index) {
                  final sound = _sounds[index];
                  final isSelected = _activeSound == sound['name'];
                  
                  return GestureDetector(
                    onTap: () => _playSound(sound['name']!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? hilightColor : Colors.transparent, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(sound['icon']!, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 8),
                          Text(sound['name']!, style: TextStyle(color: isSelected? Colors.white : Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
              
              // Volume Slider
              const Text(
                'Volume',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("🌧️", style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      activeColor: hilightColor,
                      inactiveColor: cardColor,
                      onChanged: (val) => setState(() => _volume = val),
                    ),
                  ),
                  Text("${(_volume * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
