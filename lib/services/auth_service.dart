import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
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
}