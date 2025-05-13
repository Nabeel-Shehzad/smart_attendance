// This file contains code snippets that need to be added to the student_attendance_page.dart 
// file to fix the attendance marking functionality. Follow the instructions below to implement
// the fix properly.

// -----------------------------------------------------
// STEP 1: Modify the _buildFaceVerificationUI method
// -----------------------------------------------------
// In the _buildFaceVerificationUI method, find the section where face verification is successful 
// (around line 1720-1740) and replace the code with this implementation:

if (result['match'] == true && context.mounted) {
  // Store the verification result and image file using the utility manager
  ImageVerificationManager.saveVerificationData(
    imageFile,
    result,
  );

  // Update the class-level variables
  _StudentAttendancePageState._faceVerificationResult =
      ImageVerificationManager.getCachedVerificationResult();
  _StudentAttendancePageState._capturedImageFile =
      ImageVerificationManager.getCachedImageFile();

  print('Saved verification image: ${_StudentAttendancePageState._capturedImageFile?.path}');

  // First close the dialog to ensure SnackBar is visible
  if (context.mounted && Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  // Use the callback to update parent state
  // Pass false for isProfileUpload since this is actual face verification
  onImageUploadComplete(true, false);
  
  // Now call attendanceProvider to mark attendance with the WiFi verification status
  final attendanceProvider = Provider.of<AttendanceProvider>(
    context,
    listen: false,
  );
  
  final authProvider = Provider.of<AuthProvider>(
    context,
    listen: false,
  );
  
  final currentStudentId = authProvider.user?.uid ?? '';
  final currentStudentName = authProvider.user?.displayName ?? '';
  
  // Mark attendance for active sessions
  if (currentStudentId.isNotEmpty) {
    try {
      // Get the active WiFi sessions for this student
      _getActiveSessionIdsForStudent(currentStudentId).then((sessionIds) async {
        if (sessionIds.isNotEmpty) {
          for (final sessionId in sessionIds) {
            // Check if WiFi signal was detected for this session
            final wifiVerified = _wifiSignalDetectedMap[sessionId] ?? false;
            
            try {
              final success = await attendanceProvider.markAttendanceWithFaceRecognition(
                sessionId: sessionId,
                studentId: currentStudentId,
                studentName: currentStudentName,
                imageFile: imageFile,
                verificationResult: result,
                wifiVerified: wifiVerified,
              );
              
              if (success && context.mounted) {
                // Get the attendance status from Firestore to show appropriate message
                final sessionDoc = await FirebaseFirestore.instance
                    .collection('attendance_sessions')
                    .doc(sessionId)
                    .get();
                
                if (sessionDoc.exists && context.mounted) {
                  final data = sessionDoc.data() as Map<String, dynamic>;
                  final attendees = List<Map<String, dynamic>>.from(data['attendees'] ?? []);
                  final myAttendance = attendees.firstWhere(
                    (a) => a['studentId'] == currentStudentId,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  final status = myAttendance['status'] ?? 'unknown';
                  String message = 'Attendance marked successfully!';
                  Color bgColor = Colors.green;
                  
                  if (status == 'late') {
                    message = 'Attendance marked as LATE - you arrived after the threshold time.';
                    bgColor = Colors.orange;
                  } else if (status == 'absent') {
                    message = 'Attendance marked as ABSENT - you arrived after the cutoff time.';
                    bgColor = Colors.red;
                  } else if (status == 'present') {
                    message = 'Attendance marked as PRESENT - you arrived on time!';
                    bgColor = Colors.green;
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        message,
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: bgColor,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            } catch (e) {
              print('Error marking attendance: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error marking attendance: $e',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }
        }
      });
    } catch (e) {
      print('Error getting active sessions: $e');
    }
  }
} else if (context.mounted) {
  // Close dialog before showing SnackBar for error too
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  
  // Rest of the error handling code...
}

// -----------------------------------------------------
// STEP 2: Update the success handler in the WiFi attendance dialog
// -----------------------------------------------------
// After successful attendance marking in the _showWifiAttendanceDialog method (around line 1450),
// replace the success handler with this implementation:

if (success && context.mounted) {
  // Stop scanning and clean up timer
  statusCheckTimer?.cancel();
  final wifiProvider = Provider.of<wifi_provider.WifiProvider>(context, listen: false);
  wifiProvider.stopScanning();
  Navigator.of(dialogContext).pop();

  // Refresh UI to update attendance status
  Future.delayed(Duration(milliseconds: 500), () {
    if (mounted) {
      setState(() {
        // Trigger a UI rebuild
      });
    }
  });

  // Get the attendance status from Firestore to show appropriate message
  FirebaseFirestore.instance
      .collection('attendance_sessions')
      .doc(sessionId)
      .get()
      .then((doc) {
    if (doc.exists && context.mounted) {
      final data = doc.data() as Map<String, dynamic>;
      final attendees = List<Map<String, dynamic>>.from(data['attendees'] ?? []);
      final myAttendance = attendees.firstWhere(
        (a) => a['studentId'] == studentId,
        orElse: () => <String, dynamic>{},
      );
      
      final status = myAttendance['status'] ?? 'unknown';
      String message = 'Attendance marked successfully!';
      Color bgColor = Colors.green;
      
      if (status == 'late') {
        message = 'Attendance marked as LATE - you arrived after the threshold time.';
        bgColor = Colors.orange;
      } else if (status == 'absent') {
        message = 'Attendance marked as ABSENT - you arrived after the cutoff time.';
        bgColor = Colors.red;
      } else if (status == 'present') {
        message = 'Attendance marked as PRESENT - you arrived on time!';
        bgColor = Colors.green;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      // Fall back to basic message if can't get status
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Attendance marked successfully!' : 'Failed to mark attendance. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

// -----------------------------------------------------
// STEP 3: Make sure the AttendanceProvider properly sets the status
// -----------------------------------------------------
// Verify that the markAttendance method in AttendanceService properly sets the 
// student's attendance status based on the thresholds. The relevant code that should
// exist in lib/services/attendance_service.dart is:

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
  } else if (difference.inMinutes > lateThresholdMinutes) {
    status = 'late';
  }
}

// Add the attendee with the determined status
final newAttendee = {
  'studentId': studentId,
  'studentName': validStudentName,
  'timestamp': Timestamp.now(),
  'verificationMethod': verificationMethod,
  'verificationData': verificationData ?? {},
  'status': status,  // This is the important line that sets the status
};

await _firestore
    .collection('attendance_sessions')
    .doc(sessionId)
    .update({
  'attendees': FieldValue.arrayUnion([newAttendee]),
});
