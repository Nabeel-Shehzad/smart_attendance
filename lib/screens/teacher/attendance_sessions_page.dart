import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/attendance_provider.dart';
import 'create_attendance_session_page.dart';
import 'attendance_session_detail_page.dart';

class AttendanceSessionsPage extends StatelessWidget {
  final String courseId;
  final String courseName;

  const AttendanceSessionsPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  static Route<dynamic> route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>;
    return MaterialPageRoute(
      builder: (context) => AttendanceSessionsPage(
        courseId: args['courseId'],
        courseName: args['courseName'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        
        title: Text(
          'Attendance Sessions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateAttendanceSessionPage(
                courseId: courseId,
                courseName: courseName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Session',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: theme.primaryColor,
        elevation: 2,
      ),
      // ignore: prefer-const-constructors
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Attendance Sessions',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Sessions list
          Expanded(
            child: StreamBuilder(
              stream: attendanceProvider.getCourseAttendanceSessions(courseId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note,
                            size: 64,
                            color: theme.primaryColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Sessions Yet',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new session to take attendance',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ignore: prefer-const-decl
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateAttendanceSessionPage(
                                  courseId: courseId,
                                  courseName: courseName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            'Create Session',
                            style: GoogleFonts.poppins(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final sessions = snapshot.data!.docs
                      ..sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = (aData['startTime'] as Timestamp).toDate();
                        final bTime = (bData['startTime'] as Timestamp).toDate();
                        return bTime.compareTo(aTime);
                      });
                    final session = sessions[index];
                    final sessionData = session.data() as Map<String, dynamic>;

                    final startTime = (sessionData['startTime'] as dynamic).toDate();
                    final endTime = (sessionData['endTime'] as dynamic).toDate();
                    final isActiveInDb = sessionData['isActive'] ?? false;
                    final now = DateTime.now();
                    final isActive = isActiveInDb && endTime.isAfter(now);
                    final attendees = (sessionData['attendees'] as List?)?.length ?? 0;

                    if (isActiveInDb && !isActive) {
                      attendanceProvider.endAttendanceSession(session.id);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceSessionDetailPage(
                              sessionId: session.id,
                              courseId: courseId,
                              courseName: courseName,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isActive ? Icons.timer : Icons.timer_off,
                                      color: isActive ? Colors.green.shade700 : Colors.grey.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sessionData['title'] ?? 'Attendance Session',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          isActive ? 'Active Session' : 'Closed Session',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            title: Text(
                                              'End Session?',
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                            ),
                                            content: Text(
                                              'Students will no longer be able to mark their attendance.',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: Text('Cancel', style: GoogleFonts.poppins()),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: Text(
                                                  'End Session',
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          final success = await attendanceProvider.endAttendanceSession(session.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              content: Text(
                                                success ? 'Session ended successfully' : 'Failed to end session',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: success ? Colors.green : Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ));
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                      label: Text('End', style: GoogleFonts.poppins(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    DateFormat('EEEE, MMMM d').format(startTime),
                                    Colors.grey[700]!,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.access_time,
                                    '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                    Colors.grey[600]!,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.people,
                                    '$attendees ${attendees == 1 ? 'student' : 'students'} present',
                                    theme.primaryColor,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
