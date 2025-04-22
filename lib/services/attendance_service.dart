import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a new attendance session
  Future<DocumentReference> createAttendanceSession({
    required String courseId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    int lateThresholdMinutes = 15, // Default to 15 minutes
    int absentThresholdMinutes = 30, // Default to 30 minutes
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
      'signalTime': null, // Initialize signal time as null
      'lateThresholdMinutes': lateThresholdMinutes,
      'absentThresholdMinutes': absentThresholdMinutes,
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

  // Send attendance signal to students
  Future<void> sendAttendanceSignal(String sessionId) async {
    // Record the signal time
    final now = DateTime.now();
    await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .update({
      'signalTime': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Get course ID for this session to send notifications
    final sessionDoc = await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .get();
        
    if (sessionDoc.exists) {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final courseId = sessionData['courseId'] as String;
      final title = 'Attendance Required';
      final message = 'Your instructor has requested attendance for ${sessionData['title']}';
      
      // Create a notification in Firestore
      await _firestore.collection('notifications').add({
        'type': 'attendance_signal',
        'courseId': courseId,
        'sessionId': sessionId,
        'title': title,
        'message': message,
        'sentAt': Timestamp.fromDate(now),
        'read': false,
        'targetRole': 'student'
      });
      
      // Send actual push notifications to student devices
      await _notificationService.sendAttendanceNotificationToCourse(
        courseId,
        sessionId,
        title,
        message
      );
    }
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
    
    // Get the late and absent thresholds from the session
    final lateThresholdMinutes = sessionData['lateThresholdMinutes'] ?? 15;
    final absentThresholdMinutes = sessionData['absentThresholdMinutes'] ?? 30;
    
    // Determine attendance status based on signal time
    String status = 'present';
    final signalTime = sessionData['signalTime'] != null 
        ? (sessionData['signalTime'] as Timestamp).toDate() 
        : null;
    
    if (signalTime != null) {
      final now = DateTime.now();
      final difference = now.difference(signalTime);
      
      // Use the dynamic thresholds from the session
      if (difference.inMinutes > absentThresholdMinutes) {
        status = 'absent';
      } 
      else if (difference.inMinutes > lateThresholdMinutes) {
        status = 'late';
      }
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
          'status': status, // Add attendance status
          'responseTime': Timestamp.now(),
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get all notifications for the current user based on their role
  Stream<QuerySnapshot> getNotifications() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    // First determine user's role
    return _firestore
        .collection('notifications')
        .where('targetRole', isEqualTo: 'student')
        .orderBy('sentAt', descending: true)
        .snapshots();
  }
  
  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
    });
  }
}
