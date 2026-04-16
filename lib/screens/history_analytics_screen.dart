import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class HistoryAnalyticsScreen extends StatefulWidget {
  const HistoryAnalyticsScreen({super.key});

  @override
  State<HistoryAnalyticsScreen> createState() => _HistoryAnalyticsScreenState();
}

class _HistoryAnalyticsScreenState extends State<HistoryAnalyticsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _moods = [];

  String _timeFilter = 'This Week';
  int _touchedPieIndex = -1;

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
    final moods = await service.getMoodsForLast7Days();
    if (mounted) {
      setState(() {
        _moods = moods;
        _isLoading = false;
      });
    }
  }

  List<Map<String, double?>> _getDailyAverages() {
    final now = DateTime.now();
    final days = <Map<String, double?>>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayMoods = _moods.where((m) {
        final mDate = m['createdAt'] as DateTime?;
        if (mDate == null) return false;
        return mDate.year == date.year && mDate.month == date.month && mDate.day == date.day;
      }).toList();

      final Map<String, double?> dailyAvgs = {};
      
      for (final emotion in _emotionColors.keys) {
        final emotionMoods = dayMoods.where((m) => m['label'] == emotion).toList();
        if (emotionMoods.isEmpty) {
          dailyAvgs[emotion] = null;
        } else {
          final sum = emotionMoods.fold(0, (prev, m) => prev + ((m['intensity'] as int?) ?? 0));
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
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  List<Map<String, dynamic>> get _filteredMoods {
    if (_timeFilter == 'Today') {
      final now = DateTime.now();
      return _moods.where((m) {
        final date = m['createdAt'] as DateTime?;
        if (date == null) return false;
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
    }
    return _moods; // 'This Week'
  }

  Map<String, int> _getEmotionCounts() {
    final counts = <String, int>{
      for (var e in _emotionColors.keys) e: 0
    };
    for (final m in _filteredMoods) {
      final label = m['label'] as String?;
      if (label != null && counts.containsKey(label)) {
        counts[label] = counts[label]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final streak = Provider.of<FirebaseService>(context).moodStreak;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Statistics',
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
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildMultiLineChart(),
                const SizedBox(height: 24),
                _buildDonutChart(),
                const SizedBox(height: 24),
                // streak
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2), // Soft background tint
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text("🔥", style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "You've logged your mood $streak days in a row!",
                              style: const TextStyle(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildMultiLineChart() {
    final dailyAverages = _getDailyAverages();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
            "Your emotional intensity over the past 7 days",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          // Toggle Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _emotionColors.keys.map((emotion) {
                final isActive = _activeEmotions[emotion]!;
                final color = _emotionColors[emotion]!;
                final emoji = _emotionEmojis[emotion]!;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeEmotions[emotion] = !isActive;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
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
                            emotion,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive ? color : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          // Line Chart
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 10,
                minX: 0,
                maxX: 6,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final daysAgo = 6 - value.toInt();
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
                      interval: 2,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: _emotionColors.keys.map((emotion) {
                  if (!_activeEmotions[emotion]!) {
                    return LineChartBarData(show: false);
                  }
                  
                  final spots = <FlSpot>[];
                  for (int i = 0; i < 7; i++) {
                    final avg = dailyAverages[i][emotion];
                    if (avg != null && avg > 0) {
                      spots.add(FlSpot(i.toDouble(), avg));
                    } else {
                      spots.add(FlSpot.nullSpot);
                    }
                  }
                  
                  return LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _emotionColors[emotion]!,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: _emotionColors[emotion]!,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, int>> _getEmotionData() {
    final data = <String, Map<String, int>>{
      for (var e in _emotionColors.keys) e: {'entryCount': 0, 'intensitySum': 0}
    };
    for (final m in _filteredMoods) {
      final label = m['label'] as String?;
      final intensity = (m['intensity'] as num?)?.toInt() ?? 0;
      if (label != null && data.containsKey(label)) {
        data[label]!['entryCount'] = data[label]!['entryCount']! + 1;
        data[label]!['intensitySum'] = data[label]!['intensitySum']! + intensity;
      }
    }
    return data;
  }

  Widget _buildDonutChart() {
    final emotionData = _getEmotionData();
    final totalEntries = emotionData.values.fold(0, (a, b) => a + b['entryCount']!);
    final totalIntensity = emotionData.values.fold(0, (a, b) => a + b['intensitySum']!);

    // Find dominant by intensity sum
    String dominantEmotion = 'Happy'; // default
    int maxIntensity = -1;
    emotionData.forEach((emotion, data) {
      final intensity = data['intensitySum']!;
      if (intensity > maxIntensity && intensity > 0) {
        maxIntensity = intensity;
        dominantEmotion = emotion;
      }
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            // Title and Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Emotion Distribution",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: ['Today', 'This Week'].map((filter) {
                      final isSelected = _timeFilter == filter;
                      return GestureDetector(
                        onTap: () {
                           setState(() {
                              _timeFilter = filter;
                              _touchedPieIndex = -1;
                           });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.textMain : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                               color: isSelected ? Colors.white : AppColors.textLight,
                               fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                               fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                )
              ]
            ),
            const SizedBox(height: 32),
            
            if (totalEntries == 0)
              _buildEmptyState()
            else
              Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    _touchedPieIndex = -1;
                                    return;
                                  }
                                  _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            sectionsSpace: 4,
                            centerSpaceRadius: 60,
                            sections: _getPieSections(emotionData, totalIntensity),
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 300),
                        ),
                        // Center text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _emotionEmojis[dominantEmotion] ?? '',
                              style: const TextStyle(fontSize: 40),
                            ),
                            const Text(
                              "Dominant",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLegend(emotionData, totalIntensity),
                ]
              )
         ]
      )
    );
  }

  List<PieChartSectionData> _getPieSections(
    Map<String, Map<String, int>> emotionData,
    int totalIntensity,
  ) {
    int index = 0;
    return _emotionColors.entries.map((entry) {
      final isTouched = index == _touchedPieIndex;
      final radius = isTouched ? 45.0 : 35.0;
      final intensitySum = emotionData[entry.key]!['intensitySum']!;
      final value = intensitySum.toDouble();
      
      final section = PieChartSectionData(
        color: entry.value,
        value: value,
        radius: radius,
        showTitle: false,
      );
      index++;
      return section;
    }).toList();
  }

  Widget _buildEmptyState() {
     return Center(
       child: Padding(
         padding: const EdgeInsets.symmetric(vertical: 40),
         child: Column(
           children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 16),
              const Text(
                "No entries yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "When you log your mood,\nit will appear here.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
           ]
         )
       )
     );
  }

  Widget _buildLegend(
    Map<String, Map<String, int>> emotionData, 
    int totalIntensity,
  ) {
    int index = 0;
    final items = <Widget>[];

    for (final entry in _emotionColors.entries) {
      final emotion = entry.key;
      final data = emotionData[emotion]!;
      final intensitySum = data['intensitySum']!;
      final entryCount = data['entryCount']!;
      
      final currentIndex = index; // capture for the closure loop
      index++; // increment before continue so indexing stays aligned with pie chart!

      if (entryCount == 0) {
        continue;
      }

      final isTouched = currentIndex == _touchedPieIndex;
      final percentage = (intensitySum / totalIntensity * 100).toStringAsFixed(0);

      items.add(
           Container(
             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
             decoration: BoxDecoration(
               color: isTouched ? entry.value.withValues(alpha: 0.1) : Colors.transparent,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    emotion,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMain,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$percentage%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: entry.value,
                      fontSize: 16,
                    ),
                  ),
              const SizedBox(width: 8),
              Text(
                "($entryCount entries)",
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
        
        items.add(Divider(color: Colors.grey.withValues(alpha: 0.1), height: 1));
     }
     
     if (items.isNotEmpty && items.last is Divider) {
       items.removeLast();
     }
     
     return Column(children: items);
  }
}
