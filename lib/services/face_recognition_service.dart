import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FaceRecognitionService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // API endpoint for face comparison
  final String apiUrl = 'http://45.80.181.138:8001/compare_faces';

  // Connection timeout
  final Duration connectionTimeout = Duration(seconds: 15);

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if student image exists in Firebase Storage
  Future<bool> checkStudentImageExists(String studentId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // A better way to check if a file exists without causing 404 errors
      // is to list items in the directory and check if our file is there
      final ref = _storage.ref().child('face_images');
      final result = await ref.listAll();

      // Check if any item has the student ID in its name
      for (var item in result.items) {
        if (item.name == studentId) {
          return true;
        }
      }

      // If we get here, the image doesn't exist
      return false;
    } catch (e) {
      // For unexpected errors, log them but still return false
      // to avoid crashing the app
      print('Error checking student image: $e');
      return false;
    }
  }

  // Upload student image to Firebase Storage with progress indicator
  Future<String> uploadStudentImage(
    ImageSource source, {
    Function(double)? onProgress,
    XFile? pickedFile,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Use provided pickedFile or pick a new image
      File? imageFile;

      if (pickedFile != null) {
        // Use the provided picked file
        imageFile = File(pickedFile.path);
      } else {
        // Pick a new image
        imageFile = await pickImage(source);
        if (imageFile == null) {
          throw Exception('No image selected');
        }
      }

      // We'll use Firebase's built-in progress tracking

      // Upload image to Firebase Storage using Firebase SDK
      // but track progress using stream
      final ref = _storage.ref().child('face_images/$currentUserId');
      final uploadTask = ref.putFile(imageFile);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (onProgress != null) {
          onProgress(progress);
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Pick image from gallery or camera
  Future<File?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Compare faces for verification
  Future<Map<String, dynamic>> compareFaces({
    required String studentId,
    required File imageFile,
  }) async {
    try {
      print('Starting face verification for student ID: $studentId');

      // Check if the file exists
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found at ${imageFile.path}');
      }

      // Check the file size
      final fileSize = await imageFile.length();
      print('Image file size: $fileSize bytes');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add student ID as form field
      request.fields['id'] = studentId;

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      // Send request with a longer timeout
      print('Sending request to face recognition API...');

      final client = http.Client();

      try {
        // Send the request with a longer timeout (60 seconds)
        final response = await client
            .send(request)
            .timeout(Duration(seconds: 60));

        print('API Status Code: ${response.statusCode}');

        if (response.statusCode != 200) {
          throw Exception('API returned status code ${response.statusCode}');
        }

        final responseBody = await response.stream.bytesToString();
        print('API Response received: ${responseBody.length} bytes');

        // Parse JSON response
        final result = json.decode(responseBody);

        // Check if there's an error in the response
        if (result.containsKey('error') || result.containsKey('detail')) {
          String errorMsg =
              result['error']?.toString() ??
              result['detail']?.toString() ??
              'Unknown error';
          throw Exception('API error: $errorMsg');
        }

        // Check if the result contains the expected fields
        if (!result.containsKey('match')) {
          throw Exception('Invalid API response format: missing match field');
        }

        print(
          'Face verification result: ${result['match'] ? 'Matched' : 'Not Matched'} with confidence: ${result['confidence']}%',
        );
        return result;
      } on TimeoutException {
        print('API request timed out after 60 seconds');
        throw Exception(
          'API request timed out. Please check your internet connection or try again later.',
        );
      } finally {
        client.close();
      }
    } catch (e) {
      print('Face verification error: $e');
      throw Exception('Failed to compare faces: $e');
    }
  }
}
