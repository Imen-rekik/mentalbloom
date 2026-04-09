import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service_mock.dart';
import '../theme/app_colors.dart';
import 'journal_editor_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String searchQuery = "";

  void _deleteJournal(String id) {
    //
    // add delete

    Provider.of<FirebaseServiceMock>(context, listen: false).deleteJournal(id);
  }

  @override
  Widget build(BuildContext context) {
    //
    // getting journals
    final journals = Provider.of<FirebaseServiceMock>(context).journals;

    //
    // filter journals based on search
    final filteredJournals = journals.where((j) {
      final title = j['title']?.toLowerCase() ?? "";
      final content = j['content']?.toLowerCase() ?? "";
      final search = searchQuery.toLowerCase();
      return title.contains(search) || content.contains(search);
    }).toList();

    //
    // UI
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Journal',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textMain),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            //
            //
            // search bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search entries...',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  prefixIcon: Icon(Icons.search, color: AppColors.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            //
            //
            // Journal List
            Expanded(
              child: filteredJournals.isEmpty
                  ? const Center(
                      child: Text(
                        "No entries found. Tap + to write one!",
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredJournals.length,
                      itemBuilder: (context, index) {
                        final j = filteredJournals[index];
                        final displayTitle = j['title']!.isNotEmpty
                            ? j['title']!
                            : "Diary Entry";

                        // Calculate word count
                        int wordCount = j['content']!
                            .split(RegExp(r'\s+'))
                            .where((s) => s.isNotEmpty)
                            .length;

                        // Mock a mood tag based on content length for demonstration
                        String moodLabel = "neutral";
                        Color moodColor = AppColors.background;
                        String moodEmoji = "😐";
                        if (wordCount > 30) {
                          moodLabel = "positive";
                          moodEmoji = "😊";
                          moodColor = AppColors.secondary;
                        }
                        if (wordCount < 10) {
                          moodLabel = "negative";
                          moodEmoji = "😟";
                          moodColor = const Color(0xFFFFEBEE);
                        }

                        //
                        // edit existing journal
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JournalEditorScreen(
                                  existingId: j['id'],
                                  initialTitle: j['title'],
                                  initialContent: j['content'],
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            //
                            // delete dialog
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Entry?'),
                                content: const Text(
                                  'Are you sure you want to delete this journal entry?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _deleteJournal(j['id']!);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          //
                          //
                          // journal box outside
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            //
                            //
                            //
                            //journal box inside
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      j['date']!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  j['content']!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textLight,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis, //....
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      "$wordCount words",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: moodColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            moodEmoji,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            moodLabel,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMain,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      //
      //
      //
      // + add journal button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JournalEditorScreen()),
          );
        },
      ),
    );
  }
}
