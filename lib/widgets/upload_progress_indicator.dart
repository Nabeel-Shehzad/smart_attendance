import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/face_recognition_provider.dart';

/// A widget that shows the upload progress with a circular indicator
/// and percentage text
class UploadProgressIndicator extends StatefulWidget {
  final FaceRecognitionProvider provider;

  const UploadProgressIndicator({Key? key, required this.provider})
    : super(key: key);

  @override
  UploadProgressIndicatorState createState() => UploadProgressIndicatorState();
}

class UploadProgressIndicatorState extends State<UploadProgressIndicator> {
  double _progress = 0.0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Poll for progress updates more frequently for smoother updates
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      final currentProgress = widget.provider.uploadProgress;
      if (currentProgress != _progress) {
        setState(() {
          _progress = currentProgress;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            // Always show determinate progress indicator with the current progress value
            value: _progress,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading: ${(_progress * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
