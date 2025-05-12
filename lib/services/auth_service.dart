import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Secure storage keys
  static const String _emailKey = 'auth_email';
  static const String _passwordKey = 'auth_password';

  // Register student
  Future<UserCredential> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional student data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'studentId': studentId,
        'email': email,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Register instructor
  Future<UserCredential> registerInstructor({
    required String email,
    required String password,
    required String fullName,
    required String facultyId,
    required String department,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional instructor data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'facultyId': facultyId,
        'department': department,
        'email': email,
        'role': 'instructor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberCredentials = true,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Store credentials securely if remember is enabled
      if (rememberCredentials) {
        await _storeCredentialsSecurely(email, password);
      }
      
      return credential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Store credentials securely
  Future<void> _storeCredentialsSecurely(String email, String password) async {
    await _secureStorage.write(key: _emailKey, value: email);
    await _secureStorage.write(key: _passwordKey, value: password);
  }
  
  // Check if credentials are stored
  Future<bool> hasStoredCredentials() async {
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);
    return email != null && password != null;
  }
  
  // Try to sign in with stored credentials
  Future<UserCredential?> tryAutoLogin() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      
      if (email != null && password != null) {
        return await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      return null;
    } catch (e) {
      // If auto-login fails, clear stored credentials
      await clearStoredCredentials();
      return null;
    }
  }
  
  // Clear stored credentials
  Future<void> clearStoredCredentials() async {
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
  }

  // Sign out
  Future<void> signOut() async {
    await clearStoredCredentials();
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role
  Future<String?> getUserRole() async {
    if (currentUser != null) {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      return doc.data()?['role'] as String?;
    }
    return null;
  }
  
  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser != null) {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      return doc.data();
    }
    return null;
  }
  
  // Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
  
  // Stream to monitor authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}