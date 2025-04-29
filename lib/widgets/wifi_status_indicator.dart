import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Define the possible connection statuses with clear meanings
enum WifiConnectionStatus {
  searching,    // Actively looking for WiFi signals
  notConnected, // No connection (WiFi exists but not connected)
  connected,    // Successfully connected to a WiFi signal
  error,        // Error with WiFi or permissions
}

class WifiStatusIndicator extends StatelessWidget {
  final WifiConnectionStatus status;
  final String sessionId;
  final String message;
  final VoidCallback onRetry;

  const WifiStatusIndicator({
    Key? key,
    required this.status,
    required this.sessionId,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // WiFi Icon and Status Animation
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _getIconBackgroundColor(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _buildStatusIcon(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status Title
          Text(
            _getStatusTitle(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _getTitleColor(),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Status Message
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _getMessageColor(),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Session ID indicator (for verification)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tag,
                  size: 14,
                  color: Colors.black54,
                ),
                SizedBox(width: 4),
                Text(
                  'Session ID: ${sessionId.substring(0, 6)}...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          if (status == WifiConnectionStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget for the animated status icon
  Widget _buildStatusIcon() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                strokeWidth: 2,
              ),
            ),
            Icon(
              Icons.wifi_find,
              size: 24,
              color: Colors.blue.shade700,
            ),
          ],
        );
      
      case WifiConnectionStatus.notConnected:
        return Icon(
          Icons.wifi_off,
          size: 32,
          color: Colors.orange.shade700,
        );
      
      case WifiConnectionStatus.connected:
        return Icon(
          Icons.wifi,
          size: 32,
          color: Colors.green.shade700,
        );
      
      case WifiConnectionStatus.error:
        return Icon(
          Icons.error_outline,
          size: 32,
          color: Colors.red.shade700,
        );
    }
  }

  // Get title text based on status
  String _getStatusTitle() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return 'Searching for WiFi';
      case WifiConnectionStatus.notConnected:
        return 'Not Connected';
      case WifiConnectionStatus.connected:
        return 'WiFi Connected';
      case WifiConnectionStatus.error:
        return 'Connection Error';
    }
  }

  // Color for container background
  Color _getBackgroundColor() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Colors.blue.shade50;
      case WifiConnectionStatus.notConnected:
        return Colors.orange.shade50;
      case WifiConnectionStatus.connected:
        return Colors.green.shade50;
      case WifiConnectionStatus.error:
        return Colors.red.shade50;
    }
  }

  // Color for container border
  Color _getBorderColor() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Colors.blue.shade200;
      case WifiConnectionStatus.notConnected:
        return Colors.orange.shade200;
      case WifiConnectionStatus.connected:
        return Colors.green.shade200;
      case WifiConnectionStatus.error:
        return Colors.red.shade200;
    }
  }

  // Background color for icon
  Color _getIconBackgroundColor() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Colors.blue.shade100;
      case WifiConnectionStatus.notConnected:
        return Colors.orange.shade100;
      case WifiConnectionStatus.connected:
        return Colors.green.shade100;
      case WifiConnectionStatus.error:
        return Colors.red.shade100;
    }
  }

  // Color for title text
  Color _getTitleColor() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Colors.blue.shade700;
      case WifiConnectionStatus.notConnected:
        return Colors.orange.shade700;
      case WifiConnectionStatus.connected:
        return Colors.green.shade700;
      case WifiConnectionStatus.error:
        return Colors.red.shade700;
    }
  }

  // Color for message text
  Color _getMessageColor() {
    switch (status) {
      case WifiConnectionStatus.searching:
        return Colors.blue.shade600;
      case WifiConnectionStatus.notConnected:
        return Colors.orange.shade600;
      case WifiConnectionStatus.connected:
        return Colors.green.shade600;
      case WifiConnectionStatus.error:
        return Colors.red.shade600;
    }
  }
}
