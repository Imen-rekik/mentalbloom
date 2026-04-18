import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import 'journal_editor_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String searchQuery = "";

  Future<void> _deleteJournal(String id) async {
    //
    // add delete

    try {
      await Provider.of<FirebaseService>(
        context,
        listen: false,
      ).deleteJournal(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    //
    // getting journals
    final firebaseService = Provider.of<FirebaseService>(context);
    final journals = firebaseService.journals;

    //
    // filter journals based on search
    final filteredJournals = journals.where((j) {
      final title = j['title']?.toLowerCase() ?? "";
      final date = j['date']?.toLowerCase() ?? "";
      final search = searchQuery.toLowerCase();
      return title.contains(search) || date.contains(search);
    }).toList();

    //
    // UI
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: const Text(
          'My Journal',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
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
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search by title or date...',
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
              child:
                  firebaseService.isJournalsLoading &&
                      !firebaseService.hasLoadedJournals
                  ? const Center(child: CircularProgressIndicator())
                  : filteredJournals.isEmpty
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
                                    onPressed: () async {
                                      await _deleteJournal(j['id']!);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
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
                                  color: Colors.black.withValues(alpha: 0.15),
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
