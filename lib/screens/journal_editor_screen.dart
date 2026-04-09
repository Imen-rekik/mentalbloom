import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';

class JournalEditorScreen extends StatefulWidget {
  final String? existingId;
  final String? initialTitle;
  final String? initialContent;

  const JournalEditorScreen({
    super.key,
    this.existingId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  //
  //
  // Jan 5 instead of "2024-01-05"
  static const List<String> _monthAbbreviations = <String>[
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

  String _formatDate(DateTime date) {
    final month = _monthAbbreviations[date.month - 1];
    return '$month ${date.day}';
  }

  //
  //
  //
  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null)
      titleController.text = widget.initialTitle!;
    if (widget.initialContent != null)
      contentController.text = widget.initialContent!;
  }

  void _saveEntry() {
    if (contentController.text.trim().isEmpty) return;

    //
    // the journal exists
    if (widget.existingId != null) {
      Provider.of<FirebaseServiceMock>(context, listen: false).updateJournal(
        widget.existingId!,
        titleController.text.trim(),
        contentController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Journal entry updated!',
            style: TextStyle(color: AppColors.textLight),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
      //
      // new journal
    } else {
      final date = DateTime.now();
      final dateStr = _formatDate(date);

      Provider.of<FirebaseServiceMock>(context, listen: false).addJournal(
        titleController.text.trim(),
        contentController.text.trim(),
        dateStr,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Journal entry saved successfully!',
            style: TextStyle(color: AppColors.textLight),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Write Journal',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.textLight),
            onPressed: _saveEntry,
            tooltip: 'Save Entry',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const Divider(color: AppColors.primary, thickness: 2),
            //
            //
            // content
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'How was your day?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textMain,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
