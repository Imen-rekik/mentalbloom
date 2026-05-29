import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_scheduler.dart';

class FirebaseService extends ChangeNotifier {
  static const Duration _authRequestTimeout = Duration(seconds: 20);

  //
  //
  //
  // service initialization and auth Listener
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
  }
  //
  //
  //
  // private fields
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  late final StreamSubscription<User?> _authSubscription;

  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isJournalsLoading = false;
  bool _hasLoadedJournals = false;
  String _currentUserEmail = '';
  String _currentUserName = '';
  int _moodStreak = 0;
  int _longestStreak = 0;

  final List<Map<String, String>> _journals = <Map<String, String>>[];
  final List<Map<String, dynamic>> _chatMessages = <Map<String, dynamic>>[];
  //
  // getters and methods
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  bool get isJournalsLoading => _isJournalsLoading;
  bool get hasLoadedJournals => _hasLoadedJournals;
  String get currentUserEmail => _currentUserEmail;
  String get currentUserName => _currentUserName;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  List<Map<String, String>> get journals =>
      List<Map<String, String>>.unmodifiable(_journals);
  List<Map<String, dynamic>> get chatMessages =>
      List<Map<String, dynamic>>.unmodifiable(_chatMessages);
  int get moodStreak => _moodStreak;
  int get longestStreak => _longestStreak;
  bool get isUnverified =>
      _auth.currentUser != null && !_auth.currentUser!.emailVerified;
  //
  //
  //
  //
  // auth state handler
  Future<void> _handleAuthChanged(User? user) async {
    if (user == null) {
      _resetLocalState();
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      await user.reload();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }

    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      _resetLocalState();
      _isInitialized = true;
      notifyListeners();
      return;
    }

    if (!refreshedUser.emailVerified) {
      _isLoggedIn = false;
      _currentUserEmail = refreshedUser.email ?? '';
      _isInitialized = true;
      notifyListeners();
      return;
    }

    _isLoggedIn = true;
    _currentUserEmail = refreshedUser.email ?? '';

    try {
      await _loadUserProfile(refreshedUser.uid);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  //
  //
  //
  // reset on logout
  void _resetLocalState() {
    _isLoggedIn = false;
    _currentUserEmail = '';
    _currentUserName = '';
    _moodStreak = 0;
    _longestStreak = 0;
    _isJournalsLoading = false;
    _hasLoadedJournals = false;
    _journals.clear();
    _chatMessages.clear();
  }

  //
  //
  //
  // streak validity on login
  Future<void> _loadUserProfile(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    _currentUserName = (userData['name'] as String?)?.trim() ?? '';
    final rawStreak = userData['moodStreak'];
    _moodStreak = (rawStreak is num) ? rawStreak.toInt() : 0;

    final rawLongest = userData['longestStreak'];
    _longestStreak = (rawLongest is num) ? rawLongest.toInt() : 0;

    // If longestStreak was never saved, seed it from current streak
    if (_longestStreak < _moodStreak) {
      _longestStreak = _moodStreak;
      await userRef.set({'longestStreak': _longestStreak}, SetOptions(merge: true));
    }

    // if user logs in after more than 1 day, reset streak to 0
    final lastEntryTs = userData['lastEntryDate'] as Timestamp?;
    if (lastEntryTs != null) {
      final daysDiff = _daysBetween(lastEntryTs.toDate(), DateTime.now());
      if (daysDiff > 1) {
        _moodStreak = 0;
        await userRef.set({'moodStreak': 0}, SetOptions(merge: true));
      }
    }
  }

  int _daysBetween(DateTime from, DateTime to) {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    return toDate.difference(fromDate).inDays;
  }

  Future<void> loadJournals({bool forceReload = false}) async {
    if (!_isLoggedIn) {
      return;
    }

    if (_isJournalsLoading) {
      return;
    }

    if (_hasLoadedJournals && !forceReload) {
      return;
    }

    final user = _requireUser();
    _isJournalsLoading = true;
    notifyListeners();

    try {
      final journalSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journals')
          .orderBy('createdAt', descending: true)
          .get();

      _journals
        ..clear()
        ..addAll(
          journalSnapshot.docs.map((doc) {
            final data = doc.data();
            return <String, String>{
              'id': doc.id,
              'title': (data['title'] as String?) ?? '',
              'content': (data['content'] as String?) ?? '',
              'date': (data['date'] as String?) ?? '',
            };
          }),
        );
      _hasLoadedJournals = true;
    } finally {
      _isJournalsLoading = false;
      notifyListeners();
    }
  }

  //
  //
  //
  //
  // authentication methods
  Future<void> login(String email, String password) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw Exception('Please enter your email and password.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    if (!_isValidEmail(trimmedEmail)) {
      throw Exception('Please enter a valid email address.');
    }

    UserCredential credential;
    try {
      credential = await _auth
          .signInWithEmailAndPassword(email: trimmedEmail, password: password)
          .timeout(_authRequestTimeout);
    } on TimeoutException {
      throw Exception(
        'Login timed out. Please check your internet connection and try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e)); // friendly error message
    } on FirebaseException catch (e) {
      throw Exception(_mapPlatformError(e));
    }

    final user = credential.user;
    if (user == null) {
      await _auth.signOut();
      throw Exception('Something went wrong. Please try again.');
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null || !refreshedUser.emailVerified) {
      notifyListeners();
    }
  }

  //
  //
  //
  //
  Future<void> signup(String email, String password) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw Exception('Please enter your email and password.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    if (!_isValidEmail(trimmedEmail)) {
      throw Exception('Please enter a valid email address.');
    }

    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          )
          .timeout(_authRequestTimeout);

      final user = credential.user;
      if (user == null) {
        throw Exception('Something went wrong. Please try again.');
      }

      await user.sendEmailVerification();

      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': trimmedEmail,
        'name': '',
        'moodStreak': 0,
        'longestStreak': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on TimeoutException {
      throw Exception(
        'Signup timed out. Please check your internet connection and try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_mapPlatformError(e));
    } catch (_) {
      throw Exception('Something went wrong. Please try again.');
    }
  }

  Future<void> resendVerificationEmail() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Please log in to resend verification email.');
    }

    try {
      await currentUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('Please log in to resend verification email.');
      }

      if (refreshedUser.emailVerified) {
        return;
      }

      await refreshedUser.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_mapPlatformError(e));
    } catch (_) {
      throw Exception('Something went wrong. Please try again.');
    }
  }

  Future<void> refreshAuthStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      await _handleAuthChanged(_auth.currentUser);
    }
  }

  //
  //
  //
  // set user name
  Future<void> setUserName(String name) async {
    final user = _requireUser();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Name cannot be empty.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'name': trimmedName,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _currentUserName = trimmedName;
    notifyListeners();
  }

  //
  //
  //
  // mood methods
  Future<void> saveMood(String label, int intensity, {String? notes, List<String>? symptoms}) async {
    final user = _requireUser();
    final userRef = _firestore.collection('users').doc(user.uid);
    final moodRef = userRef.collection('moods').doc();

    int updatedStreak = 0;
    int newLongest = 0;
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};

      final currentStreak = (data['moodStreak'] as num?)?.toInt() ?? 0;
      final lastEntryTs = data['lastEntryDate'] as Timestamp?;

      if (lastEntryTs == null) {
        // first mood entry
        updatedStreak = 1;
      } else {
        final daysDiff = _daysBetween(lastEntryTs.toDate(), now);
        if (daysDiff == 1) {
          // exactly the next day → extend streak
          updatedStreak = currentStreak + 1;
        } else if (daysDiff > 1) {
          // Skipped at least one day → reset
          updatedStreak = 1;
        } else {
          // daysDiff == 0: streak unchanged
          updatedStreak = currentStreak;
        }
      }

      // Update longest streak if current exceeds it
      final savedLongest = (data['longestStreak'] as num?)?.toInt() ?? 0;
      newLongest = updatedStreak > savedLongest ? updatedStreak : savedLongest;

      transaction.set(userRef, {
        'moodStreak': updatedStreak,
        'longestStreak': newLongest,
        'lastEntryDate': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(moodRef, {
        'label': label,
        'intensity': intensity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (symptoms != null && symptoms.isNotEmpty) 'symptoms': symptoms,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    _longestStreak = newLongest;
    _moodStreak = updatedStreak;
    notifyListeners();

    await NotificationScheduler.instance
        .cancelMorningReminderForTodayIfBeforeNine();
  }

  Future<String?> getLatestMoodLabel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final moodSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('moods')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (moodSnapshot.docs.isEmpty) return null;
    return moodSnapshot.docs.first.data()['label'] as String?;
  }

  Future<List<Map<String, dynamic>>> getMoodsForLast14Days() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final thirteenDaysAgo = now.subtract(const Duration(days: 13));
    final startOf14DaysAgo = DateTime(
      thirteenDaysAgo.year,
      thirteenDaysAgo.month,
      thirteenDaysAgo.day,
    );

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('moods')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOf14DaysAgo),
        )
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'label': data['label'] as String?,
        'intensity': (data['intensity'] as num?)?.toInt() ?? 5,
        'notes': data['notes'] as String?,
        'symptoms': (data['symptoms'] as List?)?.map((e) => e.toString()).toList(),
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllMoods() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('moods')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'label': data['label'] as String?,
        'intensity': (data['intensity'] as num?)?.toInt() ?? 5,
        'notes': data['notes'] as String?,
        'symptoms': (data['symptoms'] as List?)?.map((e) => e.toString()).toList(),
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMoodsForLast7Days() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final sixDaysAgo = now.subtract(const Duration(days: 6));
    final startOf7DaysAgo = DateTime(
      sixDaysAgo.year,
      sixDaysAgo.month,
      sixDaysAgo.day,
    );

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('moods')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOf7DaysAgo),
        )
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'label': data['label'] as String? ?? 'Neutral',
        'intensity': (data['intensity'] as num?)?.toInt() ?? 5, // Default to mid-intensity if null
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      };
    }).toList();
  }

  //
  //
  //
  // add, update, delete journals
  Future<void> addJournal(String title, String content, String date) async {
    final user = _requireUser();
    final journalRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journals')
        .doc();

    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await journalRef.set(payload);
    _journals.insert(0, <String, String>{
      'id': journalRef.id,
      'title': title,
      'content': content,
      'date': date,
    });
    notifyListeners();
  }

  //
  //
  //
  // update journal
  Future<void> updateJournal(String id, String title, String content) async {
    final user = _requireUser();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journals')
        .doc(id)
        .set({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final index = _journals.indexWhere((j) => j['id'] == id);
    if (index != -1) {
      _journals[index]['title'] = title;
      _journals[index]['content'] = content;
      notifyListeners();
    }
  }

  //
  //
  //
  // delete journal
  Future<void> deleteJournal(String id) async {
    final user = _requireUser();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journals')
        .doc(id)
        .delete();

    _journals.removeWhere((j) => j['id'] == id);
    notifyListeners();
  }

  //
  //
  //
  // logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  //
  //
  //
  // ensure user is logged in before actions
  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to perform this action.');
    }
    return user;
  }

  //
  //
  //
  // friendly error messages
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been suspended. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger one.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      default:
        return 'An unexpected authentication error occurred (${e.code}).';
    }
  }

  String _mapPlatformError(FirebaseException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Something went wrong on our end. Please try again shortly.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
    );
    return emailRegExp.hasMatch(email);
  }

  //
  // AI Summary methods
  Future<String?> getDailySummary(String dateStr) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('ai_summaries')
        .doc(dateStr)
        .get();

    if (doc.exists) {
      return doc.data()?['summary'] as String?;
    }
    return null;
  }

  Future<void> saveDailySummary(String dateStr, String summary) async {
    final user = _requireUser();
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('ai_summaries')
        .doc(dateStr)
        .set({
      'summary': summary,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  //
  //
  // Chat History methods
  void initChatIfNeeded() {
    if (_chatMessages.isEmpty) {
      _chatMessages.add({
        'sender': 'bot',
        'text': 'Hello! I am here to listen. How are you feeling today?',
      });
      notifyListeners();
      _saveInitialBotMessage();
    }
  }

  Future<void> _saveInitialBotMessage() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final date = DateTime.now().toIso8601String().split('T').first;
    final messagesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chatSessions')
        .doc(date)
        .collection('messages');
    final docRef = messagesRef.doc();
    await docRef.set({
      'messageId': docRef.id,
      'role': 'assistant',
      'content': 'Hello! I am here to listen. How are you feeling today?',
      'timestamp': FieldValue.serverTimestamp(),
      'date': date,
    });
  }

  Future<void> saveChatMessage(String role, String content) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // update local state
    _chatMessages.add({
      'sender': role == 'user' ? 'user' : 'bot',
      'text': content,
    });
    notifyListeners();

    // save to firestore
    final date = DateTime.now().toIso8601String().split('T').first;
    final messagesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chatSessions')
        .doc(date)
        .collection('messages');
        
    final docRef = messagesRef.doc();
    await docRef.set({
      'messageId': docRef.id,
      'role': role,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'date': date,
    });
  }

  Future<List<Map<String, dynamic>>> getTodayChatHistory(String userId, String date) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chatSessions')
        .doc(date)
        .collection('messages')
        .orderBy('timestamp')
        .get();
        
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  //
  // Community Helpers
  Future<List<Map<String, dynamic>>> getMyComments(String userId) async {
    final snapshot = await _firestore
        .collectionGroup('comments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['commentId'] = doc.id;
      // To get the postId, we can look at the reference path
      // Path: communityPosts/{postId}/comments/{commentId}
      final parentPostRef = doc.reference.parent.parent;
      data['postId'] = parentPostRef?.id;
      return data;
    }).toList();
  }
}
