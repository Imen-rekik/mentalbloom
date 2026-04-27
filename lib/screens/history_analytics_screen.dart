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
    'Happy': '✨',
    'Neutral': '⚖️',
    'Sad': '🌧️',
    'Anxious': '🌪️',
    'Angry': '🔥',
  };

  final Map<String, bool> _activeEmotions = {
    'Happy': true,
    'Neutral': true,
    'Sad': true,
    'Anxious': true,
    'Angry': true,
  };

  DateTime? _selectedListDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    await service.loadJournals(); // Ensure journals are loaded for the summary
    final moods = await service.getAllMoods();

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
      _loadSummaries(service);
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

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Map<String, List<Map<String, dynamic>>> get _groupedMoods {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final mood in _moods) {
      final date = mood['createdAt'] as DateTime?;
      if (date != null) {
        final dateStr = _formatDateKey(date);
        if (!grouped.containsKey(dateStr)) {
          grouped[dateStr] = [];
        }
        grouped[dateStr]!.add(mood);
      }
    }
    return grouped;
  }

  Future<void> _loadSummaries(FirebaseService service) async {
    final grouped = _groupedMoods;
    for (final dateStr in grouped.keys) {
      if (!_aiSummaries.containsKey(dateStr)) {
        if (mounted) {
          setState(() {
            _summaryLoading[dateStr] = true;
          });
        }
        
        final existingSummary = await service.getDailySummary(dateStr);
        
        if (existingSummary != null && existingSummary.isNotEmpty) {
          if (mounted) {
            setState(() {
              _aiSummaries[dateStr] = existingSummary;
              _summaryLoading[dateStr] = false;
            });
          }
        } else {
          // Generate summary for this day if entries exist but no summary is saved yet
          final moods = grouped[dateStr]!;
          String userDataText = "MOOD LOGS:\n";
          for (var m in moods.reversed) {
            final time = _formatTime(m['createdAt'] as DateTime);
            final label = m['label'];
            final intensity = m['intensity'];
            final notes = m['notes'] ?? 'None';
            final symptoms = (m['symptoms'] as List?)?.join(', ') ?? 'None';
            userDataText += "- At $time: Mood=$label, Intensity=$intensity/10, Notes=$notes, Symptoms=$symptoms\n";
          }

          final dailyJournals = service.journals
              .where((j) => j['date'] == dateStr || (j['date']?.contains(dateStr) ?? false))
              .toList();
          if (dailyJournals.isNotEmpty) {
            userDataText += "\nJOURNAL ENTRIES:\n";
            for (var j in dailyJournals) {
              userDataText += "- ${j['title']}: ${j['content']}\n";
            }
          }

          final summary = await _moodSummaryService.generateDailySummary(dateStr, userDataText);

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
              width: 1000, // Increased width for more spacing between days
              height: 400, // Increased height significantly
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideVertically: true,
                      fitInsideHorizontally: true,
                      tooltipMargin: 8,
                    ),
                  ),
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
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          final daysAgo = 13 - value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              _getShortDayName(daysAgo),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
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
                        interval: 2,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          Widget textWidget = Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                          
                          if (value == 10) {
                            return Transform.translate(
                              offset: const Offset(0, 6),
                              child: textWidget,
                            );
                          }
                          
                          return textWidget;
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
                            width: 6, // Thicker bars to make them more visible
                            borderRadius: BorderRadius.circular(0),
                          ),
                        );
                      }
                    }
                    return BarChartGroupData(x: i, barsSpace: 2, barRods: rods);
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

    final datesToShow = <String>[];
    if (_selectedListDate != null) {
      final s = _formatDateKey(_selectedListDate!);
      datesToShow.add(s); // Always add it to show the empty state if missing
    } else {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tStr = _formatDateKey(today);
      final yStr = _formatDateKey(yesterday);
      if (grouped.containsKey(tStr)) datesToShow.add(tStr);
      if (grouped.containsKey(yStr)) datesToShow.add(yStr);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Daily Mood Logs",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2F8AE5), // Primary blue
              ),
            ),
            InkWell(
              onTap: () async {
                DateTime initial = _selectedListDate ?? DateTime.now();
                if (!grouped.containsKey(_formatDateKey(initial))) {
                  initial = DateTime.parse(grouped.keys.first);
                }
                
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                );
                if (picked != null) {
                  setState(() {
                    _selectedListDate = picked;
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFC9A8F1), Color(0xFF8EB4F8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8EB4F8).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedListDate != null
                          ? _formatDate(_selectedListDate!)
                          : "Pick a day",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedListDate != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedListDate = null;
                          });
                        },
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (datesToShow.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "No mood entries for this day",
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
            ),
          )
        else
          ...datesToShow.map((dateStr) {
            final dayMoods = grouped[dateStr];
            
            final parsedDate = DateTime.tryParse(dateStr);
            final displayDate = parsedDate != null ? _formatDate(parsedDate) : dateStr;
            
            if (dayMoods == null || dayMoods.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    "No mood entries for this day",
                    style: TextStyle(color: AppColors.textLight, fontSize: 16),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                    child: Text(
                      displayDate,
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
                        _buildAISummaryCard(dateStr),
                        ...dayMoods.reversed.map((m) => _buildMoodTile(m)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  List<Color> _getFaceGradient(String label) {
    switch (label) {
      case 'Happy':
        return const [Color(0xFFFFD89E), Color(0xFFFFB347)];
      case 'Sad':
        return const [Color(0xFF9EC5F8), Color(0xFF5B9EF4)];
      case 'Anxious':
        return const [Color(0xFFD4A8F5), Color(0xFFAA6DD6)];
      case 'Angry':
        return const [Color(0xFFFFB0AD), Color(0xFFE86B6B)];
      case 'Neutral':
      default:
        return const [Color(0xFFC9A8F1), Color(0xFF8EB4F8)];
    }
  }

  Widget _buildMoodTile(Map<String, dynamic> mood) {
    final date = mood['createdAt'] as DateTime?;
    final timeStr = date != null ? _formatTime(date) : '';
    final label = mood['label'] as String? ?? 'Neutral';
    final intensity = mood['intensity'] as int? ?? 5;
    final gradient = _getFaceGradient(label);

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
                  colors: gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(painter: _HistoryMoodFacePainter(moodLabel: label)),
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

class _HistoryMoodFacePainter extends CustomPainter {
  const _HistoryMoodFacePainter({required this.moodLabel});

  final String moodLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Scale everything down to fit a 48x48 circle (which has radius 24)
    // Original face was drawn for a 145x145 circle. Scale factor ~ 48/145 ≈ 0.33
    const scale = 0.33;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final eyePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 4.0 / scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final mouthPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 4.2 / scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final browPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 3.0 / scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const leftEye = Offset(-22, -8);
    const rightEye = Offset(22, -8);

    switch (moodLabel) {
      case 'Happy':
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 18, height: 12),
          3.14159,
          3.14159,
          false,
          eyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 18, height: 12),
          3.14159,
          3.14159,
          false,
          eyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(0, 16),
            width: 38,
            height: 26,
          ),
          0.15 * 3.14159,
          0.7 * 3.14159,
          false,
          mouthPaint,
        );
        break;

      case 'Neutral':
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 18, height: 10),
          3.14159,
          3.14159,
          false,
          eyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 18, height: 10),
          3.14159,
          3.14159,
          false,
          eyePaint,
        );
        canvas.drawLine(
          const Offset(-13, 18),
          const Offset(13, 18),
          mouthPaint,
        );
        break;

      case 'Sad':
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
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(0, 26),
            width: 32,
            height: 22,
          ),
          3.14159,
          3.14159 - 0.1,
          false,
          mouthPaint,
        );
        break;

      case 'Anxious':
        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: 16, height: 10),
          0,
          3.14159 * 2,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.82)
            ..strokeWidth = 3.0 / scale
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: 16, height: 10),
          0,
          3.14159 * 2,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.82)
            ..strokeWidth = 3.0 / scale
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        final wavePath = Path()
          ..moveTo(-14, 18)
          ..cubicTo(
            -7,
            14,
            7,
            22,
            14,
            18,
          );
        canvas.drawPath(wavePath, mouthPaint);
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
        canvas.drawLine(
          const Offset(-11, 20),
          const Offset(11, 20),
          mouthPaint,
        );
        canvas.drawLine(
          leftEye + const Offset(-7, -15),
          leftEye + const Offset(7, -8),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3.5 / scale
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawLine(
          rightEye + const Offset(-7, -8),
          rightEye + const Offset(7, -15),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3.5 / scale
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        break;
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HistoryMoodFacePainter oldDelegate) {
    return oldDelegate.moodLabel != moodLabel;
  }
}
