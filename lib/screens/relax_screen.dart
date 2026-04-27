import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'breath_screen.dart';

class RelaxScreen extends StatefulWidget {
  final bool autoScrollToSounds;

  const RelaxScreen({super.key, this.autoScrollToSounds = false});

  @override
  State<RelaxScreen> createState() => _RelaxScreenState();
}

class _RelaxScreenState extends State<RelaxScreen> {
  late AudioPlayer _audioPlayer;
  String _activeSound = "";
  double _volume = 0.70;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  // Sound mapping uses bundled assets only.
  final List<Map<String, String>> _sounds = [
    {'name': 'Quran', 'icon': '🕌', 'asset': 'audio/q.mp3'},
    {'name': 'Rain', 'icon': '🌧️', 'asset': 'audio/rain.mp3'},
    {'name': 'Forest', 'icon': '🌲', 'asset': 'audio/forest.mp3'},
    {'name': 'Ocean', 'icon': '🌊', 'asset': 'audio/ocean.mp3'},
    {'name': 'Fire', 'icon': '🔥', 'asset': 'audio/fire.mp3'},
    {'name': 'River', 'icon': '🏞️', 'asset': 'audio/river.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(_volume);

    // Listen to player state changes to manage loading state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isLoading = false;
        _isPlaying = (state == PlayerState.playing);
      });
    });

    _audioPlayer.onLog.listen((msg) {
      debugPrint("AudioPlayer Log: $msg");
    });

    if (widget.autoScrollToSounds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            400.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundName, String? assetPath) async {
    try {
      if (_activeSound == soundName) {
        await _audioPlayer.stop();
        setState(() {
          _activeSound = "";
          _isLoading = false;
          _isPlaying = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = null;
          _isLoading = true;
          _activeSound = soundName;
        });

        if (assetPath != null && assetPath.isNotEmpty) {
          await _audioPlayer.stop();
          await _audioPlayer.setVolume(_volume);
          if (kIsWeb) {
            await _audioPlayer.play(UrlSource('assets/assets/$assetPath'));
          } else {
            await _audioPlayer.play(AssetSource(assetPath));
          }
        } else {
          setState(() {
            _isLoading = false;
            _activeSound = "";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No URL provided for $soundName")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error playing sound: $e");
      setState(() {
        _isLoading = false;
        _activeSound = "";
        _errorMessage = "Failed to load audio. Please check your connection.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error playing sound: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF1B2A30);
    final cardColor = const Color(0xFF26363B);
    final hilightColor = const Color(0xFFA3D5D3);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.canPop(context))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: const [
                        Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      ],
                    ),
                  ),
                ),
              const Text(
                'Relax & Breathe',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              // Hero Card for Breathing Exercise
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BreathScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF337980), Color(0xFF26363B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: hilightColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.air, color: Colors.white, size: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              "4-7-8 Method",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Breathing Exercise",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap to start your guided session",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Divider(
                color: Colors.white.withValues(alpha: 0.05),
                thickness: 2,
              ),
              const SizedBox(height: 30),

              // Ambient Sounds Section
              const Text(
                'Ambient Sounds',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: _sounds.map((sound) {
                  final isSelected = _activeSound == sound['name'];
                  final isCurrentlyLoading = isSelected && _isLoading;

                  return GestureDetector(
                    onTap: () => _playSound(sound['name']!, sound['asset']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? hilightColor : cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? hilightColor : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: hilightColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrentlyLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1B2A30),
                              ),
                            )
                          else if (_isPlaying && isSelected)
                            const Text('⏹️', style: TextStyle(fontSize: 18))
                          else
                            Text(
                              sound['icon']!,
                              style: const TextStyle(fontSize: 18),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            sound['name']!,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1B2A30)
                                  : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Volume Slider
              const Text(
                'Volume',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.volume_down,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      activeColor: hilightColor,
                      inactiveColor: cardColor,
                      onChanged: (val) {
                        setState(() => _volume = val);
                        _audioPlayer.setVolume(val);
                      },
                    ),
                  ),
                  Icon(
                    Icons.volume_up,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
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
