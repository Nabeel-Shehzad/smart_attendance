import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'add_student_page.dart';
import 'attendance_sessions_page.dart';

class CourseDetailPage extends StatelessWidget {
  final String courseId;
  final String courseName;

  const CourseDetailPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: BackButton(
     color: Colors.white
   ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          courseName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        
      ),
      body: StreamBuilder(
        stream: courseProvider.getCourse(courseId),
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

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Course not found',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            );
          }

          final courseData = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> students = courseData['students'] ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                        Colors.grey[100]!,
                      ],
                    ),
                  ),
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.grey[50]!,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  courseData['courseCode'] ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 16,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${students.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            courseData['description'] ?? 'No description',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                          if (courseData['schedule'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    courseData['schedule'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AttendanceSessionsPage(
                                      courseId: courseId,
                                      courseName: courseName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.fact_check),
                              label: Text(
                                'Manage Attendance',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Students',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddStudentPage(
                                courseId: courseId,
                                courseName: courseName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: Text(
                          'Add Student',
                          style: GoogleFonts.poppins(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Students List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = students[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).primaryColor.withOpacity(0.8),
                                    Theme.of(context).primaryColor,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  student['studentName'][0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              student['studentName'] ?? 'Unknown Student',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Enrolled: ${_formatTimestamp(student['enrolledAt'])}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                              ),
                              onPressed: () {
                                _showRemoveStudentDialog(
                                  context,
                                  courseProvider,
                                  student['studentId'],
                                  student['studentName'],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: students.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showRemoveStudentDialog(
    BuildContext context,
    CourseProvider courseProvider,
    String studentId,
    String studentName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Remove Student',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure you want to remove $studentName from this course?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final success = await courseProvider.removeStudentFromCourse(
                    courseId: courseId,
                    studentId: studentId,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Student removed successfully'
                              : 'Failed to remove student: ${courseProvider.error}',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  'Remove',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
