import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/face_recognition_provider.dart';
import '../../providers/wifi_provider.dart' as wifi_provider;
import '../../models/attendance_session.dart';
import '../../widgets/wifi_status_indicator.dart' as wifi_indicator;
import '../../widgets/upload_progress_indicator.dart';
import '../../utils/image_verification_manager.dart';

// This enum helps distinguish between different states of the face verification process
enum FaceVerificationState {
  noImage, // No profile image exists
  hasImage, // Profile image exists but face not verified
  faceVerified, // Face has been verified
}

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({Key? key}) : super(key: key);

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int _selectedTabIndex = 0;

  // Add scanning state and WiFi detection states
  bool _isScanning = false;
  Timer? _wifiScanTimer;
  Map<String, bool> _wifiSignalDetectedMap =
      {}; // Maps sessionId -> detected status

  // Add these variables to the class to store image and verification result globally
  static File? _capturedImageFile;
  static Map<String, dynamic>? _faceVerificationResult;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );

    // Add listener for tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });

    // Start periodic scanning for WiFi signals
    _startBackgroundWifiScanning();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _stopWifiScan();
    _capturedImageFile = null; // Clear the stored image file reference
    _faceVerificationResult = null;
    super.dispose();
  }

  // Build a WiFi status indicator widget
  Widget _buildWifiStatusIndicator(
    wifi_provider.WifiConnectionStatus status,
    String sessionId,
  ) {
    // Convert the provider's status to the widget's status enum
    final widgetStatus = _convertToWidgetStatus(status);

    return wifi_indicator.WifiStatusIndicator(
      status: widgetStatus,
      sessionId: sessionId,
      message: _getStatusMessage(status),
      onRetry: () => _retryWifiConnection(sessionId),
    );
  }

  // Convert provider status to widget status
  wifi_indicator.WifiConnectionStatus _convertToWidgetStatus(
    wifi_provider.WifiConnectionStatus status,
  ) {
    switch (status) {
      case wifi_provider.WifiConnectionStatus.searching:
        return wifi_indicator.WifiConnectionStatus.searching;
      case wifi_provider.WifiConnectionStatus.connected:
        return wifi_indicator.WifiConnectionStatus.connected;
      case wifi_provider.WifiConnectionStatus.signalDetected:
        return wifi_indicator.WifiConnectionStatus.connected;
      case wifi_provider.WifiConnectionStatus.error:
        return wifi_indicator.WifiConnectionStatus.error;
      case wifi_provider.WifiConnectionStatus.disconnected:
        return wifi_indicator.WifiConnectionStatus.notConnected;
      default:
        return wifi_indicator.WifiConnectionStatus.searching;
    }
  }

  // Get status message based on WiFi status
  String _getStatusMessage(wifi_provider.WifiConnectionStatus status) {
    switch (status) {
      case wifi_provider.WifiConnectionStatus.searching:
        return 'Searching for instructor WiFi signal...';
      case wifi_provider.WifiConnectionStatus.connected:
        return 'Connected to WiFi';
      case wifi_provider.WifiConnectionStatus.signalDetected:
        return 'Instructor WiFi signal detected!';
      case wifi_provider.WifiConnectionStatus.error:
        return 'Error connecting to WiFi';
      case wifi_provider.WifiConnectionStatus.disconnected:
        return 'Not connected to WiFi';
      default:
        return 'Checking WiFi status...';
    }
  }

  // Retry WiFi connection
  void _retryWifiConnection(String sessionId) {
    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(
      context,
      listen: false,
    );
    wifiProvider.stopScanning().then((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        wifiProvider.startScanningForSignals(
          sessionId: sessionId,
          scanDuration: 15,
        );
      });
    });
  }

  // Start background WiFi scanning
  void _startBackgroundWifiScanning() {
    // First check if we're already scanning
    if (_isScanning) return;

    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.user?.uid ?? '';

    // Request permissions first
    wifiProvider.checkAndRequestPermissions().then((hasPermissions) {
      if (hasPermissions) {
        setState(() {
          _isScanning = true;
        });

        // First, get active sessions from Firestore to get their session IDs
        _getActiveSessionIdsForStudent(studentId).then((sessionIds) {
          if (sessionIds.isNotEmpty) {
            print(
              "📱 Found ${sessionIds.length} active sessions for scanning: $sessionIds",
            );

            // If we have session IDs, fetch the teacher WiFi info for each session
            for (final sessionId in sessionIds) {
              FirebaseFirestore.instance
                  .collection('attendance_signals')
                  .doc(sessionId)
                  .get()
                  .then((signalDoc) {
                    if (signalDoc.exists && signalDoc.data() != null) {
                      final data = signalDoc.data()!;
                      final teacherWifiInfo = {
                        'networkName': data['wifiName'] ?? 'Unknown',
                        'networkId': data['networkId'] ?? '',
                        'bssid': data['bssid'] ?? '',
                      };

                      print("📱 Teacher WiFi details for matching:");
                      print("   - Network: ${teacherWifiInfo['networkName']}");
                      print("   - ID: ${teacherWifiInfo['networkId']}");
                      print("   - BSSID: ${teacherWifiInfo['bssid']}");

                      // Start scanning with the specific session ID
                      wifiProvider
                          .startScanningForSignals(
                            sessionId: sessionId,
                            scanDuration: 15,
                          )
                          .then((_) {
                            // Update UI if signal is detected
                            if (wifiProvider.status ==
                                wifi_provider
                                    .WifiConnectionStatus
                                    .signalDetected) {
                              if (mounted) {
                                setState(() {
                                  _wifiSignalDetectedMap[sessionId] = true;
                                });
                              }
                            }
                          });
                    }
                  });
            }
          }

          // Set up a timer to periodically check for signals
          _wifiScanTimer = Timer.periodic(Duration(seconds: 30), (_) {
            if (mounted) {
              _getActiveSessionIdsForStudent(studentId).then((sessionIds) {
                wifiProvider.stopScanning().then((_) {
                  // Small delay before starting next scan to avoid issues
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) {
                      if (sessionIds.isNotEmpty) {
                        for (final sessionId in sessionIds) {
                          wifiProvider
                              .startScanningForSignals(
                                sessionId: sessionId,
                                scanDuration: 15,
                              )
                              .then((_) {
                                // Update UI if signal is detected
                                if (wifiProvider.status ==
                                    wifi_provider
                                        .WifiConnectionStatus
                                        .signalDetected) {
                                  setState(() {
                                    _wifiSignalDetectedMap[sessionId] = true;
                                  });
                                }
                              });
                        }
                      } else {
                        wifiProvider
                            .startScanningForSignals(scanDuration: 15)
                            .then((_) {
                              // Handle the case when no specific session ID is provided
                              if (wifiProvider.status ==
                                      wifi_provider
                                          .WifiConnectionStatus
                                          .signalDetected &&
                                  wifiProvider.detectedSignal != null &&
                                  wifiProvider.detectedSignal!['sessionId'] !=
                                      null) {
                                setState(() {
                                  _wifiSignalDetectedMap[wifiProvider
                                          .detectedSignal!['sessionId']] =
                                      true;
                                });
                              }
                            });
                      }
                      // After each scan, update the signal detection state
                      _updateDetectedSignals(wifiProvider);
                    }
                  });
                });
              });
            }
          });
        });
      }
    });
  }

  // Helper method to get active session IDs for a student
  Future<List<String>> _getActiveSessionIdsForStudent(String studentId) async {
    try {
      // Get courses the student is enrolled in
      final coursesSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('enrolledStudents', arrayContains: studentId)
              .get();

      final courseIds = coursesSnapshot.docs.map((doc) => doc.id).toList();

      if (courseIds.isEmpty) {
        return [];
      }

      // Get active attendance sessions for these courses
      final sessionsSnapshot =
          await FirebaseFirestore.instance
              .collection('attendance_sessions')
              .where('courseId', whereIn: courseIds)
              .where('isActive', isEqualTo: true)
              .where('wifiSignalActive', isEqualTo: true)
              .get();

      return sessionsSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error getting active session IDs: $e");
      return [];
    }
  }

  // Update which sessions have detected WiFi signals
  void _updateDetectedSignals(wifi_provider.WifiProvider wifiProvider) {
    if (wifiProvider.status ==
            wifi_provider.WifiConnectionStatus.signalDetected &&
        wifiProvider.detectedSignal != null) {
      final detectedSessionId = wifiProvider.detectedSignal!['sessionId'];
      if (mounted) {
        setState(() {
          _wifiSignalDetectedMap[detectedSessionId] = true;
        });
      }
    }
  }

  // Stop WiFi scan when disposing
  void _stopWifiScan() {
    if (_isScanning) {
      final wifiProvider = Provider.of<wifi_provider.WifiProvider>(
        context,
        listen: false,
      );
      wifiProvider.stopScanning();
      _wifiScanTimer?.cancel();
      _isScanning = false;
    }
  }

  // Show face recognition dialog for attendance
  void _showFaceRecognitionDialog(
    BuildContext context,
    String sessionId,
    String studentId,
    String studentName,
  ) {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final faceRecognitionProvider = Provider.of<FaceRecognitionProvider>(
      context,
      listen: false,
    );

    // State variables
    bool isFaceVerified = false;
    // Map<String, dynamic>? faceVerificationResult;  // Not needed, using class variable instead

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  'Face Verification',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Face Recognition Icon/Status
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isFaceVerified
                                      ? Icons.check_circle
                                      : Icons.face,
                                  size: 32,
                                  color:
                                      isFaceVerified
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              isFaceVerified
                                  ? 'Face Verification Complete'
                                  : 'Face Recognition',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color:
                                    isFaceVerified
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            Text(
                              isFaceVerified
                                  ? 'Your identity has been verified'
                                  : 'Take a photo to verify your identity',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 16),

                            if (!isFaceVerified)
                              _buildFaceVerificationUI(
                                studentId: studentId,
                                faceRecognitionProvider:
                                    faceRecognitionProvider,
                                hasImage:
                                    true, // Assume the student has a profile image
                                isCheckingImage: false,
                                onImageUploadComplete: (
                                  verified,
                                  isProfileUpload,
                                ) {
                                  // Only set face as verified if this was a face verification
                                  // not just a profile image upload
                                  if (verified && !isProfileUpload) {
                                    setState(() {
                                      isFaceVerified = true;
                                    });
                                  }
                                },
                              ),

                            if (isFaceVerified)
                              Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green.shade700,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Your face has been successfully verified!',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final success = await attendanceProvider
                                          .markAttendanceWithFaceRecognition(
                                            sessionId: sessionId,
                                            studentId: studentId,
                                            studentName: studentName,
                                            imageFile:
                                                _StudentAttendancePageState
                                                    ._capturedImageFile ??
                                                File(''),
                                            verificationResult:
                                                _StudentAttendancePageState
                                                    ._faceVerificationResult,
                                            wifiVerified:
                                                false, // Not WiFi verified in this flow
                                          );

                                      if (context.mounted) {
                                        Navigator.of(dialogContext).pop();

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Attendance marked successfully'
                                                  : 'Failed to mark attendance: ${attendanceProvider.error}',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            backgroundColor:
                                                success
                                                    ? Colors.green
                                                    : Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Submit Attendance'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 48),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              minHeight: 60.0,
              maxHeight: 60.0,
              child: _buildTabBar(context),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            fillOverscroll: true,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveSessionsTab(context),
                _buildHistoryTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.05),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color:
                          _selectedTabIndex == 0
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    const Text('Active'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 20,
                      color:
                          _selectedTabIndex == 1
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    const Text('History'),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsTab(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final courseProvider = Provider.of<CourseProvider>(context);
    final studentId = authProvider.user?.uid ?? '';

    return StreamBuilder(
      stream: courseProvider.getStudentCourses(),
      builder: (context, courseSnapshot) {
        if (courseSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (courseSnapshot.hasError) {
          return _buildErrorState(
            'Error loading courses',
            courseSnapshot.error.toString(),
          );
        }

        final courses = _filterStudentCourses(
          courseSnapshot.data?.docs ?? [],
          studentId,
        );

        if (courses.isEmpty) {
          return _buildEmptyState(
            'No Enrolled Courses',
            'You are not enrolled in any courses yet',
            Icons.school_outlined,
          );
        }

        return FutureBuilder(
          future: _getActiveAttendanceSessions(
            courses.map((doc) => doc.id).toList(),
          ),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (sessionSnapshot.hasError) {
              return _buildErrorState(
                'Error loading sessions',
                sessionSnapshot.error.toString(),
              );
            }

            final sessions = sessionSnapshot.data ?? [];

            if (sessions.isEmpty) {
              return _buildEmptyState(
                'No Active Sessions',
                'There are no active attendance sessions right now',
                Icons.event_busy_outlined,
              );
            }

            return _buildSessionsList(
              context,
              sessions,
              courses,
              true, // Add isActiveTab argument
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final courseProvider = Provider.of<CourseProvider>(context);
    final studentId = authProvider.user?.uid ?? '';

    return StreamBuilder(
      stream: courseProvider.getStudentCourses(),
      builder: (context, courseSnapshot) {
        if (courseSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (courseSnapshot.hasError) {
          return _buildErrorState(
            'Error loading courses',
            courseSnapshot.error.toString(),
          );
        }

        final courses = _filterStudentCourses(
          courseSnapshot.data?.docs ?? [],
          studentId,
        );

        if (courses.isEmpty) {
          return _buildEmptyState(
            'No Enrolled Courses',
            'You are not enrolled in any courses yet',
            Icons.school_outlined,
          );
        }

        return FutureBuilder(
          future: _getAttendanceHistory(
            courses.map((doc) => doc.id).toList(),
            studentId,
          ),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (sessionSnapshot.hasError) {
              return _buildErrorState(
                'Error loading history',
                sessionSnapshot.error.toString(),
              );
            }

            final sessions = sessionSnapshot.data ?? [];

            if (sessions.isEmpty) {
              return _buildEmptyState(
                'No Attendance History',
                'You have not marked attendance for any sessions yet',
                Icons.history,
              );
            }

            return _buildSessionsList(
              context,
              sessions,
              courses,
              false, // Add isActiveTab argument
            );
          },
        );
      },
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<AttendanceSession> sessions,
    List<QueryDocumentSnapshot> courses,
    bool isActiveTab,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final courseDoc = courses.firstWhere(
          (course) => course.id == session.courseId,
          orElse: () => throw Exception('Course not found'),
        );
        final courseData = courseDoc.data() as Map<String, dynamic>;

        return _SessionCard(
          session: session,
          courseName: courseData['courseName'] ?? 'Unknown Course',
          courseCode: courseData['courseCode'] ?? '',
          isActiveTab: isActiveTab,
          wifiSignalDetected:
              _wifiSignalDetectedMap[session.id] ??
              false, // Pass WiFi signal detection state
        );
      },
    );
  }

  void _showWifiAttendanceDialog(
    BuildContext context,
    String sessionId,
    String studentId,
    String studentName,
    String courseId,
  ) {
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final faceRecognitionProvider = Provider.of<FaceRecognitionProvider>(
      context,
      listen: false,
    );
    final wifiProvider = Provider.of<wifi_provider.WifiProvider>(
      context,
      listen: false,
    );

    // State variables
    bool isScanning = false;
    bool wifiDetected = false;
    bool isFaceVerified = false;
    wifi_provider.WifiConnectionStatus wifiStatus =
        wifi_provider.WifiConnectionStatus.searching;
    String statusMessage = 'Searching for instructor signal...';
    Map<String, dynamic>? faceVerificationResult;
    Timer? statusCheckTimer;

    // Cache for checkStudentImageExists result
    bool? hasImageCache;

    // Track the current verification state
    FaceVerificationState verificationState = FaceVerificationState.noImage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setState) {
              // Check if student image exists when dialog opens
              if (hasImageCache == null) {
                // Initial image check
                faceRecognitionProvider.checkStudentImageExists(studentId).then(
                  (exists) {
                    if (mounted) {
                      setState(() {
                        hasImageCache = exists;
                      });
                    }
                  },
                );
              }

              // Start WiFi scanning when dialog opens
              if (!isScanning) {
                setState(() {
                  isScanning = true;
                  wifiStatus = wifi_provider.WifiConnectionStatus.searching;
                  statusMessage = 'Searching for instructor signal...';
                });

                // Request permissions and start scanning
                wifiProvider.checkAndRequestPermissions().then((
                  hasPermissions,
                ) {
                  if (hasPermissions) {
                    wifiProvider.startScanningForSignals(sessionId: sessionId).then((
                      _,
                    ) {
                      // Check for error status after scanning starts
                      if (wifiProvider.status ==
                              wifi_provider.WifiConnectionStatus.error &&
                          context.mounted) {
                        setState(() {
                          wifiStatus = wifi_provider.WifiConnectionStatus.error;
                          statusMessage =
                              'Failed to start WiFi scanning: ${wifiProvider.errorMessage}';
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to start WiFi scanning: ${wifiProvider.errorMessage}',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        // Log that scanning started
                        print(
                          '🔍 Started scanning for WiFi signal with session ID: $sessionId',
                        );

                        // Successfully started scanning, set up periodic checks
                        statusCheckTimer = Timer.periodic(Duration(seconds: 2), (
                          timer,
                        ) async {
                          if (!context.mounted) {
                            timer.cancel();
                            return;
                          }

                          // Check for signal detection
                          final signal = wifiProvider.detectedSignal;
                          final status = wifiProvider.status;

                          // Log current scanning status
                          print(
                            '🔄 WiFi Status: $status | Signal detected: ${signal != null}',
                          );

                          // Check for WiFi signal detection directly from the provider
                          bool foundSignal = false;
                          if (status ==
                              wifi_provider
                                  .WifiConnectionStatus
                                  .signalDetected) {
                            foundSignal = true;

                            // Extract session details from the signal if available
                            if (signal != null &&
                                signal.containsKey('sessionId')) {
                              final detectedSessionId = signal['sessionId'];
                              print(
                                '✅ Found WiFi signal for session: $detectedSessionId',
                              );
                            }
                          }

                          // If signal detected, update UI and mark attendance if needed
                          if (foundSignal) {
                            setState(() {
                              _wifiSignalDetectedMap[sessionId] = true;
                            });

                            // Cancel timer as we found the signal
                            timer.cancel();
                          }

                          // Check Firestore for the latest attendance signal as a fallback
                          try {
                            final signalQuery =
                                await FirebaseFirestore.instance
                                    .collection('attendance_signals')
                                    .where('sessionId', isEqualTo: sessionId)
                                    .where(
                                      'validUntil',
                                      isGreaterThan:
                                          DateTime.now().millisecondsSinceEpoch,
                                    )
                                    .get();

                            // Also check the session document for bleSignalActive flag
                            final sessionDoc =
                                await FirebaseFirestore.instance
                                    .collection('attendance_sessions')
                                    .doc(sessionId)
                                    .get();

                            final hasValidSignal = signalQuery.docs.isNotEmpty;
                            final sessionWifiEnabled =
                                sessionDoc.exists &&
                                sessionDoc.data() != null &&
                                (sessionDoc.data() as Map<String, dynamic>)
                                    .containsKey('wifiSignalActive') &&
                                sessionDoc.data()!['wifiSignalActive'] == true;

                            print(
                              '📡 Firestore signal check: ${hasValidSignal ? "Signal active" : "No signal"} | Session WiFi enabled: $sessionWifiEnabled',
                            );

                            // Check if signal has been detected previously
                            final hasDetectedSignal = await wifiProvider
                                .hasDetectedSessionSignal(sessionId);

                            if (context.mounted) {
                              setState(() {
                                // Accept a Firestore signal as a valid detection if direct WiFi detection fails
                                // This is crucial to make the system work reliably
                                if ((status ==
                                            wifi_provider
                                                .WifiConnectionStatus
                                                .signalDetected &&
                                        signal != null &&
                                        signal['sessionId'] == sessionId) ||
                                    hasDetectedSignal ||
                                    hasValidSignal) {
                                  setState(() {
                                    wifiStatus =
                                        wifi_provider
                                            .WifiConnectionStatus
                                            .connected;
                                    wifiDetected =
                                        true; // Set wifiDetected to true when signal is detected
                                    statusMessage =
                                        'Connected to instructor WiFi signal! You can now verify your identity.';
                                  });

                                  // Record the successful detection in our local storage
                                  // to remember it for future reference
                                  if (!_wifiSignalDetectedMap.containsKey(
                                    sessionId,
                                  )) {
                                    _wifiSignalDetectedMap[sessionId] = true;
                                  }

                                  // Also record the detection in WifiProvider's storage
                                  if (hasValidSignal &&
                                      signalQuery.docs.isNotEmpty) {
                                    final signalData =
                                        signalQuery.docs.first.data();
                                    wifiProvider.recordSignalDetection(
                                      signalData,
                                    );
                                    wifiProvider.addDetectedSessionId(
                                      sessionId,
                                    );
                                  }
                                } else if (!hasValidSignal) {
                                  setState(() {
                                    wifiStatus =
                                        wifi_provider
                                            .WifiConnectionStatus
                                            .error;
                                    statusMessage =
                                        'No active WiFi signal detected. Ask instructor to enable WiFi.';
                                  });
                                } else {
                                  setState(() {
                                    wifiStatus =
                                        wifi_provider
                                            .WifiConnectionStatus
                                            .disconnected;
                                    statusMessage =
                                        'Signal is active but not detected. Move closer to instructor.';
                                  });
                                }
                              });
                            }
                          } catch (e) {
                            print('❌ Error checking Firestore signal: $e');
                            // Don't update UI state here, just log the error
                          }
                        });
                      }
                    });
                  } else if (context.mounted) {
                    setState(() {
                      wifiStatus = wifi_provider.WifiConnectionStatus.error;
                      statusMessage =
                          'WiFi permissions are required for attendance';
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'WiFi permissions required for attendance',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                });
              }

              return WillPopScope(
                onWillPop: () async {
                  // Clean up timer when dialog is closed
                  statusCheckTimer?.cancel();
                  wifiProvider.stopScanning();
                  return true;
                },
                child: AlertDialog(
                  title: Text(
                    'Attendance Verification',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Step 1: WiFi Verification with clearer indication of connection status
                        wifi_indicator.WifiStatusIndicator(
                          status: _convertToWidgetStatus(wifiStatus),
                          sessionId: sessionId,
                          message: statusMessage,
                          onRetry: () {
                            setState(() {
                              wifiStatus =
                                  wifi_provider.WifiConnectionStatus.searching;
                              wifiDetected = false;
                              statusMessage =
                                  'Searching for instructor signal...';
                            });

                            // Force a new signal check
                            wifiProvider.stopScanning().then((_) {
                              Future.delayed(Duration(milliseconds: 500), () {
                                if (context.mounted) {
                                  wifiProvider.startScanningForSignals(
                                    sessionId: sessionId,
                                  );
                                }
                              });
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // Divider with text
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Step 2',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Step 2: Face Recognition (only enabled after WiFi verification)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                wifiDetected
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  wifiDetected
                                      ? Colors.blue.shade200
                                      : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Face Recognition Icon/Status
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color:
                                      wifiDetected
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isFaceVerified
                                        ? Icons.check_circle
                                        : Icons.face,
                                    size: 32,
                                    color:
                                        isFaceVerified
                                            ? Colors.green.shade700
                                            : (wifiDetected
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade500),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                isFaceVerified
                                    ? 'Face Verification Complete'
                                    : 'Face Recognition',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isFaceVerified
                                          ? Colors.green.shade700
                                          : (wifiDetected
                                              ? Colors.blue.shade700
                                              : Colors.grey.shade600),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 8),

                              Text(
                                wifiDetected
                                    ? (isFaceVerified
                                        ? 'Your identity has been verified'
                                        : 'Take a photo to verify your identity')
                                    : 'Complete signal detection first',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color:
                                      wifiDetected
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

                              if (wifiDetected && !isFaceVerified)
                                hasImageCache == null
                                    ? UploadProgressIndicator(
                                      provider: faceRecognitionProvider,
                                    )
                                    : _buildFaceVerificationUI(
                                      studentId: studentId,
                                      faceRecognitionProvider:
                                          faceRecognitionProvider,
                                      hasImage: hasImageCache!,
                                      isCheckingImage: false,
                                      onImageUploadComplete: (
                                        verified,
                                        isProfileUpload,
                                      ) {
                                        // Only set face as verified if this was a face verification
                                        // not just a profile image upload
                                        if (verified && !isProfileUpload) {
                                          setState(() {
                                            isFaceVerified = true;
                                          });
                                        } else if (verified &&
                                            isProfileUpload) {
                                          // If it was just a profile upload, refresh the UI
                                          setState(() {});
                                        }
                                      },
                                    ),

                              if (isFaceVerified)
                                Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green.shade700,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Your face has been successfully verified!',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        // Get the cached verification result and image file
                                        final cachedVerificationResult =
                                            _StudentAttendancePageState
                                                ._faceVerificationResult;
                                        final cachedImageFile =
                                            _StudentAttendancePageState
                                                ._capturedImageFile;

                                        print(
                                          'Using cached verification result: $cachedVerificationResult',
                                        );
                                        print(
                                          'Using cached image file: ${cachedImageFile?.path}',
                                        );

                                        if (cachedVerificationResult == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Face verification data not found. Please try again.',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }

                                        final success = await attendanceProvider
                                            .markAttendanceWithFaceRecognition(
                                              sessionId: sessionId,
                                              studentId: studentId,
                                              studentName: studentName,
                                              imageFile:
                                                  cachedImageFile ??
                                                  File(
                                                    '',
                                                  ), // Use cached image file if available
                                              verificationResult:
                                                  cachedVerificationResult,
                                              wifiVerified:
                                                  true, // Mark as WiFi verified
                                            );

                                        if (context.mounted) {
                                          // Stop scanning and clean up timer
                                          statusCheckTimer?.cancel();
                                          final wifiProvider = Provider.of<
                                            wifi_provider.WifiProvider
                                          >(context, listen: false);
                                          wifiProvider.stopScanning();
                                          Navigator.of(dialogContext).pop();

                                          // Refresh UI to update attendance status
                                          Future.delayed(
                                            Duration(milliseconds: 500),
                                            () {
                                              if (mounted) {
                                                setState(() {
                                                  // Trigger a UI rebuild
                                                });
                                              }
                                            },
                                          );

                                          // Get the attendance status from Firestore to show appropriate message
                                          FirebaseFirestore.instance
                                              .collection('attendance_sessions')
                                              .doc(sessionId)
                                              .get()
                                              .then((doc) {
                                                if (doc.exists &&
                                                    context.mounted) {
                                                  final data =
                                                      doc.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  final attendees = List<
                                                    Map<String, dynamic>
                                                  >.from(
                                                    data['attendees'] ?? [],
                                                  );
                                                  final myAttendance = attendees
                                                      .firstWhere(
                                                        (a) =>
                                                            a['studentId'] ==
                                                            studentId,
                                                        orElse:
                                                            () =>
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{},
                                                      );

                                                  final status =
                                                      myAttendance['status'] ??
                                                      'unknown';
                                                  String message =
                                                      'Attendance marked successfully!';
                                                  Color bgColor = Colors.green;

                                                  if (status == 'late') {
                                                    message =
                                                        'Attendance marked as LATE - you arrived after the threshold time.';
                                                    bgColor = Colors.orange;
                                                  } else if (status ==
                                                      'absent') {
                                                    message =
                                                        'Attendance marked as ABSENT - you arrived after the cutoff time.';
                                                    bgColor = Colors.red;
                                                  } else if (status ==
                                                      'present') {
                                                    message =
                                                        'Attendance marked as PRESENT - you arrived on time!';
                                                    bgColor = Colors.green;
                                                  }

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        message,
                                                        style:
                                                            GoogleFonts.poppins(),
                                                      ),
                                                      backgroundColor: bgColor,
                                                      behavior:
                                                          SnackBarBehavior
                                                              .floating,
                                                      duration: Duration(
                                                        seconds: 5,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  // Fall back to basic message if can't get status
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        success
                                                            ? 'Attendance marked successfully!'
                                                            : 'Failed to mark attendance: ${attendanceProvider.error}',
                                                        style:
                                                            GoogleFonts.poppins(),
                                                      ),
                                                      backgroundColor:
                                                          success
                                                              ? Colors.green
                                                              : Colors.red,
                                                      behavior:
                                                          SnackBarBehavior
                                                              .floating,
                                                    ),
                                                  );
                                                }
                                              });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Submit Attendance'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(double.infinity, 48),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Stop scanning, clean up timer and close dialog
                        statusCheckTimer?.cancel();
                        wifiProvider.stopScanning();
                        Navigator.pop(dialogContext);
                      },
                      child: Text('Cancel', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Helper method to build face verification section with cached result
  Widget _buildFaceVerificationUI({
    required String studentId,
    required FaceRecognitionProvider faceRecognitionProvider,
    required bool hasImage,
    required bool isCheckingImage,
    required Function(bool, bool) onImageUploadComplete,
  }) {
    if (isCheckingImage) {
      return UploadProgressIndicator(provider: faceRecognitionProvider);
    }

    if (!hasImage) {
      return Column(
        children: [
          Icon(Icons.error_outline, size: 36, color: Colors.orange[700]),
          const SizedBox(height: 12),
          Text(
            'No profile image found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload your profile image to complete verification',
            style: GoogleFonts.poppins(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      isCheckingImage = true;
                    });

                    try {
                      final result = await faceRecognitionProvider
                          .uploadStudentImage(ImageSource.camera);

                      if (result != null && mounted) {
                        // Clear any existing verification result since this is just a profile upload
                        _StudentAttendancePageState._faceVerificationResult =
                            null;

                        // Pass true for isProfileUpload since this is just uploading a profile image
                        onImageUploadComplete(true, true);

                        // Don't dismiss the dialog after profile image upload
                        // Instead, show a message within the dialog that the profile image was uploaded

                        // Show a message to the user that they need to verify their face
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profile image uploaded. Now take a photo to verify your identity.',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isCheckingImage = false;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      isCheckingImage = true;
                    });

                    try {
                      final result = await faceRecognitionProvider
                          .uploadStudentImage(ImageSource.gallery);

                      if (result != null && mounted) {
                        // Clear any existing verification result since this is just a profile upload
                        _StudentAttendancePageState._faceVerificationResult =
                            null;

                        // Pass true for isProfileUpload since this is just uploading a profile image
                        onImageUploadComplete(true, true);

                        // Don't dismiss the dialog after profile image upload
                        // Instead, show a message within the dialog that the profile image was uploaded

                        // Show a message to the user that they need to verify their face
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profile image uploaded. Now take a photo to verify your identity.',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isCheckingImage = false;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Builder(
      builder: (context) {
        // Local state for the verification button
        bool isLocalVerifying = false;

        return StatefulBuilder(
          builder: (context, buttonSetState) {
            return ElevatedButton.icon(
              onPressed:
                  isLocalVerifying
                      ? null
                      : () async {
                        // Set loading state
                        buttonSetState(() {
                          isLocalVerifying = true;
                        });

                        try {
                          // Get image from camera
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );

                          if (pickedFile != null && context.mounted) {
                            // Show a loading dialog with indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Verifying face...',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                            final imageFile = File(pickedFile.path);

                            // Verify face
                            final result = await faceRecognitionProvider
                                .compareFaces(
                                  studentId: studentId,
                                  imageFile: imageFile,
                                ); // Close the loading dialog
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }

                            // Debug: print the result to see what's coming back from API
                            print('Face verification result: $result');

                            if (result != null) {
                              print('Match value: ${result['match']}');
                              print('Confidence: ${result['confidence']}');

                              if (result['match'] == true && context.mounted) {
                                // Store the verification result and image file using the utility manager
                                ImageVerificationManager.saveVerificationData(
                                  imageFile,
                                  result,
                                );

                                // Update the class-level variables
                                _StudentAttendancePageState
                                        ._faceVerificationResult =
                                    ImageVerificationManager.getCachedVerificationResult();
                                _StudentAttendancePageState._capturedImageFile =
                                    ImageVerificationManager.getCachedImageFile();

                                print(
                                  'Saved verification image: ${_StudentAttendancePageState._capturedImageFile?.path}',
                                );

                                // Don't close the dialog after successful verification
                                // Instead, keep it open to show the Submit Attendance button

                                // Use the callback to update parent state
                                // Pass false for isProfileUpload since this is actual face verification
                                onImageUploadComplete(true, false);

                                // Now call attendanceProvider to mark attendance with the WiFi verification status
                                // Get the attendanceProvider
                                final attendanceProvider =
                                    Provider.of<AttendanceProvider>(
                                      context,
                                      listen: false,
                                    );

                                // Get the authProvider to get student info
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );

                                final studentId = authProvider.user?.uid ?? '';
                                final studentName =
                                    authProvider.user?.displayName ?? '';

                                // Call markAttendanceWithFaceRecognition with the verified result
                                if (studentId.isNotEmpty) {
                                  // The sessionId is passed from the calling function, so you need to get it from there
                                  // For this implementation, get the active session ID for the student
                                  try {
                                    // Get the active WiFi sessions for this student
                                    final sessionIds =
                                        await _getActiveSessionIdsForStudent(
                                          studentId,
                                        );
                                    if (sessionIds.isNotEmpty) {
                                      // Mark attendance for each active session
                                      for (final sessionId in sessionIds) {
                                        // Check if WiFi signal was detected for this session
                                        final wifiVerified =
                                            _wifiSignalDetectedMap[sessionId] ??
                                            false;

                                        final success = await attendanceProvider
                                            .markAttendanceWithFaceRecognition(
                                              sessionId: sessionId,
                                              studentId: studentId,
                                              studentName: studentName,
                                              imageFile: imageFile,
                                              verificationResult: result,
                                              wifiVerified: wifiVerified,
                                            );

                                        if (success && context.mounted) {
                                          // Get the attendance status from Firestore to show appropriate message
                                          final sessionDoc =
                                              await FirebaseFirestore.instance
                                                  .collection(
                                                    'attendance_sessions',
                                                  )
                                                  .doc(sessionId)
                                                  .get();

                                          if (sessionDoc.exists &&
                                              context.mounted) {
                                            final data =
                                                sessionDoc.data()
                                                    as Map<String, dynamic>;
                                            final attendees =
                                                List<Map<String, dynamic>>.from(
                                                  data['attendees'] ?? [],
                                                );
                                            final myAttendance = attendees
                                                .firstWhere(
                                                  (a) =>
                                                      a['studentId'] ==
                                                      studentId,
                                                  orElse:
                                                      () => <String, dynamic>{},
                                                );

                                            final status =
                                                myAttendance['status'] ??
                                                'unknown';
                                            String message =
                                                'Attendance marked successfully!';
                                            Color bgColor = Colors.green;

                                            if (status == 'late') {
                                              message =
                                                  'Attendance marked as LATE - you arrived after the threshold time.';
                                              bgColor = Colors.orange;
                                            } else if (status == 'absent') {
                                              message =
                                                  'Attendance marked as ABSENT - you arrived after the cutoff time.';
                                              bgColor = Colors.red;
                                            } else if (status == 'present') {
                                              message =
                                                  'Attendance marked as PRESENT - you arrived on time!';
                                              bgColor = Colors.green;
                                            }

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  message,
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: bgColor,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: Duration(seconds: 5),
                                              ),
                                            );
                                          } else {
                                            // Fall back to basic message if can't get status
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Attendance marked successfully!',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    print('Error marking attendance: $e');
                                  }
                                }
                              } else if (context.mounted) {
                                // Close dialog before showing SnackBar for error too
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Face verification failed. Please try again. Confidence: ${result['confidence']}%',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else if (context.mounted) {
                              // Close dialog before showing SnackBar for null response too
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Face verification failed. Null response received.',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Close the loading dialog if it's still open
                          if (context.mounted &&
                              Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }

                          if (context.mounted) {
                            // Show a more detailed error message
                            String errorMessage = 'Error: ';
                            if (e.toString().contains('SocketException') ||
                                e.toString().contains('Failed host lookup')) {
                              errorMessage +=
                                  'Cannot connect to face recognition server. Check your internet connection.';
                            } else if (e.toString().contains('timed out')) {
                              errorMessage +=
                                  'Connection to server timed out. Please try again.';
                            } else {
                              errorMessage += e.toString();
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMessage,
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 5),
                              ),
                            );

                            // Log the error for debugging
                            print('Face verification error: $e');
                          }
                        } finally {
                          // Reset loading state if still mounted
                          if (context.mounted) {
                            buttonSetState(() {
                              isLocalVerifying = false;
                            });
                          }
                        }
                      },
              icon:
                  isLocalVerifying
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.camera_alt),
              label: Text(
                isLocalVerifying ? 'Verifying...' : 'Take Photo to Verify',
                style: GoogleFonts.poppins(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
              ),
            );
          },
        );
      },
    );
  }

  // Loading state UI
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Empty state UI
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Error state UI
  Widget _buildErrorState(String title, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                setState(() {}); // Retry by triggering a rebuild
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter student courses
  List<QueryDocumentSnapshot> _filterStudentCourses(
    List<QueryDocumentSnapshot> docs,
    String studentId,
  ) {
    return docs.where((doc) {
      final courseData = doc.data() as Map<String, dynamic>;
      final students = List<Map<String, dynamic>>.from(
        (courseData['students'] ?? []).map(
          (student) => student is Map<String, dynamic> ? student : {},
        ),
      );
      return students.any((student) => student['studentId'] == studentId);
    }).toList();
  }

  // Get active attendance sessions
  Future<List<AttendanceSession>> _getActiveAttendanceSessions(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) {
      return [];
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final studentId =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';

    // Get all active attendance sessions for the student's courses
    final querySnapshot =
        await firestore
            .collection('attendance_sessions')
            .where('courseId', whereIn: courseIds)
            .where('isActive', isEqualTo: true)
            .get();

    final sessions =
        querySnapshot.docs
            .map((doc) => AttendanceSession.fromFirestore(doc))
            .where(
              (session) =>
                  session.endTime.isAfter(now) &&
                  // Exclude sessions where the student has already marked attendance
                  !session.attendees.any(
                    (attendee) => attendee['studentId'] == studentId,
                  ),
            )
            .toList();

    // Sort by start time (most recent first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

    return sessions;
  }

  // Get attendance history
  Future<List<AttendanceSession>> _getAttendanceHistory(
    List<String> courseIds,
    String studentId,
  ) async {
    if (courseIds.isEmpty) {
      return [];
    }

    final firestore = FirebaseFirestore.instance;

    // Get all attendance sessions for the student's courses
    final querySnapshot =
        await firestore
            .collection('attendance_sessions')
            .where('courseId', whereIn: courseIds)
            .get();

    // Filter sessions where the student has marked attendance (including active sessions)
    // or the session is closed
    final sessions =
        querySnapshot.docs
            .map((doc) => AttendanceSession.fromFirestore(doc))
            .where((session) {
              final hasMarkedAttendance = session.attendees.any(
                (attendee) => attendee['studentId'] == studentId,
              );
              // Include both closed sessions AND active sessions where attendance is marked
              return hasMarkedAttendance || !session.isActive;
            })
            .toList();

    // Sort by start time (most recent first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

    return sessions;
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceSession session;
  final String courseName;
  final String courseCode;
  final bool isActiveTab;
  final bool wifiSignalDetected; // Add WiFi signal detection state

  const _SessionCard({
    required this.session,
    required this.courseName,
    required this.courseCode,
    required this.isActiveTab,
    required this.wifiSignalDetected, // Add WiFi signal detection state
  });

  @override
  Widget build(BuildContext context) {
    // Check if WiFi is available in the session
    final wifiEnabled = session.signalTime != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        // Only allow tapping if the session is active and we're on the active tab
        onTap:
            isActiveTab
                ? () async {
                  // Check if WiFi is enabled for this session
                  if (!wifiEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'WiFi attendance is not enabled for this session',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    // Get the student's current WiFi information
                    final wifiProvider =
                        Provider.of<wifi_provider.WifiProvider>(
                          context,
                          listen: false,
                        );
                    final studentWifiName =
                        await wifiProvider.getCurrentWifiName();

                    if (studentWifiName == null) {
                      // Close loading indicator
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot mark attendance: WiFi is not enabled on your device',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    // Check if the teacher's WiFi signal is active in Firestore
                    final signalDoc =
                        await FirebaseFirestore.instance
                            .collection('attendance_signals')
                            .doc(session.id)
                            .get();

                    // Close loading indicator
                    Navigator.of(context).pop();

                    if (!signalDoc.exists || signalDoc.data() == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot mark attendance: The instructor has not activated the WiFi signal yet',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final signalData = signalDoc.data()!;
                    final teacherWifiName = signalData['wifiName'];
                    final wifiSignalActive =
                        signalData['wifiSignalActive'] == true;

                    print(
                      '🔍 Student WiFi: $studentWifiName, Teacher WiFi: $teacherWifiName, Signal Active: $wifiSignalActive',
                    );

                    if (!wifiSignalActive) {
                      // Show error: WiFi signal not active
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot mark attendance: The instructor has not activated the WiFi signal yet',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (studentWifiName != teacherWifiName) {
                      // Show error: Not on the same WiFi network
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot mark attendance: You are not connected to the same WiFi network as your instructor (${teacherWifiName})',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      // All conditions met, proceed with attendance marking
                      _handleAttendanceMarking(context);
                    }
                  } catch (e) {
                    // Close loading indicator if still showing
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }

                    print('❌ Error checking WiFi networks: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error checking WiFi networks: $e',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
                : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(context),
              const SizedBox(height: 16),
              _buildCourseInfo(context),
              const SizedBox(height: 12),
              _buildTimeInfo(context),

              // Show BLE indicator if enabled
              if (session.signalTime != null && isActiveTab) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth_searching,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This session requires WIFI proximity verification',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!isActiveTab) ...[
                const SizedBox(height: 12),
                _buildAttendanceStatus(context),
              ],
              if (isActiveTab) ...[
                const SizedBox(height: 16),
                _buildActionButton(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleAttendanceMarking(BuildContext context) {
    final studentId =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    final studentName =
        Provider.of<AuthProvider>(context, listen: false).user?.displayName ??
        '';
    final isWifiEnabled = session.signalTime != null;

    // Get a reference to the parent state to access dialog methods
    final parentState =
        context.findAncestorStateOfType<_StudentAttendancePageState>();
    if (parentState == null) {
      // Fallback if parent state is not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to mark attendance. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (isWifiEnabled) {
      // First check if there's an active WiFi signal for this session in Firestore
      FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(session.id)
          .get()
          .then((doc) {
            final data = doc.data();
            final wifiSignalActive = data?['wifiSignalActive'] ?? false;

            if (!wifiSignalActive) {
              // Show error: WiFi signal not active
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot mark attendance: The instructor has not activated the WiFi signal yet.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              // Show WiFi attendance dialog with face recognition
              parentState._showWifiAttendanceDialog(
                context,
                session.id,
                studentId,
                studentName,
                session.courseId,
              );
            }
          });
    } else {
      // Use the existing face recognition dialog without WiFi
      parentState._showFaceRecognitionDialog(
        context,
        session.id,
        studentId,
        studentName,
      );
    }
  }

  Widget _buildAttendanceStatus(BuildContext context) {
    final studentId = Provider.of<AuthProvider>(context).user?.uid ?? '';
    final attendeeRecord = session.attendees.firstWhere(
      (attendee) => attendee['studentId'] == studentId,
      orElse: () => <String, dynamic>{},
    );
    
    final bool wasPresent = attendeeRecord.isNotEmpty;
    String status = 'Absent';
    Color statusColor = Colors.red[700]!;
    Color bgColor = Colors.red[50]!;
    Color borderColor = Colors.red[100]!;
    IconData statusIcon = Icons.cancel_outlined;
    
    if (wasPresent) {
      // Get the actual status from Firebase
      status = attendeeRecord['status'] ?? 'present';
      
      // Set colors and icons based on status
      if (status == 'late') {
        statusColor = Colors.orange[700]!;
        bgColor = Colors.orange[50]!;
        borderColor = Colors.orange[100]!;
        statusIcon = Icons.watch_later_outlined;
      } else if (status == 'absent') {
        statusColor = Colors.red[700]!;
        bgColor = Colors.red[50]!;
        borderColor = Colors.red[100]!;
        statusIcon = Icons.cancel_outlined;
      } else { // present
        statusColor = Colors.green[700]!;
        bgColor = Colors.green[50]!;
        borderColor = Colors.green[100]!;
        statusIcon = Icons.check_circle_outline;
      }
    }
    
    // Capitalize the first letter of the status
    final displayStatus = status.substring(0, 1).toUpperCase() + status.substring(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            statusIcon,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            displayStatus,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
          if (wasPresent) ...[
            const SizedBox(width: 16),
            Icon(
              _getVerificationIcon(
                session.attendees.firstWhere(
                      (attendee) => attendee['studentId'] == studentId,
                    )['verificationMethod'] ??
                    'Manual',
              ),
              size: 16,
              color: Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              session.attendees.firstWhere(
                    (attendee) => attendee['studentId'] == studentId,
                  )['verificationMethod'] ??
                  'Manual',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getVerificationIcon(String method) {
    switch (method) {
      case 'Face Recognition':
        return Icons.face;
      default:
        return Icons.check_circle;
    }
  }

  Widget _buildStatusHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: session.isActive ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                session.isActive
                    ? Icons.radio_button_on
                    : Icons.radio_button_off,
                size: 14,
                color: session.isActive ? Colors.green[700] : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                session.isActive ? 'ACTIVE' : 'CLOSED',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      session.isActive ? Colors.green[700] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            courseCode,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          courseName,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          session.title,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _TimeInfoItem(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('MMM d, yyyy').format(session.startTime),
              ),
            ),
            VerticalDivider(width: 32, thickness: 1, color: Colors.grey[200]),
            Expanded(
              child: _TimeInfoItem(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value:
                    '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final studentId = Provider.of<AuthProvider>(context).user?.uid ?? '';
    final hasMarkedAttendance = session.attendees.any(
      (attendee) => attendee['studentId'] == studentId,
    );

    if (!session.isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Session Closed',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (hasMarkedAttendance) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[100]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: Colors.green[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Attendance Marked',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    }

    // Use FutureBuilder to check if the WiFi signal is active in Firestore
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('attendance_signals')
              .doc(session.id)
              .get(),
      builder: (context, snapshot) {
        // Default to false unless we can confirm the signal is active
        bool signalActive = false;

        // Check if we have valid data and the signal is active
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          signalActive = data != null && data['wifiSignalActive'] == true;
        }

        // Check all conditions for enabling the button
        final bool canMarkAttendance =
            wifiSignalDetected && session.signalTime != null && signalActive;

        // Debug print to check values
        print(
          '📱 Button state: wifiSignalDetected=$wifiSignalDetected, signalTime=${session.signalTime}, signalActive=$signalActive, canMarkAttendance=$canMarkAttendance',
        );

        return ElevatedButton(
          onPressed:
              canMarkAttendance
                  ? () => _handleAttendanceMarking(context)
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canMarkAttendance
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
            foregroundColor:
                canMarkAttendance ? Colors.white : Colors.grey.shade700,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                session.signalTime != null
                    ? Icons.wifi_find
                    : Icons.face_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                session.signalTime != null
                    ? (canMarkAttendance
                        ? 'Mark Attendance (WiFi Enabled)'
                        : 'Waiting for Teacher Signal...')
                    : 'Mark Attendance',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[900],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
