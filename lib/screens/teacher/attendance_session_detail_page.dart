import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/wifi_provider.dart' as wifi_provider;
import '../../providers/auth_provider.dart'; 
import '../../models/attendance_session.dart';
import '../../widgets/student_attendance_item.dart';

class AttendanceSessionDetailPage extends StatefulWidget {
  final String sessionId;
  final String courseId;
  final String courseName;

  const AttendanceSessionDetailPage({
    Key? key,
    required this.sessionId,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<AttendanceSessionDetailPage> createState() =>
      _AttendanceSessionDetailPageState();
}

class _AttendanceSessionDetailPageState
    extends State<AttendanceSessionDetailPage> {
  bool _isBroadcasting = false;

  @override
  void initState() {
    super.initState();
    _checkWifiSignalStatus();
  }

  Future<void> _checkWifiSignalStatus() async {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final isActive = await attendanceProvider.isSessionSignalActive(
      widget.sessionId,
    );

    if (mounted) {
      setState(() {
        _isBroadcasting = isActive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        title: Text(
          'Session Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder(
        stream: attendanceProvider.getAttendanceSession(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Session not found',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          }

          final session = AttendanceSession.fromFirestore(snapshot.data!);
          final attendees = session.attendees;
          final isActive = session.isActive;

          // Get WiFi signal status from Firestore, safely accessing the data
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final wifiSignalActive = data?['wifiSignalActive'] ?? false;

          // Only update local state if it doesn't match Firestore when the component mounts
          // This prevents constant refreshing/blinking of the UI
          if (_isBroadcasting != wifiSignalActive && mounted) {
            // We'll handle this in initState and _checkWifiSignalStatus instead
            // to avoid the blinking issue
            _isBroadcasting = wifiSignalActive;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.courseName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  isActive
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? Colors.green.shade100
                                        : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isActive ? Icons.timer : Icons.timer_off,
                                color:
                                    isActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Status',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  isActive ? 'Active' : 'Closed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isActive
                                            ? Colors.green.shade700
                                            : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (_isBroadcasting)
                              Container(
                                 padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wifi,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'WiFi Active',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Date',
                              DateFormat(
                                'EEEE, MMM d, yyyy',
                              ).format(session.startTime),
                              theme,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.access_time,
                              'Time',
                              '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
                              theme,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.timelapse,
                              'Duration',
                              '${session.endTime.difference(session.startTime).inMinutes} minutes',
                              theme,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.timer_outlined,
                              'Attendance Thresholds',
                              'Late: ${session.lateThresholdMinutes} min | Absent: ${session.absentThresholdMinutes} min',
                              theme,
                            ),
                          ],
                        ),
                      ),
                      if (isActive) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      wifiProvider.status == wifi_provider.WifiConnectionStatus.error
                                          ? null
                                          : (_isBroadcasting
                                              ? _stopBroadcasting
                                              : _startBroadcasting),
                                  icon: Icon(
                                    _isBroadcasting
                                        ? Icons.wifi_off
                                        : Icons.wifi,
                                  ),
                                  label: Text(
                                    _isBroadcasting
                                        ? 'Stop Signal'
                                        : 'Send Signal',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _isBroadcasting
                                            ? Colors.orange
                                            : theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: Text(
                                              'End Session?',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            content: Text(
                                              'Students will no longer be able to mark their attendance once the session is ended.',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      false,
                                                    ),
                                                child: Text(
                                                  'Cancel',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      true,
                                                    ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: Text(
                                                  'End Session',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirm == true) {
                                      if (_isBroadcasting) {
                                        await _stopBroadcasting();
                                      }

                                      final success = await attendanceProvider
                                          .endAttendanceSession(
                                            widget.sessionId,
                                          );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Session ended successfully'
                                                  : 'Failed to end session: ${attendanceProvider.error}',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            backgroundColor:
                                                success
                                                    ? Colors.green
                                                    : Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            margin: const EdgeInsets.all(10),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: Text(
                                    'End Session',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (wifiProvider.status == wifi_provider.WifiConnectionStatus.error)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'WiFi error: ${wifiProvider.errorMessage}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Send a WiFi signal to allow students to mark attendance. ' +
                                        'Only students connected to the same WiFi network can mark attendance.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Attendance List',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${attendees.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                attendees.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Students Present',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 8),
                          Text(
                            _isBroadcasting
                                ? 'WiFi signal is active. Waiting for students on the same network to mark attendance.'
                                : 'Tap "Send Signal" to enable attendance marking for students on the same WiFi network',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: attendees.length,
                    itemBuilder: (context, index) {
                      final attendee = attendees[index];
                      return StudentAttendanceItem(attendee: attendee);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startBroadcasting() async {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // First check permissions
    final hasPermissions = await wifiProvider.checkAndRequestPermissions();
    if (!hasPermissions) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permissions required to access WiFi information',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Check and reset WiFi state before attempting to broadcast
    final wifiConnected = await wifiProvider.checkAndResetWifiState();
    if (!wifiConnected) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please connect to WiFi before sending a signal: ${wifiProvider.errorMessage}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    // Proceed with starting the attendance signal
    // First send the attendance signal through the attendance provider
    final signalSuccess = await attendanceProvider.sendAttendanceSignal(widget.sessionId);
    
    if (!signalSuccess) {
      // Close loading indicator if still showing
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to enable attendance signal: ${attendanceProvider.error}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    // Then broadcast the WiFi signal
    final success = await wifiProvider.broadcastAttendanceSignal(
      sessionId: widget.sessionId,
      courseId: widget.courseId,
      instructorId: authProvider.user?.uid ?? '',
      validityDuration: 30, // Set validity duration to 30 minutes
    );

    // Close loading indicator
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (success) {
      setState(() {
        _isBroadcasting = true;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WiFi attendance signal activated',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start WiFi broadcast: ${wifiProvider.errorMessage}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await attendanceProvider.stopAttendanceSignal(widget.sessionId);
    }
  }

  Future<void> _stopBroadcasting() async {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(context, listen: false);

    await wifiProvider.stopBroadcasting();

    final success = await attendanceProvider.stopAttendanceSignal(
      widget.sessionId,
    );

    if (success) {
      setState(() {
        _isBroadcasting = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WiFi attendance signal deactivated',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to stop attendance signal: ${attendanceProvider.error}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
