import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  String? _userRole;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  User? get user => _user;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check if user is already authenticated
    _user = _authService.currentUser;
    
    if (_user != null) {
      // Get user role and data from Firestore
      _userRole = await _authService.getUserRole();
      _userData = await _authService.getUserData();
      
      // Save authentication state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', _userRole ?? '');
    } else {
      // Check if we have saved login info
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isLoggedIn) {
        // User was previously logged in but Firebase token expired
        // We'll need to wait for Firebase to restore the session
        _userRole = prefs.getString('userRole');
      }
    }
    
    notifyListeners();
  }

  Future<void> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credentials = await _authService.registerStudent(
        email: email,
        password: password,
        fullName: fullName,
        studentId: studentId,
      );
      
      _user = credentials.user;
      _userRole = 'student';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerInstructor({
    required String email,
    required String password,
    required String fullName,
    required String facultyId,
    required String department,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credentials = await _authService.registerInstructor(
        email: email,
        password: password,
        fullName: fullName,
        facultyId: facultyId,
        department: department,
      );
      
      _user = credentials.user;
      _userRole = 'instructor';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credentials = await _authService.signIn(
        email: email,
        password: password,
      );
      
      _user = credentials.user;
      _userRole = await _authService.getUserRole();
      _userData = await _authService.getUserData();
      
      // Save authentication state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', _userRole ?? '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _userRole = null;
    
    // Clear authentication state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userRole');
    
    notifyListeners();
  }
}