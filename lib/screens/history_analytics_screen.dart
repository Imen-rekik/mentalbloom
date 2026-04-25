import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/mood_summary_service.dart';
import '../theme/app_colors.dart';

class HistoryAnalyticsScreen extends StatefulWidget {
  const HistoryAnalyticsScreen({super.key});

  @override
  State<HistoryAnalyticsScreen> createState() => _HistoryAnalyticsScreenState();
}

class _HistoryAnalyticsScreenState extends State<HistoryAnalyticsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _moods = [];

  final MoodSummaryService _moodSummaryService = MoodSummaryService();
  final Map<String, String> _aiSummaries = {};
  final Map<String, bool> _summaryLoading = {};

  // Define our 5 emotions and their distinct colors
  final Map<String, Color> _emotionColors = {
    'Happy': const Color(0xFFFFB74D), // Warm Orange
    'Neutral': const Color(0xFF90A4AE), // Cool Grey
    'Sad': const Color(0xFF64B5F6), // Cool Blue
    'Anxious': const Color(0xFFBA68C8), // Purple
    'Angry': const Color(0xFFE57373), // Red
  };

  final Map<String, String> _emotionEmojis = {
    'Happy': '😊',
    'Neutral': '😐',
    'Sad': '😢',
    'Anxious': '😰',
    'Angry': '😠',
  };

  final Map<String, bool> _activeEmotions = {
    'Happy': true,
    'Neutral': true,
    'Sad': true,
    'Anxious': true,
    'Angry': true,
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    await service.loadJournals(); // Ensure journals are loaded for the summary
    final moods = await service.getMoodsForLast14Days();

    // Sort newest first
    moods.sort((a, b) {
      final aDate = a['createdAt'] as DateTime?;
      final bDate = b['createdAt'] as DateTime?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    if (mounted) {
      setState(() {
        _moods = moods;
        _isLoading = false;
      });
      _loadOrGenerateSummaries(service);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    int min = date.minute;
    String ampm = hour >= 12 ? 'pm' : 'am';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minStr = min.toString().padLeft(2, '0');
    return '$hour:$minStr $ampm';
  }

  Map<String, List<Map<String, dynamic>>> get _groupedMoods {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final mood in _moods) {
      final date = mood['createdAt'] as DateTime?;
      if (date != null) {
        final dateStr = _formatDate(date);
        if (!grouped.containsKey(dateStr)) {
          grouped[dateStr] = [];
        }
        grouped[dateStr]!.add(mood);
      }
    }
    return grouped;
  }

  Future<void> _loadOrGenerateSummaries(FirebaseService service) async {
    final grouped = _groupedMoods;
    for (final dateStr in grouped.keys) {
      final existingSummary = await service.getDailySummary(dateStr);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        if (mounted) {
          setState(() {
            _aiSummaries[dateStr] = existingSummary;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _summaryLoading[dateStr] = true;
          });
        }

        final moods = grouped[dateStr]!;
        String userDataText = "MOOD LOGS:\n";
        for (var m in moods) {
          final time = _formatTime(m['createdAt'] as DateTime);
          final label = m['label'];
          final intensity = m['intensity'];
          final notes = m['notes'] ?? 'None';
          final symptoms = (m['symptoms'] as List?)?.join(', ') ?? 'None';
          userDataText +=
              "- At $time: Mood=$label, Intensity=$intensity/10, Notes=$notes, Symptoms=$symptoms\n";
        }

        // Add journals if available for this date
        final dailyJournals = service.journals
            .where(
              (j) =>
                  j['date'] == dateStr ||
                  (j['date']?.contains(dateStr) ?? false),
            )
            .toList();
        if (dailyJournals.isNotEmpty) {
          userDataText += "\nJOURNAL ENTRIES:\n";
          for (var j in dailyJournals) {
            userDataText += "- ${j['title']}: ${j['content']}\n";
          }
        }

        final summary = await _moodSummaryService.generateDailySummary(
          dateStr,
          userDataText,
        );

        if (summary.isNotEmpty && !summary.startsWith('Summary unavailable')) {
          await service.saveDailySummary(dateStr, summary);
        }

        if (mounted) {
          setState(() {
            if (summary.isNotEmpty) {
              _aiSummaries[dateStr] = summary;
            }
            _summaryLoading[dateStr] = false;
          });
        }
      }
    }
  }

  List<Map<String, double?>> _getDailyAverages() {
    final now = DateTime.now();
    final days = <Map<String, double?>>[];

    for (int i = 13; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayMoods = _moods.where((m) {
        final mDate = m['createdAt'] as DateTime?;
        if (mDate == null) return false;
        return mDate.year == date.year &&
            mDate.month == date.month &&
            mDate.day == date.day;
      }).toList();

      final Map<String, double?> dailyAvgs = {};

      for (final emotion in _emotionColors.keys) {
        final emotionMoods = dayMoods
            .where((m) => m['label'] == emotion)
            .toList();
        if (emotionMoods.isEmpty) {
          dailyAvgs[emotion] = null;
        } else {
          final sum = emotionMoods.fold(
            0,
            (prev, m) => prev + ((m['intensity'] as int?) ?? 0),
          );
          dailyAvgs[emotion] = sum / emotionMoods.length;
        }
      }

      days.add(dailyAvgs);
    }

    return days;
  }

  String _getShortDayName(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    switch (date.weekday) {
      case 1:
        return 'Mo';
      case 2:
        return 'Tu';
      case 3:
        return 'We';
      case 4:
        return 'Th';
      case 5:
        return 'Fr';
      case 6:
        return 'Sa';
      case 7:
        return 'Su';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Analytics & History',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMultiLineChart(),
                  const SizedBox(height: 32),
                  const Text(
                    "Daily Mood Logs",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDailyLogList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMultiLineChart() {
    final dailyAverages = _getDailyAverages();
    final bool isAllActive = _activeEmotions.values.every((v) => v);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mood Intensity Trends",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Your emotional intensity over the past 2 weeks",
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  "All",
                  "✨",
                  isAllActive,
                  Colors.grey.shade600,
                  () {
                    setState(() {
                      final newState = !isAllActive;
                      for (var key in _activeEmotions.keys) {
                        _activeEmotions[key] = newState;
                      }
                    });
                  },
                ),
                ..._emotionColors.keys.map((emotion) {
                  return _buildFilterChip(
                    emotion,
                    _emotionEmojis[emotion]!,
                    _activeEmotions[emotion]!,
                    _emotionColors[emotion]!,
                    () {
                      setState(() {
                        _activeEmotions[emotion] = !_activeEmotions[emotion]!;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Scrollable Bar Chart
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: 800, // Wide enough to show 14 days comfortably
              height: 250,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withValues(alpha: 0.3),
                        strokeWidth: (value == 0 || value == 10) ? 2.0 : 1.0,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final daysAgo = 13 - value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _getShortDayName(daysAgo),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == 10) {
                            return Transform.translate(
                              offset: const Offset(0, 12),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    "HIGH",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else if (value == 0) {
                            return Transform.translate(
                              offset: const Offset(0, -12),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    "LOW",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(14, (i) {
                    final rods = <BarChartRodData>[];
                    for (final emotion in _emotionColors.keys) {
                      if (!_activeEmotions[emotion]!) continue;
                      final avg = dailyAverages[i][emotion];
                      if (avg != null && avg > 0) {
                        rods.add(
                          BarChartRodData(
                            toY: avg,
                            color: _emotionColors[emotion],
                            width: 2,
                            borderRadius: BorderRadius.circular(0),
                          ),
                        );
                      }
                    }
                    return BarChartGroupData(x: i, barsSpace: 1, barRods: rods);
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String emoji,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? color : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyLogList() {
    final grouped = _groupedMoods;
    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Column(
            children: [
              Text('🌱', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text(
                "No entries yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "When you log your mood, it will appear here.",
                style: TextStyle(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: grouped.entries.map((entry) {
        final dateStr = entry.key;
        final dayMoods = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ...dayMoods.map((m) => _buildMoodTile(m)),
                    _buildAISummaryCard(dateStr),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMoodTile(Map<String, dynamic> mood) {
    final date = mood['createdAt'] as DateTime?;
    final timeStr = date != null ? _formatTime(date) : '';
    final label = mood['label'] as String? ?? 'Neutral';
    final intensity = mood['intensity'] as int? ?? 5;
    final color = _emotionColors[label] ?? Colors.grey;
    final emoji = _emotionEmojis[label] ?? '😐';

    return InkWell(
      onTap: () => _showMoodDetailDialog(mood),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.5), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "I'm feeling ${label.toLowerCase()}.",
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$label level: $intensity",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAISummaryCard(String dateStr) {
    final summary = _aiSummaries[dateStr];
    final isLoading = _summaryLoading[dateStr] == true;

    if (summary == null && !isLoading) {
      return const SizedBox.shrink(); // Don't show anything if no summary and not loading
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                "What shaped your day",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else
            Text(
              summary ?? "",
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMain,
              ),
            ),
        ],
      ),
    );
  }

  void _showMoodDetailDialog(Map<String, dynamic> mood) {
    final label = mood['label'] as String? ?? 'Neutral';
    final intensity = mood['intensity'] as int? ?? 5;
    final notes = mood['notes'] as String?;
    final symptomsList = mood['symptoms'] as List?;
    final color = _emotionColors[label] ?? Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "Level $intensity",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (symptomsList != null && symptomsList.isNotEmpty) ...[
                  const Text(
                    "Symptoms & Context",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: symptomsList
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              s.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const Text(
                    "Notes",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      notes,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMain,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
