import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/attendance_service.dart';
import '../services/face_recognition_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
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
  
  // Mark attendance for a student
  Future<bool> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _attendanceService.markAttendance(
        sessionId: sessionId,
        studentId: studentId,
        studentName: studentName,
        verificationMethod: 'Manual',
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
  
  // Mark attendance using face recognition
  Future<bool> markAttendanceWithFaceRecognition({
    required String sessionId,
    required String studentId,
    required String studentName,
    required File imageFile,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Check if student image exists in Firebase Storage
      final hasImage = await _faceRecognitionService.checkStudentImageExists(studentId);
      
      if (!hasImage) {
        _error = 'No profile image found. Please upload your image first.';
        return false;
      }
      
      // Compare the captured image with the stored image
      final comparisonResult = await _faceRecognitionService.compareFaces(
        studentId: studentId,
        imageFile: imageFile,
      );
      
      if (comparisonResult['match'] == true) {
        // If faces match, mark attendance
        await _attendanceService.markAttendance(
          sessionId: sessionId,
          studentId: studentId,
          studentName: studentName,
          verificationMethod: 'Face Recognition',
          verificationData: {
            'confidence': comparisonResult['confidence'],
            'timestamp': DateTime.now().toIso8601String(),
          },
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
