import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/course_service.dart';

class CourseProvider extends ChangeNotifier {
  final CourseService _courseService = CourseService();
  bool _isLoading = false;
  String? _error;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Create a new course
  Future<DocumentReference?> createCourse({
    required String courseCode,
    required String courseName,
    required String description,
    String? schedule,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final courseRef = await _courseService.createCourse(
        courseCode: courseCode,
        courseName: courseName,
        description: description,
        schedule: schedule,
      );
      
      return courseRef;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get instructor courses
  Stream<QuerySnapshot> getInstructorCourses() {
    return _courseService.getInstructorCourses();
  }
  
  // Get a specific course
  Stream<DocumentSnapshot> getCourse(String courseId) {
    return _courseService.getCourse(courseId);
  }
  
  // Get a specific course by ID (non-stream version)
  Future<DocumentSnapshot> getCourseById(String courseId) async {
    return await _courseService.getCourseById(courseId);
  }
  
  // Get all courses for the current student
  Stream<QuerySnapshot> getStudentCourses() {
    return _courseService.getStudentCourses();
  }
  
  // Update course details
  Future<bool> updateCourse({
    required String courseId,
    String? courseCode,
    String? courseName,
    String? description,
    String? schedule,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _courseService.updateCourse(
        courseId: courseId,
        courseCode: courseCode,
        courseName: courseName,
        description: description,
        schedule: schedule,
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
  
  // Delete a course
  Future<bool> deleteCourse(String courseId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _courseService.deleteCourse(courseId);
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Add a student to a course
  Future<bool> addStudentToCourse({
    required String courseId,
    required String studentId,
    required String studentName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _courseService.addStudentToCourse(
        courseId: courseId,
        studentId: studentId,
        studentName: studentName,
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
  
  // Remove a student from a course
  Future<bool> removeStudentFromCourse({
    required String courseId,
    required String studentId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _courseService.removeStudentFromCourse(
        courseId: courseId,
        studentId: studentId,
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
  
  // Search for students
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final results = await _courseService.searchStudents(query);
      
      return results;
    } catch (e) {
      _error = e.toString();
      return [];
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
