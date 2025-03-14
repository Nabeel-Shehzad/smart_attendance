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
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: attendanceProvider.isLoading
                                  ? null
                                  : () {
                                      // Show face recognition dialog
                                      _showFaceRecognitionDialog(
                                        context,
                                        session.id,
                                        studentId,
                                        studentName,
                                      );
                                    },
                              icon: const Icon(Icons.face, color: Colors.white),
                              label: const Text(
                                'Mark Attendance with Face Recognition',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  void _showFaceRecognitionDialog(
    BuildContext context,
    String sessionId,
    String studentId,
    String studentName,
  ) {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final faceRecognitionProvider = Provider.of<FaceRecognitionProvider>(
      context,
      listen: false,
    );

    // First check if the student image exists outside of the build method
    // to avoid setState during build error
    bool? hasImage;
    bool isLoading = true;
    bool isUploading = false;
    bool isProcessingFaceRecognition = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Use a StatefulBuilder to manage dialog state
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Check for student image existence if we haven't done so yet
            if (isLoading && hasImage == null) {
              // Start the check outside of the build method
              Future.microtask(() async {
                try {
                  // We're catching the error in the provider, so this should not throw
                  final exists = await faceRecognitionProvider
                      .checkStudentImageExists(studentId);
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      hasImage = exists;
                      isLoading = false;
                    });
                  }
                } catch (e) {
                  // This is a fallback in case something unexpected happens
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      hasImage = false;
                      isLoading = false;
                    });
                    // Don't show error snackbar here as it's confusing to users
                    // The dialog will show upload options instead
                  }
                }
              });
            }

            return AlertDialog(
              title: Text(
                'Face Recognition',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              content: isLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : isProcessingFaceRecognition
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            Text(
                              'Processing face recognition...',
                              style: GoogleFonts.poppins(),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : hasImage == false
                          ? isUploading
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Uploading image...',
                                      style: GoogleFonts.poppins(),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Consumer<FaceRecognitionProvider>(
                                      builder: (context, provider, child) {
                                        return Column(
                                          children: [
                                            LinearProgressIndicator(
                                              value: provider.uploadProgress,
                                              backgroundColor: Colors.grey[300],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${(provider.uploadProgress * 100).toStringAsFixed(0)}%',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'You need to upload your image first',
                                      style: GoogleFonts.poppins(),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              setDialogState(() {
                                                // Show loading state immediately
                                                isUploading = true;
                                              });

                                              final result =
                                                  await faceRecognitionProvider
                                                      .uploadStudentImage(
                                                          ImageSource.camera);

                                              if (context.mounted) {
                                                setDialogState(() {
                                                  isUploading = false;
                                                  if (result != null) {
                                                    hasImage = true;
                                                  }
                                                });
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                            ),
                                            label: const Text('Camera'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              // First pick the image without showing loading state
                                              final picker = ImagePicker();
                                              final pickedFile =
                                                  await picker.pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 80,
                                              );

                                              // Only proceed if an image was selected
                                              if (pickedFile != null &&
                                                  context.mounted) {
                                                // Now show the loading state after image selection
                                                setDialogState(() {
                                                  isUploading = true;
                                                });

                                                // Upload the selected image
                                                final result =
                                                    await faceRecognitionProvider
                                                        .uploadStudentImage(
                                                  ImageSource.gallery,
                                                  pickedFile: pickedFile,
                                                );

                                                if (context.mounted) {
                                                  setDialogState(() {
                                                    isUploading = false;
                                                    if (result != null) {
                                                      hasImage = true;
                                                    }
                                                  });
                                                }
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.photo_library,
                                              color: Colors.white,
                                            ),
                                            label: const Text('Gallery'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Take a photo to verify your identity',
                                  style: GoogleFonts.poppins(),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        // First get the image from camera
                                        final picker = ImagePicker();
                                        final pickedFile =
                                            await picker.pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 80,
                                        );

                                        if (pickedFile != null &&
                                            context.mounted) {
                                          // Show loading indicator for face recognition
                                          setDialogState(() {
                                            isProcessingFaceRecognition = true;
                                          });

                                          final imageFile =
                                              File(pickedFile.path);

                                          // Get comparison result from face recognition provider
                                          final comparisonResult =
                                              await faceRecognitionProvider
                                                  .compareFaces(
                                            studentId: studentId,
                                            imageFile: imageFile,
                                          );

                                          // Hide loading indicator
                                          if (context.mounted) {
                                            setDialogState(() {
                                              isProcessingFaceRecognition =
                                                  false;
                                            });
                                          }

                                          if (comparisonResult != null &&
                                              comparisonResult[
                                                      'verification_match'] ==
                                                  true) {
                                            // If faces match, mark attendance
                                            final success = await attendanceProvider
                                                .markAttendanceWithFaceRecognition(
                                              sessionId: sessionId,
                                              studentId: studentId,
                                              studentName: studentName,
                                              imageFile: imageFile,
                                            );

                                            if (context.mounted) {
                                              Navigator.of(context).pop();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? 'Attendance marked successfully'
                                                        : 'Failed to mark attendance: ${attendanceProvider.error}',
                                                    style:
                                                        GoogleFonts.poppins(),
                                                  ),
                                                  backgroundColor: success
                                                      ? Colors.green
                                                      : Colors.red,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          } else {
                                            // If faces don't match or there was an API error
                                            if (context.mounted) {
                                              String errorMessage =
                                                  'Face verification failed.';

                                              // Show confidence score if available
                                              if (comparisonResult != null &&
                                                  comparisonResult.containsKey(
                                                      'confidence')) {
                                                double confidence =
                                                    comparisonResult[
                                                        'confidence'];
                                                errorMessage =
                                                    'Face verification failed (Confidence: ${confidence.toStringAsFixed(1)}%).';
                                              }

                                              // Check if we have a more specific error message
                                              if (comparisonResult != null &&
                                                  comparisonResult.containsKey(
                                                      'detail')) {
                                                errorMessage =
                                                    'Error: ${comparisonResult['detail']}';
                                              } else if (faceRecognitionProvider
                                                      .error !=
                                                  null) {
                                                errorMessage =
                                                    'Error: ${faceRecognitionProvider.error}';
                                              }

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    errorMessage,
                                                    style:
                                                        GoogleFonts.poppins(),
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                      seconds: 5),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          // Extract the most useful part of the error message
                                          String errorMsg = e.toString();
                                          if (errorMsg.contains(
                                              'Exception: Failed to compare faces:')) {
                                            errorMsg = errorMsg.replaceAll(
                                                'Exception: Failed to compare faces: ',
                                                '');
                                          }
                                          if (errorMsg.contains(
                                              'Exception: API error:')) {
                                            errorMsg = errorMsg.replaceAll(
                                                'Exception: API error: ', '');
                                          }

                                          print(
                                              'Face recognition error: $errorMsg');

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error: $errorMsg',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration:
                                                  const Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.white),
                                    label: const Text('Take Photo'),
                                  ),
                                ),
                              ],
                            ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
