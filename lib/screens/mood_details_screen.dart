import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../services/mood_summary_service.dart';
import 'gratitude_jar_screen.dart';

class MoodDetailsScreen extends StatefulWidget {
  final String moodLabel;
  const MoodDetailsScreen({super.key, required this.moodLabel});

  @override
  State<MoodDetailsScreen> createState() => _MoodDetailsScreenState();
}

class _MoodDetailsScreenState extends State<MoodDetailsScreen> {
  int intensity = 5;
  final TextEditingController _notesController = TextEditingController();
  Set<String> selectedSymptoms = {};

  static const Map<String, dynamic> moodData = {
    'Happy': {
      'title': "Great to hear you're feeling happy!",
      'word': 'happiness',
      'signsLabel': 'happiness',
      'colors': <Color>[Color(0xFFFFD89E), Color(0xFFFFB347)],
      'minLabel': 'not happy',
      'maxLabel': 'extremely happy',
      'symptoms': <String>[
        "High energy",
        "Smiling",
        "Feeling motivated",
        "Feeling grateful",
        "Wanting to socialize",
        "Increased creativity",
        "Feeling confident",
        "Generosity",
        "Excitement",
        "Sense of calm",
      ],
    },
    'Neutral': {
      'title': "Thanks for checking in.",
      'word': '',
      'signsLabel': 'neutrality',
      'colors': <Color>[Color(0xFFC9A8F1), Color(0xFF8EB4F8)],
      'minLabel': '',
      'maxLabel': '',
      'symptoms': <String>[
        "Feeling indifferent",
        "Low motivation",
        "Difficulty feeling excited",
        "Feeling detached",
        "Going through the motions",
        "Lack of energy",
        "Feeling balanced",
        "Hard to focus",
        "Neither happy nor sad",
        "Feeling steady",
      ],
    },
    'Sad': {
      'title': "Sorry to hear you're feeling sad.",
      'word': 'sadness',
      'signsLabel': 'sadness',
      'colors': <Color>[Color(0xFF9EC5F8), Color(0xFF5B9EF4)],
      'minLabel': 'no sadness',
      'maxLabel': 'extremely sad',
      'symptoms': <String>[
        "Low energy",
        "Crying",
        "Feeling empty",
        "Loss of interest",
        "Difficulty concentrating",
        "Changes in appetite",
        "Feeling hopeless",
        "Withdrawing from others",
        "Trouble sleeping",
        "Feeling worthless",
      ],
    },
    'Anxious': {
      'title': "Sorry to hear you're feeling anxious.",
      'word': 'anxiety',
      'signsLabel': 'anxiety',
      'colors': <Color>[Color(0xFFF9A8D4), Color(0xFFF472B6)],
      'minLabel': 'no anxiety',
      'maxLabel': 'extremely anxious',
      'symptoms': <String>[
        "Racing heart",
        "Rapid breathing",
        "Chest tightness",
        "Feeling very hot or cold",
        "Sweating",
        "Dry mouth",
        "Lump in throat",
        "Upset stomach",
        "Nausea",
        "Dizzy or lightheaded",
        "Trouble concentrating",
        "Muscle tension",
        "Feeling restless",
        "Trouble sleeping",
        "Racing thoughts",
        "Lots of worries",
      ],
    },
    'Angry': {
      'title': "Sorry to hear you're feeling angry.",
      'word': 'anger',
      'signsLabel': 'anger',
      'colors': <Color>[Color(0xFFFCA5A5), Color(0xFFEF4444)],
      'minLabel': 'no anger',
      'maxLabel': 'extremely angry',
      'symptoms': <String>[
        "Clenched jaw",
        "Tense muscles",
        "Racing heart",
        "Raised voice",
        "Irritability",
        "Feeling disrespected",
        "Urge to lash out",
        "Difficulty listening",
        "Sweating",
        "Headache",
      ],
    },
  };

  void _submitData() async {
    final service = Provider.of<FirebaseService>(context, listen: false);
    try {
      await service.saveMood(
        widget.moodLabel,
        intensity,
        notes: _notesController.text.trim(),
        symptoms: selectedSymptoms.toList(),
      );

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      List<String> existingMoods = prefs.getStringList('local_moods') ?? [];
      existingMoods.add(
        jsonEncode({
          'label': widget.moodLabel,
          'intensity': intensity,
          'notes': _notesController.text.trim(),
          'symptoms': selectedSymptoms.toList(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await prefs.setStringList('local_moods', existingMoods);

      // Trigger AI Summary in background for today (force update after every submit)
      Future.microtask(() async {
        try {
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          final moods = await service.getMoodsForLast14Days();
          final todayMoods = moods.where((m) {
            final date = m['createdAt'] as DateTime?;
            if (date == null) return false;
            // Compare local date strings
            return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}" ==
                todayStr;
          }).toList();

          String userDataText = "MOOD LOGS:\n";
          for (var m in todayMoods.reversed) {
            final d = m['createdAt'] as DateTime?;
            final time = d != null
                ? "${d.hour}:${d.minute.toString().padLeft(2, '0')}"
                : "";
            final label = m['label'];
            final intensity = m['intensity'];
            final notes = m['notes'] ?? 'None';
            final symptoms = (m['symptoms'] as List?)?.join(', ') ?? 'None';
            userDataText +=
                "- At $time: Mood=$label, Intensity=$intensity/10, Notes=$notes, Symptoms=$symptoms\n";
          }

          await service.loadJournals();
          final dailyJournals = service.journals
              .where(
                (j) =>
                    j['date'] == todayStr ||
                    (j['date']?.contains(todayStr) ?? false),
              )
              .toList();
          if (dailyJournals.isNotEmpty) {
            userDataText += "\nJOURNAL ENTRIES:\n";
            for (var j in dailyJournals) {
              userDataText += "- ${j['title']}: ${j['content']}\n";
            }
          }

          final moodSummaryService = MoodSummaryService();
          final summary = await moodSummaryService.generateDailySummary(
            todayStr,
            userDataText,
          );
          if (summary.isNotEmpty &&
              !summary.startsWith('Summary unavailable')) {
            await service.saveDailySummary(todayStr, summary);
          }
        } catch (_) {
          // ignore background errors
        }
      });

      if (!mounted) return;

      final currentStreak = service.moodStreak;

      // dialog for the streak
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 20,
          backgroundColor: const Color(0xFFFF8A65),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🔥", style: TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                const Text(
                  "Streak Increased!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You are on a $currentStreak day fire streak!\nKeep tracking your feelings.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx); // pop dialog

                      // Navigate to GratitudeJarScreen
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GratitudeJarScreen(),
                        ),
                      );

                      if (!mounted) return;
                      // Pop back to Dashboard with a flag to show the Quick Relief modal
                      Navigator.of(context).pop(true);
                    },
                    child: const Text(
                      "Awesome!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8A65),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openSymptomsScreen(Map<String, dynamic> moodConf) async {
    final List<String> availableSymptoms = moodConf['symptoms'] as List<String>;
    final result = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SymptomsSelectionScreen(
          moodLabel: widget.moodLabel,
          availableSymptoms: availableSymptoms,
          initialSelection: selectedSymptoms,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        selectedSymptoms = result;
      });
    }
  }

  Widget _buildNumberPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(11, (index) {
          final isSelected = intensity == index;
          return GestureDetector(
            onTap: () => setState(() => intensity = index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_drop_down,
                    color: isSelected ? Colors.white : Colors.transparent,
                    size: 36,
                  ),
                  Text(
                    '$index',
                    style: TextStyle(
                      fontSize: isSelected ? 48 : 36,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default to Neutral if mood is unrecognized
    final moodConf = moodData[widget.moodLabel] ?? moodData['Neutral'];
    final isNeutral = widget.moodLabel == 'Neutral';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Check In',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ClipPath(
              clipper: _CurveClipper(),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: moodConf['colors'] as List<Color>,
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 40,
                  bottom: 80,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  children: [
                    Text(
                      moodConf['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!isNeutral) ...[
                      const SizedBox(height: 32),
                      Text(
                        "Now let's rate your ${moodConf['word']}:",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildNumberPicker(),
                      const SizedBox(height: 16),
                      Text(
                        "0 = ${moodConf['minLabel']}, 10 = ${moodConf['maxLabel']}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      // Neutral space padding
                      const SizedBox(height: 48),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's going on?",
                    style: TextStyle(
                      color: Color(0xFF2F8AE5), // Primary blue
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Describe what's going on in your life right now and/or what's on your mind.",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 6,
                    maxLength: 400,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2F8AE5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Symptoms Section ──
                  Text(
                    "Experiencing any signs of ${moodConf['signsLabel']}?",
                    style: const TextStyle(
                      color: Color(0xFF2F8AE5), // Primary blue
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Click 'Add Symptom' to add from checklist.",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _openSymptomsScreen(moodConf),
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _DashedBorderPainter(
                        color: const Color(0xFF2F8AE5),
                        radius: 8.0,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: const Text(
                          "+ Add Symptoms",
                          style: TextStyle(
                            color: Color(0xFF2F8AE5),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selectedSymptoms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "${selectedSymptoms.length} symptom${selectedSymptoms.length > 1 ? 's' : ''} selected",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F8AE5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 4,
                        shadowColor: const Color(
                          0xFF2F8AE5,
                        ).withValues(alpha: 0.4),
                      ),
                      onPressed: _submitData,
                      child: const Text(
                        'Submit ➔',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    Path path = Path()..addRRect(rrect);
    Path dashPath = Path();

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class SymptomsSelectionScreen extends StatefulWidget {
  final String moodLabel;
  final List<String> availableSymptoms;
  final Set<String> initialSelection;

  const SymptomsSelectionScreen({
    super.key,
    required this.moodLabel,
    required this.availableSymptoms,
    required this.initialSelection,
  });

  @override
  State<SymptomsSelectionScreen> createState() =>
      _SymptomsSelectionScreenState();
}

class _SymptomsSelectionScreenState extends State<SymptomsSelectionScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Copy initial selection so we can cancel safely
    _selected = Set.from(widget.initialSelection);
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selected.contains(symptom)) {
        _selected.remove(symptom);
      } else {
        _selected.add(symptom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Symptoms',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w400,
            fontSize: 18,
          ),
        ),
        leading: TextButton(
          onPressed: () => Navigator.pop(context), // Dismiss without saving
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFF2F8AE5), fontSize: 16),
          ),
        ),
        leadingWidth: 80,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected), // Save
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF2F8AE5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF7F7F7),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Here are some common signs of ${widget.moodLabel.toLowerCase()}.",
                  style: const TextStyle(
                    color: Color(0xFF2F8AE5),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Check all those that apply.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: widget.availableSymptoms.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final symptom = widget.availableSymptoms[index];
                final isSelected = _selected.contains(symptom);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  onTap: () => _toggleSymptom(symptom),
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF2F8AE5)
                          : Colors.grey.shade200,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    symptom,
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.black87 : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
