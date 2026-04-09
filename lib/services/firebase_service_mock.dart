import 'package:flutter/material.dart';

// service class
class FirebaseServiceMock extends ChangeNotifier {
  //fake database
  static final Map<String, String> _mockDatabaseNames = {};

  bool _isLoggedIn = false;
  String _currentUserEmail = "";
  String _currentUserName = "";

  // global Mock Journals List
  final List<Map<String, String>> _journals = [];

  // mood_streak
  int _moodStreak = 0;

  // getters
  bool get isLoggedIn => _isLoggedIn;
  String get currentUserEmail => _currentUserEmail;
  String get currentUserName => _currentUserName;
  List<Map<String, String>> get journals => _journals;
  int get moodStreak => _moodStreak;

  // save Mood
  void saveMood(String label, int intensity) {
    _moodStreak++;
    notifyListeners(); //update UI
  }

  // CRUD
  // save a journal
  void addJournal(String title, String content, String date) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _journals.insert(0, {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
    });
    notifyListeners();
  }

  // edit a journal
  void updateJournal(String id, String title, String content) {
    final index = _journals.indexWhere((j) => j['id'] == id);
    if (index != -1) {
      _journals[index]['title'] = title;
      _journals[index]['content'] = content;
      notifyListeners();
    }
  }

  // delete a journal
  void deleteJournal(String id) {
    _journals.removeWhere((j) => j['id'] == id);
    notifyListeners();
  }

  // set name after login
  Future<void> setUserName(String name) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUserName = name;
    _mockDatabaseNames[_currentUserEmail] = name;
    notifyListeners();
  }

  // fake login function
  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email.isNotEmpty && password.isNotEmpty) {
      _isLoggedIn = true;
      _currentUserEmail = email;
      // Load name from DB if they exist, else empty
      _currentUserName = _mockDatabaseNames[email] ?? "";
      notifyListeners();
    }
  }

  // Fake signup function
  Future<void> signup(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email.isNotEmpty && password.isNotEmpty) {
      _isLoggedIn = true; // For now, signup automatically logs them in
      _currentUserEmail = email;
      _currentUserName = "";
      notifyListeners();
    }
  }

  // Fake logout function
  void logout() {
    _isLoggedIn = false;
    _currentUserEmail = "";
    _currentUserName = ""; // Clear name on logout
    notifyListeners();
  }
}
