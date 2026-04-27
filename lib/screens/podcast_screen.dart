import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/podcast_provider.dart';
import '../theme/app_colors.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {

  final List<PodcastEpisode> _allEpisodes = const [
    PodcastEpisode(
      title: "How stress rewires your brain",
      podcastName: "Andrew Huberman",
      durationMin: 48,
      audioUrl: "https://www.learningcontainer.com/wp-content/uploads/2020/02/Kalimba.mp3",
      emoji: "🧠",
      bgColor: Color(0xFFEEEDFE),
      textColor: Color(0xFF534AB7),
    ),
    PodcastEpisode(
      title: "Meditation for people who hate it",
      podcastName: "Dan Harris",
      durationMin: 32,
      audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
      emoji: "😄",
      bgColor: Color(0xFFEAF3DE),
      textColor: Color(0xFF3B6D11),
    ),
    PodcastEpisode(
      title: "5 tools to calm anxiety fast",
      podcastName: "Emma McAdam",
      durationMin: 24,
      audioUrl: "https://codeskulptor-demos.commondatastorage.googleapis.com/pang/paza-moduless.mp3",
      emoji: "🛋️",
      bgColor: Color(0xFFFBEAF0),
      textColor: Color(0xFF993556),
    ),
    PodcastEpisode(
      title: "Honest talk about the hard days",
      podcastName: "Paul Gilmartin",
      durationMin: 41,
      audioUrl: "https://codeskulptor-demos.commondatastorage.googleapis.com/descent/gotitem.mp3",
      emoji: "🗣️",
      bgColor: Color(0xFFFAEEDA),
      textColor: Color(0xFF854F0B),
    ),
    PodcastEpisode(
      title: "How to Optimize Your Sleep",
      podcastName: "Andrew Huberman",
      durationMin: 55,
      audioUrl: "https://www.learningcontainer.com/wp-content/uploads/2020/02/Kalimba.mp3",
      emoji: "🌙",
      bgColor: Color(0xFFE8EAF6),
      textColor: Color(0xFF3949AB),
    ),
    PodcastEpisode(
      title: "Using Meditation to Focus, Work & Create Better",
      podcastName: "Andrew Huberman",
      durationMin: 37,
      audioUrl: "https://codeskulptor-demos.commondatastorage.googleapis.com/descent/background%20music.mp3",
      emoji: "🧘",
      bgColor: Color(0xFFE0F2F1),
      textColor: Color(0xFF00695C),
    ),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFC9A8F1), Color(0xFF8EB4F8)],
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Podcasts",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              "for your wellbeing",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
            Consumer<PodcastProvider>(
              builder: (context, provider, child) {
                if (provider.currentEpisode != null) {
                  return _buildNowPlayingCard(provider);
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _allEpisodes.length,
                itemBuilder: (context, index) {
                  final episode = _allEpisodes[index];
                  return _buildEpisodeCard(episode, context);
                },
              ),
            ),
          ],
        ),
    );
  }



  Widget _buildNowPlayingCard(PodcastProvider provider) {
    final episode = provider.currentEpisode!;
    double progress = 0.0;
    if (provider.duration.inSeconds > 0) {
      progress = provider.position.inSeconds / provider.duration.inSeconds;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: episode.bgColor.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: episode.bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(episode.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        episode.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        episode.podcastName,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(episode.textColor),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.formatDuration(provider.position),
                  style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
                Text(
                  provider.formatDuration(provider.duration),
                  style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind),
                  color: AppColors.textMain,
                  onPressed: () => provider.skipBackward15(),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: episode.textColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                    iconSize: 32,
                    onPressed: () {
                      if (provider.isPlaying) {
                        provider.pause();
                      } else {
                        provider.playEpisode(episode);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fast_forward),
                  color: AppColors.textMain,
                  onPressed: () => provider.skipForward15(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(PodcastEpisode episode, BuildContext context) {
    final isCurrentlyPlaying = context.watch<PodcastProvider>().currentEpisode == episode;

    return GestureDetector(
      onTap: () {
        context.read<PodcastProvider>().playEpisode(episode);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCurrentlyPlaying
              ? Border.all(color: episode.textColor, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: episode.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(episode.emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.podcastName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [

                      const SizedBox(width: 8),
                      Text(
                        "${episode.durationMin} min",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCurrentlyPlaying ? Icons.volume_up : Icons.play_arrow,
                color: episode.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
