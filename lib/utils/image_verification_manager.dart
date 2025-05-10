// Helper utility file to manage the image storage for verification
import 'dart:io';

class ImageVerificationManager {
  static File? _cachedImageFile;
  static Map<String, dynamic>? _cachedVerificationResult;

  // Save image file and verification result
  static void saveVerificationData(
    File imageFile,
    Map<String, dynamic> result,
  ) {
    try {
      // Create a copy of the image file in the same directory with a timestamp
      final imageDir = Directory(imageFile.parent.path);
      final newImagePath =
          '${imageDir.path}/verification_${DateTime.now().millisecondsSinceEpoch}.jpg';
      imageFile.copySync(newImagePath);

      // Create and store a new file reference to the copied file
      _cachedImageFile = File(newImagePath);

      // Store the verification result
      _cachedVerificationResult = Map<String, dynamic>.from(result);

      // Add the image path to the result
      _cachedVerificationResult!['imagePath'] = newImagePath;

      print('Saved verification image to: $newImagePath');
    } catch (e) {
      print('Error saving verification data: $e');
    }
  }

  // Get the cached image file
  static File? getCachedImageFile() {
    return _cachedImageFile;
  }

  // Get the cached verification result
  static Map<String, dynamic>? getCachedVerificationResult() {
    return _cachedVerificationResult;
  }

  // Clear the cached data
  static void clear() {
    // Delete the cached file if it exists
    if (_cachedImageFile != null && _cachedImageFile!.existsSync()) {
      try {
        _cachedImageFile!.deleteSync();
      } catch (e) {
        print('Error deleting cached file: $e');
      }
    }

    _cachedImageFile = null;
    _cachedVerificationResult = null;
  }
}
