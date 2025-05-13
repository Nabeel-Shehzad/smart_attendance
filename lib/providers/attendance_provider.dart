import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/attendance_service.dart';
import '../services/face_recognition_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final FaceRecognitionService _faceRecognitionService =
      FaceRecognitionService();
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Create a new attendance session
  Future<DocumentReference?> createAttendanceSession({
    required String courseId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    int lateThresholdMinutes = 15,
    int absentThresholdMinutes = 30,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final sessionRef = await _attendanceService.createAttendanceSession(
        courseId: courseId,
        title: title,
        startTime: startTime,
        endTime: endTime,
        lateThresholdMinutes: lateThresholdMinutes,
        absentThresholdMinutes: absentThresholdMinutes,
      );

      return sessionRef;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get attendance sessions for a course
  Stream<QuerySnapshot> getCourseAttendanceSessions(String courseId) {
    return _attendanceService.getCourseAttendanceSessions(courseId);
  }

  // Get a specific attendance session
  Stream<DocumentSnapshot> getAttendanceSession(String sessionId) {
    return _attendanceService.getAttendanceSession(sessionId);
  }

  // End an attendance session
  Future<bool> endAttendanceSession(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _attendanceService.endAttendanceSession(sessionId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send attendance signal (updated for WiFi)
  Future<bool> sendAttendanceSignal(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _attendanceService.sendAttendanceSignal(sessionId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Stop attendance signal (new method for WiFi)
  Future<bool> stopAttendanceSignal(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _attendanceService.stopAttendanceSignal(sessionId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update attendance statuses based on time thresholds
  Future<bool> updateAttendanceStatuses(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _attendanceService.updateAttendanceStatuses(
        sessionId,
      );

      return result;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if a session has an active WiFi signal
  Future<bool> isSessionSignalActive(String sessionId) async {
    try {
      return await _attendanceService.isSessionSignalActive(sessionId);
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // Get student notifications
  Stream<QuerySnapshot> getNotifications() {
    return _attendanceService.getNotifications();
  }

  // Mark a notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _attendanceService.markNotificationAsRead(notificationId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // Mark attendance for a student
  Future<bool> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    bool wifiVerified = false, // New parameter for WiFi verification
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Add WiFi verification parameter
      await _attendanceService.markAttendance(
        sessionId: sessionId,
        studentId: studentId,
        studentName: studentName,
        verificationMethod: 'Manual',
        wifiVerified: wifiVerified,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark attendance using face recognition (updated with BLE verification)
  Future<bool> markAttendanceWithFaceRecognition({
    required String sessionId,
    required String studentId,
    required String studentName,
    required File imageFile,
    Map<String, dynamic>?
    verificationResult, // Add optional parameter to pass existing verification result
    bool wifiVerified = false, // Add WiFi verification status
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      Map<String, dynamic> comparisonResult;

      // Only do face comparison if verification result is not provided
      if (verificationResult == null) {
        // Check if student image exists in Firebase Storage
        final hasImage = await _faceRecognitionService.checkStudentImageExists(
          studentId,
        );

        if (!hasImage) {
          _error = 'No profile image found. Please upload your image first.';
          return false;
        }

        // Compare the captured image with the stored image
        comparisonResult = await _faceRecognitionService.compareFaces(
          studentId: studentId,
          imageFile: imageFile,
        );
      } else {
        // Use the provided verification result
        comparisonResult = verificationResult;
      }

      // Extract the confidence value, handling both formats
      final confidence =
          comparisonResult['confidence'] ??
          comparisonResult['verification_confidence'] ??
          0.0;

      // Check if the face verification passed (handling both possible key names)
      if (comparisonResult['verification_match'] == true ||
          comparisonResult['match'] == true) {
        // If faces match, mark attendance with WiFi verification status
        await _attendanceService.markAttendance(
          sessionId: sessionId,
          studentId: studentId,
          studentName: studentName,
          verificationMethod: 'Face Recognition',
          verificationData: {
            'confidence': confidence,
            'timestamp': DateTime.now().toIso8601String(),
          },
          wifiVerified: wifiVerified, // Pass the WiFi verification status
        );

        return true;
      } else {
        _error = 'Face verification failed. Please try again.';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
