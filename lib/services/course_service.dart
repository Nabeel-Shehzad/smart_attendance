import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a new course
  Future<DocumentReference> createCourse({
    required String courseCode,
    required String courseName,
    required String description,
    String? schedule,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Get instructor details
    final instructorDoc = await _firestore.collection('users').doc(currentUserId).get();
    final instructorName = instructorDoc.data()?['fullName'] ?? 'Unknown';
    final instructorId = currentUserId!;

    // Create course document
    return await _firestore.collection('courses').add({
      'courseCode': courseCode,
      'courseName': courseName,
      'description': description,
      'schedule': schedule,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'students': [],
    });
  }

  // Get all courses for the current instructor
  Stream<QuerySnapshot> getInstructorCourses() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Using a simpler query to avoid requiring a composite index
    // We're only filtering by instructorId without complex ordering
    return _firestore
        .collection('courses')
        .where('instructorId', isEqualTo: currentUserId)
        .snapshots();
  }

  // Get a specific course
  Stream<DocumentSnapshot> getCourse(String courseId) {
    return _firestore.collection('courses').doc(courseId).snapshots();
  }
  
  // Get a specific course by ID (non-stream version)
  Future<DocumentSnapshot> getCourseById(String courseId) {
    return _firestore.collection('courses').doc(courseId).get();
  }
  
  // Get all courses for the current student
  Stream<QuerySnapshot> getStudentCourses() {
    // Return empty result if user is not authenticated (during logout)
    if (currentUserId == null) {
      return _firestore
          .collection('courses')
          .where('nonexistent_field', isEqualTo: true) // Empty result query
          .snapshots();
    }
    
    // Get all courses and filter in the UI
    return _firestore
        .collection('courses')
        .snapshots();
  }

  // Update course details
  Future<void> updateCourse({
    required String courseId,
    String? courseCode,
    String? courseName,
    String? description,
    String? schedule,
  }) async {
    Map<String, dynamic> updateData = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (courseCode != null) updateData['courseCode'] = courseCode;
    if (courseName != null) updateData['courseName'] = courseName;
    if (description != null) updateData['description'] = description;
    if (schedule != null) updateData['schedule'] = schedule;

    await _firestore.collection('courses').doc(courseId).update(updateData);
  }

  // Delete a course
  Future<void> deleteCourse(String courseId) async {
    await _firestore.collection('courses').doc(courseId).delete();
  }

  // Add a student to a course
  Future<void> addStudentToCourse({
    required String courseId,
    required String studentId,
    required String studentName,
  }) async {
    // First check if the student exists
    final studentDoc = await _firestore.collection('users').doc(studentId).get();
    
    if (!studentDoc.exists) {
      throw Exception('Student not found');
    }
    
    if (studentDoc.data()?['role'] != 'student') {
      throw Exception('User is not a student');
    }

    // Get the course document
    final courseDoc = await _firestore.collection('courses').doc(courseId).get();
    
    if (!courseDoc.exists) {
      throw Exception('Course not found');
    }
    
    // Check if student is already in the course
    List<dynamic> students = courseDoc.data()?['students'] ?? [];
    bool studentExists = students.any((student) => student['studentId'] == studentId);
    
    if (studentExists) {
      throw Exception('Student is already enrolled in this course');
    }
    
    // Get current timestamp as a regular Timestamp (not a FieldValue)
    final now = Timestamp.now();
    
    // Add student to the course
    await _firestore.collection('courses').doc(courseId).update({
      'students': FieldValue.arrayUnion([
        {
          'studentId': studentId,
          'studentName': studentName,
          'enrolledAt': now,
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove a student from a course
  Future<void> removeStudentFromCourse({
    required String courseId,
    required String studentId,
  }) async {
    // Get the course document
    final courseDoc = await _firestore.collection('courses').doc(courseId).get();
    
    if (!courseDoc.exists) {
      throw Exception('Course not found');
    }
    
    // Get current students
    List<dynamic> students = List.from(courseDoc.data()?['students'] ?? []);
    
    // Find the student to remove
    int studentIndex = students.indexWhere((student) => student['studentId'] == studentId);
    
    if (studentIndex == -1) {
      throw Exception('Student not found in this course');
    }
    
    // Remove the student
    students.removeAt(studentIndex);
    
    // Update the course document
    await _firestore.collection('courses').doc(courseId).update({
      'students': students,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Search for students by name or ID
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // Convert query to lowercase for case-insensitive comparison
    final lowercaseQuery = query.toLowerCase();
    
    // Get all students - we'll filter them in memory
    // This is more flexible than using Firestore queries with specific field constraints
    final allStudents = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .limit(100) // Reasonable limit to avoid loading too many users
        .get();
    
    // Filter and map results
    List<Map<String, dynamic>> results = [];
    
    for (var doc in allStudents.docs) {
      final data = doc.data();
      final fullName = (data['fullName'] ?? '').toString().toLowerCase();
      final studentId = (data['studentId'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      
      // Check if any field contains the query string
      if (fullName.contains(lowercaseQuery) || 
          studentId.contains(lowercaseQuery) || 
          email.contains(lowercaseQuery)) {
        
        results.add({
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Unknown',
          'studentId': data['studentId'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
        });
      }
    }
    
    // Sort results by name for better usability
    results.sort((a, b) => (a['fullName'] ?? '').compareTo(b['fullName'] ?? ''));
    
    return results;
  }
}
