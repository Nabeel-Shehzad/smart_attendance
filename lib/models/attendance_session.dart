import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String id;
  final String courseId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final List<Map<String, dynamic>> attendees;
  final DateTime createdAt;
  final DateTime? signalTime; // Added signal time for attendance notification
  final int lateThresholdMinutes; // Minutes after which students are marked as late
  final int absentThresholdMinutes; // Minutes after which students are marked as absent

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.attendees,
    required this.createdAt,
    this.signalTime, // Optional signal time
    this.lateThresholdMinutes = 15, // Default to 15 minutes
    this.absentThresholdMinutes = 30, // Default to 30 minutes
  });

  // Create from Firestore document
  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? 'Attendance Session',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      attendees: List<Map<String, dynamic>>.from(data['attendees'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      signalTime: data['signalTime'] != null ? (data['signalTime'] as Timestamp).toDate() : null,
      lateThresholdMinutes: data['lateThresholdMinutes'] ?? 15, // Default to 15 if not set
      absentThresholdMinutes: data['absentThresholdMinutes'] ?? 30, // Default to 30 if not set
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': isActive,
      'attendees': attendees,
      'createdAt': Timestamp.fromDate(createdAt),
      'signalTime': signalTime != null ? Timestamp.fromDate(signalTime!) : null,
      'lateThresholdMinutes': lateThresholdMinutes,
      'absentThresholdMinutes': absentThresholdMinutes,
    };
  }
}
