import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a new attendance session
  Future<DocumentReference> createAttendanceSession({
    required String courseId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check if there's already an active session for this course
    final activeSessions = await _firestore
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: courseId)
        .where('isActive', isEqualTo: true)
        .get();

    if (activeSessions.docs.isNotEmpty) {
      throw Exception('There is already an active attendance session for this course');
    }

    // Create attendance session document
    return await _firestore.collection('attendance_sessions').add({
      'courseId': courseId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': true,
      'attendees': [],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUserId,
    });
  }

  // Get all attendance sessions for a course
  Stream<QuerySnapshot> getCourseAttendanceSessions(String courseId) {
    // Using a simpler query that doesn't require a composite index
    // We're only filtering by courseId without complex ordering
    return _firestore
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: courseId)
        .snapshots();
  }

  // Get a specific attendance session
  Stream<DocumentSnapshot> getAttendanceSession(String sessionId) {
    return _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .snapshots();
  }

  // End an attendance session
  Future<void> endAttendanceSession(String sessionId) async {
    await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Mark attendance for a student
  Future<void> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    String verificationMethod = 'Manual',
    Map<String, dynamic>? verificationData,
  }) async {
    // Check if the session is active
    final sessionDoc = await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .get();
    
    if (!sessionDoc.exists) {
      throw Exception('Attendance session not found');
    }
    
    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    if (!(sessionData['isActive'] as bool)) {
      throw Exception('Attendance session is not active');
    }
    
    // Check if the student is already marked
    final attendees = List<Map<String, dynamic>>.from(sessionData['attendees'] ?? []);
    final alreadyMarked = attendees.any((attendee) => attendee['studentId'] == studentId);
    
    if (alreadyMarked) {
      throw Exception('Student attendance already marked');
    }
    
    // Mark attendance
    await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .update({
      'attendees': FieldValue.arrayUnion([
        {
          'studentId': studentId,
          'studentName': studentName,
          'markedAt': Timestamp.now(),
          'verificationMethod': verificationMethod,
          'verificationData': verificationData,
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
