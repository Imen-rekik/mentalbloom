import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime timestamp;

  CommunityComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
  });

  factory CommunityComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityComment(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CommunityPost {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime timestamp;
  Map<String, int> reactionsCount;
  String? userReaction; // local field, updated separately

  CommunityPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    Map<String, int>? reactionsCount,
    this.userReaction,
  }) : reactionsCount = reactionsCount ?? {"💙": 0, "🤝": 0, "✨": 0};

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactionsCount: Map<String, int>.from(
          data['reactionsCount'] ?? {"💙": 0, "🤝": 0, "✨": 0}),
    );
  }
}
