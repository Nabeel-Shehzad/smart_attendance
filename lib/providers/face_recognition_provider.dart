import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/face_recognition_service.dart';

class FaceRecognitionProvider with ChangeNotifier {
  final FaceRecognitionService _faceRecognitionService =
      FaceRecognitionService();

  bool _isLoading = false;
  String? _error;
  bool _hasUploadedImage = false;
  double _uploadProgress = 0.0;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUploadedImage => _hasUploadedImage;
  double get uploadProgress => _uploadProgress;

  // Check if student image exists
  Future<bool> checkStudentImageExists(String studentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final exists = await _faceRecognitionService.checkStudentImageExists(
        studentId,
      );
      _hasUploadedImage = exists;

      _isLoading = false;
      notifyListeners();

      return exists;
    } catch (e) {
      // Most likely the image doesn't exist, which is a valid state
      // Just set hasUploadedImage to false and don't treat it as an error
      _hasUploadedImage = false;
      _error = null; // Clear any previous errors
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Upload student image with progress tracking
  Future<String?> uploadStudentImage(
    ImageSource source, {
    XFile? pickedFile,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _uploadProgress = 0.0;
      notifyListeners();

      File? imageFile;

      // If pickedFile is provided, use it directly
      if (pickedFile != null) {
        imageFile = File(pickedFile.path);
      } else {
        // Otherwise pick a new image
        imageFile = await _faceRecognitionService.pickImage(source);

        if (imageFile == null) {
          _error = 'No image selected';
          _isLoading = false;
          notifyListeners();
          return null;
        }
      }

      // Upload image with progress tracking
      final downloadUrl = await _faceRecognitionService.uploadStudentImage(
        source,
        pickedFile: pickedFile,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );
      _hasUploadedImage = true;

      _isLoading = false;
      notifyListeners();

      return downloadUrl;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Compare faces for verification
  Future<Map<String, dynamic>?> compareFaces({
    required String studentId,
    required File imageFile,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Provider: Starting face comparison for student ID: $studentId');
      print('Provider: Image file exists: ${imageFile.existsSync()}');
      print('Provider: Image file path: ${imageFile.path}');
      print('Provider: Image file size: ${await imageFile.length()} bytes');

      final result = await _faceRecognitionService.compareFaces(
        studentId: studentId,
        imageFile: imageFile,
      );

      print('Provider: API response received: $result');

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      print('Provider: Face comparison error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
