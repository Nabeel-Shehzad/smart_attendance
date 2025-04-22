import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/face_recognition_provider.dart';
import '../../models/attendance_session.dart';

class StudentCourseDetailPage extends StatelessWidget {
  final String courseId;
  final String courseName;

  const StudentCourseDetailPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final courseProvider = Provider.of<CourseProvider>(context);

    final studentId = authProvider.user?.uid ?? '';
    final studentName = authProvider.user?.displayName ?? 'Unknown Student';

    return Scaffold(
      appBar: _buildAppBar(),
      body: FutureBuilder(
        future: courseProvider.getCourseById(courseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingIndicator();
          }

          if (snapshot.hasError) {
            return _ErrorDisplay(error: snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const _ErrorDisplay(error: 'Course not found');
          }

          final courseData = snapshot.data!.data() as Map<String, dynamic>;
          return _CourseDetailContent(
            courseData: courseData,
            courseId: courseId, // Pass the courseId here
            attendanceProvider: attendanceProvider,
            studentId: studentId,
            studentName: studentName,
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        courseName,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String error;

  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Error: $error',
        style: GoogleFonts.poppins(color: Colors.red),
      ),
    );
  }
}

class _CourseDetailContent extends StatelessWidget {
  final Map<String, dynamic> courseData;
  final AttendanceProvider attendanceProvider;
  final String studentId;
  final String studentName;
  final String courseId; // Add courseId parameter

  const _CourseDetailContent({
    required this.courseData,
    required this.attendanceProvider,
    required this.studentId,
    required this.studentName,
    required this.courseId, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CourseInfoCard(courseData: courseData),
        _ActiveSessionsHeader(),
        Expanded(
          child: _ActiveSessionsList(
            attendanceProvider: attendanceProvider,
            studentId: studentId,
            studentName: studentName,
            courseId: courseId, // Pass the courseId from parameter instead of courseData
          ),
        ),
      ],
    );
  }
}

class _CourseInfoCard extends StatelessWidget {
  final Map<String, dynamic> courseData;

  const _CourseInfoCard({required this.courseData});

  @override
  Widget build(BuildContext context) {
    final courseCode = courseData['courseCode'] ?? '';
    final description = courseData['description'] ?? 'No description';
    final instructorName = courseData['instructorName'] ?? 'Unknown Instructor';
    final schedule = courseData['schedule'] ?? 'Not specified';

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourseHeader(courseCode: courseCode),
            const SizedBox(height: 16),
            _CourseDescription(description: description),
            const SizedBox(height: 16),
            _CourseInstructor(instructorName: instructorName),
            const SizedBox(height: 8),
            _CourseSchedule(schedule: schedule),
          ],
        ),
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final String courseCode;

  const _CourseHeader({required this.courseCode});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Course Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            courseCode,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseDescription extends StatelessWidget {
  final String description;

  const _CourseDescription({required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

class _CourseInstructor extends StatelessWidget {
  final String instructorName;

  const _CourseInstructor({required this.instructorName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          'Instructor: $instructorName',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _CourseSchedule extends StatelessWidget {
  final String schedule;

  const _CourseSchedule({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          'Schedule: $schedule',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _ActiveSessionsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.fact_check,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Active Attendance Sessions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionsList extends StatelessWidget {
  final AttendanceProvider attendanceProvider;
  final String studentId;
  final String studentName;
  final String courseId; // Add courseId parameter

  const _ActiveSessionsList({
    required this.attendanceProvider,
    required this.studentId,
    required this.studentName,
    required this.courseId, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: attendanceProvider.getCourseAttendanceSessions(courseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final sessions = snapshot.data?.docs ?? [];

        // Filter for active sessions
        final activeSessions = sessions
            .map((doc) => AttendanceSession.fromFirestore(doc))
            .where(
              (session) =>
                  session.isActive && session.endTime.isAfter(DateTime.now()),
            )
            .toList();

        if (activeSessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No active sessions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'There are no active attendance sessions for this course',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeSessions.length,
          itemBuilder: (context, index) {
            final session = activeSessions[index];

            // Check if student has already marked attendance
            final hasMarkedAttendance = session.attendees.any(
              (attendee) => attendee['studentId'] == studentId,
            );

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'EEEE, MMM d, yyyy',
                          ).format(session.startTime),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (hasMarkedAttendance)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Attendance Marked',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Go to Attendance tab to mark attendance',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
