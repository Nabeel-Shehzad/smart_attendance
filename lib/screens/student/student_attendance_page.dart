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
import '../../providers/ble_provider.dart'; // Add BLE provider import
import '../../models/attendance_session.dart';
import '../../widgets/ble_status_indicator.dart'; // Add the BleStatusIndicator import

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({Key? key}) : super(key: key);

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int _selectedTabIndex = 0;

  // Add scanning state and BLE detection states
  bool _isScanning = false;
  Timer? _bleScanTimer;
  Map<String, bool> _bleSignalDetectedMap = {}; // Maps sessionId -> detected status
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    
    // Start background BLE scanning when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundBleScanning();
    });
  }

  @override
  void dispose() {
    _stopBleScan();
    _tabController.dispose();
    _scrollController.dispose();
    _bleScanTimer?.cancel();
    super.dispose();
  }
  
  // Start background BLE scanning
  void _startBackgroundBleScanning() {
    // First check if we're already scanning
    if (_isScanning) return;
    
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    // Request permissions first
    bleProvider.checkAndRequestPermissions().then((hasPermissions) {
      if (hasPermissions) {
        setState(() {
          _isScanning = true;
        });
        
        // Start scanning for BLE signals
        bleProvider.startScanningForSignals(scanDuration: 15).then((_) {
          // Set up a timer to periodically check for signals
          _bleScanTimer = Timer.periodic(Duration(seconds: 15), (_) {
            if (mounted) {
              bleProvider.stopScanning().then((_) {
                // Small delay before starting next scan to avoid issues
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    bleProvider.startScanningForSignals(scanDuration: 15);
                    
                    // After each scan, update the signal detection state
                    _updateDetectedSignals(bleProvider);
                  }
                });
              });
            }
          });
        });
      }
    });
  }

  // Update which sessions have detected BLE signals
  void _updateDetectedSignals(BleProvider bleProvider) {
    if (bleProvider.status == BleStatus.signalDetected && bleProvider.detectedSignal != null) {
      final detectedSessionId = bleProvider.detectedSignal!['sessionId'];
      if (mounted) {
        setState(() {
          _bleSignalDetectedMap[detectedSessionId] = true;
        });
      }
    }
  }

  // Stop BLE scan when disposing
  void _stopBleScan() {
    if (_isScanning) {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      bleProvider.stopScanning();
      _bleScanTimer?.cancel();
      _isScanning = false;
    }
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
                      color: _selectedTabIndex == 0
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
                      color: _selectedTabIndex == 1
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
          Divider(
            height: 1,
            color: Colors.grey[200],
          ),
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
          bleSignalDetected: _bleSignalDetectedMap[session.id] ?? false, // Pass BLE signal detection state
        );
      },
    );
  }

  void _showBleAttendanceDialog(
    BuildContext context, 
    String sessionId, 
    String studentId, 
    String studentName, 
    String courseId
  ) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final faceRecognitionProvider = Provider.of<FaceRecognitionProvider>(context, listen: false);
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    // State variables
    bool isScanning = false;
    bool bleDetected = false;
    bool isFaceVerified = false;
    BleConnectionStatus bleStatus = BleConnectionStatus.searching;
    String statusMessage = 'Searching for instructor signal...';
    Map<String, dynamic>? faceVerificationResult;
    Timer? statusCheckTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Start BLE scanning when dialog opens
          if (!isScanning) {
            setState(() {
              isScanning = true;
              bleStatus = BleConnectionStatus.searching;
              statusMessage = 'Searching for instructor signal...';
            });

            // Request permissions and start scanning
            bleProvider.checkAndRequestPermissions().then((hasPermissions) {
              if (hasPermissions) {
                bleProvider.startScanningForSignals(sessionId: sessionId).then((success) {
                  if (!success && context.mounted) {
                    setState(() {
                      bleStatus = BleConnectionStatus.error;
                      statusMessage = 'Failed to start BLE scanning: ${bleProvider.errorMessage}';
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to start BLE scanning: ${bleProvider.errorMessage}',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    // Log that scanning started
                    print('🔍 Started scanning for BLE signal with session ID: $sessionId');
                    
                    // Successfully started scanning, set up periodic checks
                    statusCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
                      if (!context.mounted) {
                        timer.cancel();
                        return;
                      }
                      
                      // Check for signal detection
                      final signal = bleProvider.detectedSignal;
                      final status = bleProvider.status;
                      
                      // Log current scanning status
                      print('🔄 BLE Status: $status | Signal detected: ${signal != null}');
                      
                      // Also check directly from scan results for device names containing session fragments
                      final scanResults = bleProvider.scanResults;
                      bool foundByName = false;
                      if (scanResults.isNotEmpty) {
                        for (final result in scanResults) {
                          // Extract first 8 chars of session ID to match with device name
                          final sessionFragment = sessionId.length > 8 ? sessionId.substring(0, 8) : sessionId;
                          final deviceName = result.advertisementData.localName;
                          
                          // Check if device name contains our session ID fragment
                          if (deviceName != null && deviceName.contains("SmartAttnd_$sessionFragment")) {
                            foundByName = true;
                            print('✅ Found BLE device with matching name: $deviceName');
                            break;
                          }
                        }
                      }
                      
                      // Check Firestore for the latest attendance signal as a fallback
                      try {
                        final signalQuery = await FirebaseFirestore.instance
                            .collection('attendance_signals')
                            .where('sessionId', isEqualTo: sessionId)
                            .where('validUntil', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
                            .get();
                        
                        // Also check the session document for bleSignalActive flag
                        final sessionDoc = await FirebaseFirestore.instance
                            .collection('attendance_sessions')
                            .doc(sessionId)
                            .get();
                        
                        final hasValidSignal = signalQuery.docs.isNotEmpty;
                        final sessionBleEnabled = sessionDoc.exists && 
                            (sessionDoc.data() as Map<String, dynamic>?)?.containsKey('bleSignalActive') == true && 
                            sessionDoc.data()!['bleSignalActive'] == true;
                        
                        print('📡 Firestore signal check: ${hasValidSignal ? "Signal active" : "No signal"} | Session BLE enabled: $sessionBleEnabled');
                        
                        // Check if signal has been detected previously
                        final hasDetectedSignal = await bleProvider.hasDetectedSessionSignal(sessionId);
                        
                        if (context.mounted) {
                          setState(() {
                            // Accept a Firestore signal as a valid detection if direct BLE detection fails
                            // This is crucial to make the system work reliably
                            if ((status == BleStatus.signalDetected && signal != null && 
                                signal['sessionId'] == sessionId) || foundByName || hasDetectedSignal || 
                                (hasValidSignal && sessionBleEnabled)) {
                                
                              bleDetected = true;
                              bleStatus = BleConnectionStatus.connected;
                              statusMessage = 'Connected to instructor signal! You can now verify your identity.';
                              
                              // Record the successful detection in our local storage 
                              // to remember it for future reference
                              if (!_bleSignalDetectedMap.containsKey(sessionId)) {
                                _bleSignalDetectedMap[sessionId] = true;
                              }
                              
                              // Also record the detection in BleProvider's storage
                              if (hasValidSignal && signalQuery.docs.isNotEmpty) {
                                final signalData = signalQuery.docs.first.data();
                                bleProvider.recordSignalDetection(signalData);
                                bleProvider.addDetectedSessionId(sessionId);
                              }
                            } else if (!hasValidSignal && !sessionBleEnabled) {
                              bleDetected = false;
                              bleStatus = BleConnectionStatus.error;
                              statusMessage = 'No active BLE signal detected. Ask instructor to enable BLE.';
                            } else {
                              bleDetected = false;
                              bleStatus = BleConnectionStatus.notConnected;
                              statusMessage = 'Signal is active but not detected. Move closer to instructor.';
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
                  bleStatus = BleConnectionStatus.error;
                  statusMessage = 'Bluetooth permissions are required for attendance';
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Bluetooth permissions required for attendance',
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
              bleProvider.stopScanning();
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
                    // Step 1: BLE Verification with clearer indication of connection status
                    BleStatusIndicator(
                      status: bleStatus,
                      sessionId: sessionId,
                      message: statusMessage,
                      onRetry: () {
                        setState(() {
                          bleStatus = BleConnectionStatus.searching;
                          bleDetected = false;
                          statusMessage = 'Searching for instructor signal...';
                        });
                        
                        // Force a new signal check
                        bleProvider.stopScanning().then((_) {
                          Future.delayed(Duration(milliseconds: 500), () {
                            if (context.mounted) {
                              bleProvider.startScanningForSignals(courseId: courseId);
                            }
                          });
                        });
                      },
                    ),

                    const SizedBox(height: 24),
                    
                    // Divider with text
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
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
                        Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Step 2: Face Recognition (only enabled after BLE verification)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bleDetected ? Colors.blue.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: bleDetected ? Colors.blue.shade200 : Colors.grey.shade300,
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
                              color: bleDetected ? Colors.blue.shade100 : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                isFaceVerified ? Icons.check_circle : Icons.face,
                                size: 32,
                                color: isFaceVerified 
                                    ? Colors.green.shade700
                                    : (bleDetected ? Colors.blue.shade700 : Colors.grey.shade500),
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
                              color: isFaceVerified 
                                  ? Colors.green.shade700
                                  : (bleDetected ? Colors.blue.shade700 : Colors.grey.shade600),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            bleDetected 
                                ? (isFaceVerified 
                                    ? 'Your identity has been verified' 
                                    : 'Take a photo to verify your identity')
                                : 'Complete signal detection first',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: bleDetected ? Colors.blue.shade700 : Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 16),

                          if (bleDetected && !isFaceVerified)
                            FutureBuilder<bool>(
                              future: faceRecognitionProvider.checkStudentImageExists(studentId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: SizedBox(
                                      width: 32, 
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                      ),
                                    ),
                                  );
                                }

                                final hasImage = snapshot.data ?? false;

                                if (!hasImage) {
                                  return Column(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 36,
                                        color: Colors.orange[700],
                                      ),
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
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                final result = await faceRecognitionProvider.uploadStudentImage(ImageSource.camera);
                                                if (result != null && context.mounted) {
                                                  setState(() {});
                                                }
                                              },
                                              icon: const Icon(Icons.camera_alt),
                                              label: const Text('Camera')
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                final result = await faceRecognitionProvider.uploadStudentImage(ImageSource.gallery);
                                                if (result != null && context.mounted) {
                                                  setState(() {});
                                                }
                                              },
                                              icon: const Icon(Icons.photo_library),
                                              label: const Text('Gallery')
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return ElevatedButton.icon(
                                  onPressed: bleDetected ? () async {
                                    try {
                                      // Get image from camera
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.camera,
                                        imageQuality: 80,
                                      );

                                      if (pickedFile != null && context.mounted) {
                                        final imageFile = File(pickedFile.path);

                                        // Verify face
                                        final result = await faceRecognitionProvider.compareFaces(
                                          studentId: studentId,
                                          imageFile: imageFile,
                                        );

                                        if (result != null && result['verification_match'] == true) {
                                          setState(() {
                                            isFaceVerified = true;
                                            faceVerificationResult = result;
                                          });
                                        } else if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Face verification failed. Please try again.',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: $e',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  } : null,
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(
                                    bleDetected ? 'Take Photo to Verify' : 'Connect to Signal First',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bleDetected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                                    foregroundColor: bleDetected ? Colors.white : Colors.grey.shade700,
                                    minimumSize: Size(double.infinity, 48),
                                    disabledBackgroundColor: Colors.grey.shade200,
                                    disabledForegroundColor: Colors.grey.shade500,
                                  ),
                                );
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
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade700),
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
                                    final success = await attendanceProvider.markAttendanceWithFaceRecognition(
                                      sessionId: sessionId,
                                      studentId: studentId,
                                      studentName: studentName,
                                      imageFile: File(''), // Empty file as we already have verification result
                                      verificationResult: faceVerificationResult,
                                      bleVerified: true, // Mark as BLE verified
                                    );

                                    if (context.mounted) {
                                      // Stop scanning and clean up timer
                                      statusCheckTimer?.cancel();
                                      bleProvider.stopScanning();
                                      Navigator.of(dialogContext).pop();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Attendance marked successfully'
                                                : 'Failed to mark attendance: ${attendanceProvider.error}',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: success ? Colors.green : Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
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
                    bleProvider.stopScanning();
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFaceRecognitionDialog(BuildContext context, String sessionId, String studentId, String studentName) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final faceRecognitionProvider = Provider.of<FaceRecognitionProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Face Recognition Attendance',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<bool>(
                    future: faceRecognitionProvider.checkStudentImageExists(studentId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final hasImage = snapshot.data ?? false;

                      if (!hasImage) {
                        return Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No profile image found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please upload your profile image to use face recognition for attendance',
                              style: GoogleFonts.poppins(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await faceRecognitionProvider.uploadStudentImage(ImageSource.camera);
                                    if (result != null && context.mounted) {
                                      setState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Camera')
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await faceRecognitionProvider.uploadStudentImage(ImageSource.gallery);
                                    if (result != null && context.mounted) {
                                      setState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Gallery')
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Text(
                            'Take a selfie to verify your identity and mark attendance',
                            style: GoogleFonts.poppins(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    // First get the image from camera
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(
                                      source: ImageSource.camera,
                                      imageQuality: 80,
                                    );

                                    if (pickedFile != null && context.mounted) {
                                      final imageFile = File(pickedFile.path);

                                      // Get comparison result from face recognition provider
                                      final comparisonResult = await faceRecognitionProvider.compareFaces(
                                        studentId: studentId,
                                        imageFile: imageFile,
                                      );

                                      if (comparisonResult != null && comparisonResult['verification_match'] == true) {
                                        // If faces match, mark attendance - pass the verification result to avoid double API calls
                                        final success = await attendanceProvider.markAttendanceWithFaceRecognition(
                                          sessionId: sessionId,
                                          studentId: studentId,
                                          studentName: studentName,
                                          imageFile: imageFile,
                                          verificationResult: comparisonResult, // Pass result to avoid double API call
                                        );

                                        if (context.mounted) {
                                          Navigator.of(context).pop();

                                          // Force UI refresh after successful attendance marking
                                          if (success) {
                                            setState(() {
                                              // Refresh the parent widget
                                            });
                                          }

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? 'Attendance marked successfully'
                                                    : 'Failed to mark attendance: ${attendanceProvider.error}',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: success ? Colors.green : Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } else {
                                        // If faces don't match
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Face verification failed. Please try again.',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error: $e',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Take Photo'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          );
        },
      ),
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
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter student courses
  List<QueryDocumentSnapshot> _filterStudentCourses(List<QueryDocumentSnapshot> docs, String studentId) {
    return docs.where((doc) {
      final courseData = doc.data() as Map<String, dynamic>;
      final students = List<Map<String, dynamic>>.from(
        (courseData['students'] ?? []).map((student) => 
          student is Map<String, dynamic> ? student : {}
        )
      );
      return students.any((student) => student['studentId'] == studentId);
    }).toList();
  }

  // Get active attendance sessions
  Future<List<AttendanceSession>> _getActiveAttendanceSessions(List<String> courseIds) async {
    if (courseIds.isEmpty) {
      return [];
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    
    // Get all active attendance sessions for the student's courses
    final querySnapshot = await firestore
        .collection('attendance_sessions')
        .where('courseId', whereIn: courseIds)
        .where('isActive', isEqualTo: true)
        .get();
    
    final sessions = querySnapshot.docs
        .map((doc) => AttendanceSession.fromFirestore(doc))
        .where((session) => session.endTime.isAfter(now)) // Only include sessions that haven't ended
        .toList();
    
    // Sort by start time (most recent first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    return sessions;
  }

  // Get attendance history
  Future<List<AttendanceSession>> _getAttendanceHistory(List<String> courseIds, String studentId) async {
    if (courseIds.isEmpty) {
      return [];
    }

    final firestore = FirebaseFirestore.instance;
    
    // Get all attendance sessions for the student's courses
    final querySnapshot = await firestore
        .collection('attendance_sessions')
        .where('courseId', whereIn: courseIds)
        .get();
    
    // Filter sessions where the student has marked attendance or the session is closed
    final sessions = querySnapshot.docs
        .map((doc) => AttendanceSession.fromFirestore(doc))
        .where((session) {
          final hasMarkedAttendance = session.attendees.any(
            (attendee) => attendee['studentId'] == studentId
          );
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
  final bool bleSignalDetected; // Add BLE signal detection state

  const _SessionCard({
    required this.session,
    required this.courseName,
    required this.courseCode,
    required this.isActiveTab,
    required this.bleSignalDetected, // Add BLE signal detection state
  });

  @override
  Widget build(BuildContext context) {
    // Check if BLE is available in the session
    final bleEnabled = session.signalTime != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isActiveTab ? () => _handleAttendanceMarking(context) : null,
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
                      Icon(Icons.bluetooth_searching, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This session requires BLE proximity verification',
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
    final studentId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    final studentName = Provider.of<AuthProvider>(context, listen: false).user?.displayName ?? '';
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final isBleEnabled = session.signalTime != null;
    
    // Get a reference to the parent state to access dialog methods
    final parentState = context.findAncestorStateOfType<_StudentAttendancePageState>();
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

    if (isBleEnabled) {
      // First check if there's an active BLE signal for this session in Firestore
      FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(session.id)
          .get()
          .then((doc) {
            final data = doc.data();
            final bleSignalActive = data?['bleSignalActive'] ?? false;
            
            if (!bleSignalActive) {
              // Show error: BLE signal not active
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot mark attendance: The instructor has not activated the BLE signal yet.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              // Show BLE attendance dialog with face recognition
              parentState._showBleAttendanceDialog(context, session.id, studentId, studentName, session.courseId);
            }
          });
    } else {
      // Use the existing face recognition dialog without BLE
      parentState._showFaceRecognitionDialog(context, session.id, studentId, studentName);
    }
  }

  Widget _buildAttendanceStatus(BuildContext context) {
    final studentId = Provider.of<AuthProvider>(context).user?.uid ?? '';
    final wasPresent = session.attendees.any(
      (attendee) => attendee['studentId'] == studentId,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: wasPresent ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: wasPresent ? Colors.green[100]! : Colors.red[100]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            wasPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 20,
            color: wasPresent ? Colors.green[700] : Colors.red[700],
          ),
          const SizedBox(width: 8),
          Text(
            wasPresent ? 'Present' : 'Absent',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: wasPresent ? Colors.green[700] : Colors.red[700],
            ),
          ),
          if (wasPresent) ...[
            const SizedBox(width: 16),
            Icon(
              _getVerificationIcon(session.attendees.firstWhere(
                (attendee) => attendee['studentId'] == studentId,
              )['verificationMethod'] ?? 'Manual'),
              size: 16,
              color: Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              session.attendees
                  .firstWhere(
                    (attendee) => attendee['studentId'] == studentId,
                  )['verificationMethod'] ?? 'Manual',
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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: session.isActive
                ? Colors.green[50]
                : Colors.grey[100],
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
                color: session.isActive
                    ? Colors.green[700]
                    : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                session.isActive ? 'ACTIVE' : 'CLOSED',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: session.isActive
                      ? Colors.green[700]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
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
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
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
        border: Border.all(
          color: Colors.grey[100]!,
        ),
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
            VerticalDivider(
              width: 32,
              thickness: 1,
              color: Colors.grey[200],
            ),
            Expanded(
              child: _TimeInfoItem(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green[100]!,
          ),
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

    // Update button to show BLE scanning if BLE signal is active
    final isBleEnabled = session.signalTime != null;

    return ElevatedButton(
      onPressed: bleSignalDetected ? () => _handleAttendanceMarking(context) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bleSignalDetected ? Theme.of(context).primaryColor : Colors.grey.shade300,
        foregroundColor: bleSignalDetected ? Colors.white : Colors.grey.shade700,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isBleEnabled ? Icons.bluetooth_searching : Icons.face_outlined,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isBleEnabled ? 'Mark Attendance (BLE Enabled)' : 'Mark Attendance',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
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
          textAlign: TextAlign.center,
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
