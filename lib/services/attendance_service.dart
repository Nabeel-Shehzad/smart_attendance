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
    final activeSessions =
        await _firestore
            .collection('attendance_sessions')
            .where('courseId', isEqualTo: courseId)
            .where('isActive', isEqualTo: true)
            .get();

    if (activeSessions.docs.isNotEmpty) {
      throw Exception(
        'There is already an active attendance session for this course',
      );
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
      'wifiEnabled':
          true, // New field to indicate WiFi-based attendance is enabled
      'wifiSignalActive':
          false, // Flag to track if WiFi signal is currently active
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
    await _firestore.collection('attendance_sessions').doc(sessionId).update({
      'isActive': false,
      'wifiSignalActive': false, // Ensure WiFi signal is also deactivated
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Send attendance signal to students (with WiFi support)
  Future<void> sendAttendanceSignal(String sessionId) async {
    // Record the signal time
    final now = DateTime.now();
    await _firestore.collection('attendance_sessions').doc(sessionId).update({
      'signalTime': Timestamp.fromDate(now),
      'wifiSignalActive': true, // Mark that WiFi signal is now active
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Get course ID for this session to send notifications
    final sessionDoc =
        await _firestore.collection('attendance_sessions').doc(sessionId).get();

    if (sessionDoc.exists) {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final courseId = sessionData['courseId'] as String;
      final title = 'Attendance Required';
      final message =
          'Your instructor has requested attendance for ${sessionData['title']}';

      // Create a notification in Firestore for fallback purposes
      await _firestore.collection('notifications').add({
        'type': 'attendance_signal',
        'courseId': courseId,
        'sessionId': sessionId,
        'title': title,
        'message': message,
        'sentAt': Timestamp.fromDate(now),
        'read': false,
        'targetRole': 'student',
        'isWifiBased': true, // Mark this as WiFi-based attendance
      });

      // Note: We won't send push notifications directly as we're using BLE now
      // But we keep this record for UI updates and fallback purposes
    }
  }

  // Stop attendance signal (new method for WiFi)
  Future<void> stopAttendanceSignal(String sessionId) async {
    await _firestore.collection('attendance_sessions').doc(sessionId).update({
      'wifiSignalActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update attendance statuses when signal is stopped
    await updateAttendanceStatuses(sessionId);
  }

  // Update attendance statuses based on time thresholds and include all enrolled students
  Future<bool> updateAttendanceStatuses(String sessionId) async {
    try {
      // Get the session document
      final sessionDoc =
          await _firestore
              .collection('attendance_sessions')
              .doc(sessionId)
              .get();

      if (!sessionDoc.exists) {
        return false;
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final signalTime =
          sessionData['signalTime'] != null
              ? (sessionData['signalTime'] as Timestamp).toDate()
              : null;

      // If no signal time is set, we can't update statuses
      if (signalTime == null) {
        return false;
      }

      // Session data is used for signal time and thresholds

      // Get the late and absent thresholds
      final lateThresholdMinutes = sessionData['lateThresholdMinutes'] ?? 15;
      final absentThresholdMinutes =
          sessionData['absentThresholdMinutes'] ?? 30;

      // Get the current attendees
      final attendees = List<Map<String, dynamic>>.from(
        sessionData['attendees'] ?? [],
      );

      // Update status for students who have marked attendance
      final updatedAttendees =
          attendees.map((attendee) {
            // Get the marked time for this attendee
            final markedAt = (attendee['markedAt'] as Timestamp).toDate();
            final responseTime = markedAt.difference(signalTime);

            // Determine the correct status based on response time
            String status = 'present';
            if (responseTime.inMinutes > absentThresholdMinutes) {
              status = 'absent';
            } else if (responseTime.inMinutes > lateThresholdMinutes) {
              status = 'late';
            }

            // Update the status if it's different
            if (attendee['status'] != status) {
              attendee['status'] = status;
              attendee['statusUpdatedAt'] = Timestamp.now();
            }

            return attendee;
          }).toList();

      // Only update the existing attendees, don't auto-mark absent students
      await _firestore
          .collection('attendance_sessions')
          .doc(sessionId)
          .update({
        'attendees': updatedAttendees,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating attendance statuses: $e');
      return false;
    }
  }

  // Check if a WiFi signal is active for a session
  Future<bool> isSessionSignalActive(String sessionId) async {
    final doc =
        await _firestore.collection('attendance_sessions').doc(sessionId).get();

    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    return data['wifiSignalActive'] == true;
  }

  // Mark attendance for a student (updated to accept WiFi verification)
  Future<void> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    String verificationMethod = 'Manual',
    Map<String, dynamic>? verificationData,
    bool wifiVerified = false, // New param to indicate WiFi verification
  }) async {
    // Ensure we have a valid student name by fetching from Firestore if needed
    String validStudentName = studentName;
    if (validStudentName.isEmpty || validStudentName == 'Unknown Student') {
      try {
        // Attempt to fetch student name from users collection
        final userDoc =
            await _firestore.collection('users').doc(studentId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          if (userData.containsKey('fullName') &&
              userData['fullName'] != null) {
            validStudentName = userData['fullName'];
          }
        }
      } catch (e) {
        print('Error fetching student name: $e');
        // Continue with the provided name if there's an error
      }
    }

    // Check if the session is active
    final sessionDoc =
        await _firestore.collection('attendance_sessions').doc(sessionId).get();

    if (!sessionDoc.exists) {
      throw Exception('Attendance session not found');
    }

    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    if (!(sessionData['isActive'] as bool)) {
      throw Exception('Attendance session is not active');
    }

    // Check if WiFi verification is required but not provided
    final wifiEnabled = sessionData['wifiEnabled'] ?? false;
    if (wifiEnabled && !wifiVerified && verificationMethod != 'Manual') {
      throw Exception('WiFi verification required for attendance');
    }

    // Check if the student is already marked
    final attendees = List<Map<String, dynamic>>.from(
      sessionData['attendees'] ?? [],
    );
    final alreadyMarked = attendees.any(
      (attendee) => attendee['studentId'] == studentId,
    );

    if (alreadyMarked) {
      throw Exception('Student attendance already marked');
    }

    // Get the late and absent thresholds from the session
    final lateThresholdMinutes = sessionData['lateThresholdMinutes'] ?? 15;
    final absentThresholdMinutes = sessionData['absentThresholdMinutes'] ?? 30;

    // Determine attendance status based on signal time
    String status = 'present';
    final signalTime =
        sessionData['signalTime'] != null
            ? (sessionData['signalTime'] as Timestamp).toDate()
            : null;

    if (signalTime != null) {
      final now = DateTime.now();
      final difference = now.difference(signalTime);

      // Use the dynamic thresholds from the session
      if (difference.inMinutes > absentThresholdMinutes) {
        status = 'absent';
      } else if (difference.inMinutes > lateThresholdMinutes) {
        status = 'late';
      }
    }

    // Mark attendance
    await _firestore.collection('attendance_sessions').doc(sessionId).update({
      'attendees': FieldValue.arrayUnion([
        {
          'studentId': studentId,
          'studentName': validStudentName, // Use the validated student name
          'markedAt': Timestamp.now(),
          'verificationMethod': verificationMethod,
          'verificationData': verificationData,
          'wifiVerified': wifiVerified, // Include WiFi verification status
          'status': status, // Add attendance status
          'responseTime': Timestamp.now(),
        },
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
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }
}
