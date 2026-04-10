import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseService extends ChangeNotifier {
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

  final List<Map<String, String>> _journals = <Map<String, String>>[];
  //
  // getters and methods
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  bool get isJournalsLoading => _isJournalsLoading;
  bool get hasLoadedJournals => _hasLoadedJournals;
  String get currentUserEmail => _currentUserEmail;
  String get currentUserName => _currentUserName;
  List<Map<String, String>> get journals =>
      List<Map<String, String>>.unmodifiable(_journals);
  int get moodStreak => _moodStreak;
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

    _isLoggedIn = true;
    _currentUserEmail = user.email ?? '';

    try {
      await _loadUserProfile(user.uid);
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
    _isJournalsLoading = false;
    _hasLoadedJournals = false;
    _journals.clear();
  }
  //
  //
  //
  // load user profile
  Future<void> _loadUserProfile(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    _currentUserName = (userData['name'] as String?)?.trim() ?? '';
    _moodStreak = (userData['moodStreak'] as num?)?.toInt() ?? 0;
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
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Email and password are required.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e)); // friendly error message
    }
  }
  //
  //
  //
  //
  Future<void> signup(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Email and password are required.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'name': '',
        'moodStreak': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
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
  // journal methods
  Future<void> saveMood(String label, int intensity) async {
    final user = _requireUser();
    final userRef = _firestore.collection('users').doc(user.uid);
    final moodRef = userRef.collection('moods').doc();

    int updatedStreak = 0;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final currentStreak =
          (snapshot.data()?['moodStreak'] as num?)?.toInt() ?? 0;
      updatedStreak = currentStreak + 1;

      transaction.set(userRef, {
        'moodStreak': updatedStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(moodRef, {
        'label': label,
        'intensity': intensity,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    _moodStreak = updatedStreak;
    notifyListeners();
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
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
