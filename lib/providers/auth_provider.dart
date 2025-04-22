import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  String? _userRole;
  bool _isLoading = false;
  bool _isInitialized = false;
  Map<String, dynamic>? _userData;

  User? get user => _user;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic>? get userData => _userData;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null && _user?.uid != firebaseUser.uid) {
        // User logged in or changed
        _user = firebaseUser;
        _userRole = await _authService.getUserRole();
        _userData = await _authService.getUserData();
        
        // Save authentication state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userRole', _userRole ?? '');
        
        notifyListeners();
      } else if (firebaseUser == null && _user != null) {
        // User logged out
        _user = null;
        _userRole = null;
        _userData = null;
        
        notifyListeners();
      }
    });

    // Check if user is already authenticated with Firebase
    _user = _authService.currentUser;
    
    if (_user != null) {
      // Get user role and data
      _userRole = await _authService.getUserRole();
      _userData = await _authService.getUserData();
    } else {
      // Try to perform automatic login if we have stored credentials
      final hasCredentials = await _authService.hasStoredCredentials();
      
      if (hasCredentials) {
        try {
          final userCredential = await _authService.tryAutoLogin();
          if (userCredential != null) {
            _user = userCredential.user;
            _userRole = await _authService.getUserRole();
            _userData = await _authService.getUserData();
          }
        } catch (e) {
          // Auto-login failed, clear preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('userRole');
        }
      }
    }
    
    _isLoading = false;
    _isInitialized = true;
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
      
      // Store credentials securely for automatic login
      await _authService.signIn(email: email, password: password);
      
      // Save authentication state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', _userRole ?? '');
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
      
      // Store credentials securely for automatic login
      await _authService.signIn(email: email, password: password);
      
      // Save authentication state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', _userRole ?? '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credentials = await _authService.signIn(
        email: email,
        password: password,
        rememberCredentials: rememberMe,
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
    _isLoading = true;
    notifyListeners();
    
    await _authService.signOut();
    _user = null;
    _userRole = null;
    _userData = null;
    
    // Clear authentication state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userRole');
    
    _isLoading = false;
    notifyListeners();
  }
}