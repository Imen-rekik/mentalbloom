import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PodcastEpisode {
  final String title;
  final String podcastName;
  final int durationMin;
  final String audioUrl;
  final String emoji;
  final Color bgColor;
  final Color textColor;

  const PodcastEpisode({
    required this.title,
    required this.podcastName,
    required this.durationMin,
    required this.audioUrl,
    required this.emoji,
    required this.bgColor,
    required this.textColor,
  });
}

class PodcastProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PodcastEpisode? _currentEpisode;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PodcastEpisode? get currentEpisode => _currentEpisode;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  PodcastProvider() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      _duration = newDuration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });
  }

  Future<void> playEpisode(PodcastEpisode episode) async {
    if (_currentEpisode == episode && _isPlaying) return;

    if (_currentEpisode != episode) {
      _currentEpisode = episode;
      _position = Duration.zero;
      _duration = Duration(
        minutes: episode.durationMin,
      ); // fallback before load
      notifyListeners();
      await _audioPlayer.play(UrlSource(episode.audioUrl));
    } else {
      await _audioPlayer.resume();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> skipForward15() async {
    final target = _position + const Duration(seconds: 15);
    await seek(target > _duration ? _duration : target);
  }

  Future<void> skipBackward15() async {
    final target = _position - const Duration(seconds: 15);
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
