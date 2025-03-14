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

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.attendees,
    required this.createdAt,
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
    };
  }
}
