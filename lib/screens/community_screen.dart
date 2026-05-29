import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_post.dart';
import '../services/moderation_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _postController = TextEditingController();
  final ModerationService _moderationService = ModerationService();
  final ScrollController _scrollController = ScrollController();

  bool _isChecking = false;
  String? _expandedPostId;
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _isCheckingReply = {};
  int _postLimit = 20;
  bool _showMyPostsOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _postLimit += 20;
      });
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    _scrollController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Color _getColorForId(String id) {
    final hash = id.hashCode.abs();
    final r = 200 + (hash % 56);
    final g = 200 + ((hash ~/ 56) % 56);
    final b = 200 + ((hash ~/ (56 * 56)) % 56);
    return Color.fromARGB(255, r, g, b);
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 8) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if ((difference.inDays / 7).floor() >= 1) {
      return '1 week ago';
    } else if (difference.inDays >= 2) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays >= 1) {
      return '1 day ago';
    } else if (difference.inHours >= 2) {
      return '${difference.inHours} hours ago';
    } else if (difference.inHours >= 1) {
      return '1 hour ago';
    } else if (difference.inMinutes >= 2) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes >= 1) {
      return '1 minute ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _handleShare() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    if (_isChecking) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final authService = Provider.of<FirebaseService>(context, listen: false);

    setState(() {
      _isChecking = true;
    });

    try {
      final moderation = await _moderationService.moderateContent(text);

      if (!mounted) return;

      if (!moderation.safe) {
        _showUnsafeDialog(reason: moderation.reason);
        return;
      }

      await FirebaseFirestore.instance.collection('communityPosts').add({
        'userId': user.uid,
        'username': 'Anonymous',
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'reactionsCount': {"💙": 0, "🤝": 0, "✨": 0},
      });

      setState(() {
        _postController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Shared 💙"),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint("Community share error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().replaceFirst('Exception: ', '')}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleReply(String postId) async {
    final controller = _replyControllers[postId];
    if (controller == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final authService = Provider.of<FirebaseService>(context, listen: false);

    setState(() {
      _isCheckingReply[postId] = true;
    });

    try {
      final moderation = await _moderationService.moderateContent(text);

      if (!mounted) return;

      if (!moderation.safe) {
        _showUnsafeDialog(reason: moderation.reason);
        return;
      }

      await FirebaseFirestore.instance
          .collection('communityPosts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username': 'Anonymous',
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        controller.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reply sent 💙"),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().replaceFirst('Exception: ', '')}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingReply[postId] = false;
        });
      }
    }
  }

  Future<void> _toggleReaction(String postId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reactionRef = FirebaseFirestore.instance
        .collection('communityPosts')
        .doc(postId)
        .collection('reactions')
        .doc(user.uid);
    final postRef = FirebaseFirestore.instance.collection('communityPosts').doc(postId);

    final doc = await reactionRef.get();
    final currentReaction = doc.exists ? (doc.data() as Map<String, dynamic>)['reactionType'] as String? : null;

    final batch = FirebaseFirestore.instance.batch();

    if (currentReaction == emoji) {
      // Remove reaction
      batch.delete(reactionRef);
      batch.update(postRef, {'reactionsCount.$emoji': FieldValue.increment(-1)});
    } else {
      // Switch or add reaction
      if (currentReaction != null) {
        batch.update(postRef, {'reactionsCount.$currentReaction': FieldValue.increment(-1)});
      }
      batch.set(reactionRef, {
        'userId': user.uid,
        'reactionType': emoji,
        'timestamp': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'reactionsCount.$emoji': FieldValue.increment(1)});
    }

    await batch.commit();
  }

  void _showUnsafeDialog({String? reason}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Let's keep this space safe 💙",
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        content: Text(
          reason ?? "Your message may not feel supportive for someone going through a hard time. Would you like to rephrase it?",
          style: const TextStyle(color: AppColors.textLight, fontSize: 16),
        ),
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildPostInput()),
          SliverToBoxAdapter(child: _buildFilterToggle()),
          StreamBuilder<QuerySnapshot>(
            stream: _showMyPostsOnly
                ? FirebaseFirestore.instance
                    .collection('communityPosts')
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .orderBy('timestamp', descending: true)
                    .limit(_postLimit)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('communityPosts')
                    .orderBy('timestamp', descending: true)
                    .limit(_postLimit)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Error loading posts', style: TextStyle(color: AppColors.textLight))),
                );
              }
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = CommunityPost.fromFirestore(docs[index]);
                    return _buildPostCard(post);
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Safe Space",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "You are not alone here 💙",
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInput() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _postController,
              maxLength: 280,
              maxLines: null,
              minLines: 2,
              decoration: InputDecoration(
                hintText: "Share how you're feeling today...",
                hintStyle: const TextStyle(color: AppColors.textLight),
                border: InputBorder.none,
                counterStyle: const TextStyle(color: AppColors.textLight),
              ),
              style: const TextStyle(color: AppColors.textMain, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  user != null ? "Posting to Community" : "Sign in to post",
                  style: const TextStyle(color: AppColors.textLight, fontSize: 14, fontStyle: FontStyle.italic),
                ),
                ElevatedButton(
                  onPressed: _isChecking || user == null ? null : _handleShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1A1A), // Much darker text
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A1A1A),
                          ),
                        )
                      : const Text("Share", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_isChecking)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Making sure this is safe... 💙",
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            "💙",
            style: TextStyle(fontSize: 48),
          ),
          SizedBox(height: 16),
          Text(
            "Be the first to share",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Your words might be exactly\nwhat someone needs to hear today",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text("My Posts Only", style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
          Switch(
            value: _showMyPostsOnly,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _showMyPostsOnly = val;
                _postLimit = 20;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    final avatarColor = _getColorForId(post.userId);
    final isExpanded = _expandedPostId == post.id;
    _replyControllers.putIfAbsent(post.id, () => TextEditingController());
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor,
                  radius: 20,
                  child: const Icon(Icons.person, color: Colors.white70, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              fontSize: 16,
                            ),
                          ),
                          if (currentUser?.uid == post.userId)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "You",
                                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _timeAgo(post.timestamp),
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
          ),
          // Post Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Reactions & Reply
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Real-time user reaction Stream
                if (currentUser != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('communityPosts')
                        .doc(post.id)
                        .collection('reactions')
                        .doc(currentUser.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final userReaction = snapshot.hasData && snapshot.data!.exists
                          ? (snapshot.data!.data() as Map<String, dynamic>)['reactionType'] as String?
                          : null;
                      return Row(
                        children: [
                          _buildReactionButton(post, "💙", userReaction),
                          const SizedBox(width: 8),
                          _buildReactionButton(post, "🤝", userReaction),
                          const SizedBox(width: 8),
                          _buildReactionButton(post, "✨", userReaction),
                        ],
                      );
                    },
                  )
                else
                  Row(
                    children: [
                      _buildReactionButton(post, "💙", null),
                      const SizedBox(width: 8),
                      _buildReactionButton(post, "🤝", null),
                      const SizedBox(width: 8),
                      _buildReactionButton(post, "✨", null),
                    ],
                  ),

                const Spacer(),

                // Real-time comment count Stream
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('communityPosts')
                      .doc(post.id)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final repliesCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedPostId = null;
                          } else {
                            _expandedPostId = post.id;
                          }
                        });
                      },
                      icon: const Icon(Icons.reply, color: AppColors.textLight, size: 20),
                      label: Text(
                        "$repliesCount Replies",
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Reply Section
          if (isExpanded) _buildReplySection(post),
        ],
      ),
    );
  }

  Widget _buildReactionButton(CommunityPost post, String emoji, String? userReaction) {
    final count = post.reactionsCount[emoji] ?? 0;
    final isSelected = userReaction == emoji;
    
    return InkWell(
      onTap: () => _toggleReaction(post.id, emoji),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1) : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplySection(CommunityPost post) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communityPosts')
                .doc(post.id)
                .collection('comments')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const SizedBox.shrink();
              
              return Column(
                children: [
                  ...docs.map((doc) => _buildReplyItem(CommunityComment.fromFirestore(doc))),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _replyControllers[post.id],
                    decoration: const InputDecoration(
                      hintText: "Add a supportive reply...",
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isCheckingReply[post.id] == true
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : IconButton(
                      onPressed: () => _handleReply(post.id),
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      splashRadius: 24,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommunityComment reply) {
    final avatarColor = _getColorForId(reply.userId);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = currentUser?.uid == reply.userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: avatarColor,
            radius: 14,
            child: const Icon(Icons.person, color: Colors.white70, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary.withValues(alpha: 0.1) : AppColors.white,
                borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
                border: isMe ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 14),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "You",
                            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        _timeAgo(reply.timestamp),
                        style: const TextStyle(color: AppColors.textLight, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.content,
                    style: const TextStyle(color: AppColors.textMain, fontSize: 14, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
