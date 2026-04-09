import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';

class JournalEditorScreen extends StatefulWidget {
  final String? existingId;
  final String? initialTitle;
  final String? initialContent;

  const JournalEditorScreen({super.key, this.existingId, this.initialTitle, this.initialContent});

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) titleController.text = widget.initialTitle!;
    if (widget.initialContent != null) contentController.text = widget.initialContent!;
  }

  void _saveEntry() {
    if (contentController.text.trim().isEmpty) return;

    if (widget.existingId != null) {
      Provider.of<FirebaseServiceMock>(context, listen: false)
          .updateJournal(widget.existingId!, titleController.text.trim(), contentController.text.trim());
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry updated!'), backgroundColor: AppColors.primary),
      );
      Navigator.pop(context); // Go back
    } else {
      final date = DateTime.now();
      final dateStr = "Apr ${date.day}"; // simplified date like in the photo

      Provider.of<FirebaseServiceMock>(context, listen: false)
          .addJournal(titleController.text.trim(), contentController.text.trim(), dateStr);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry saved successfully!'), backgroundColor: AppColors.primary),
      );
      Navigator.pop(context); // Go back to the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Write Journal', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
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
                hintText: 'Title (Optional)',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const Divider(color: AppColors.white, thickness: 2),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'How was your day?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 16, color: AppColors.textLight),
                ),
                style: const TextStyle(fontSize: 16, color: AppColors.textMain, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
