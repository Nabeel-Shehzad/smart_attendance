import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

// Enum to represent WiFi connection status
enum WifiConnectionStatus {
  connected,
  disconnected,
  searching,
  error,
  idle,
  signalDetected,
  broadcasting
}

class WifiProvider with ChangeNotifier {
  // Network info instance for WiFi operations
  final _networkInfo = NetworkInfo();
  
  // Firestore instance
  final _firestore = FirebaseFirestore.instance;
  
  // Wifi state
  WifiConnectionStatus _status = WifiConnectionStatus.idle;
  String _errorMessage = '';
  Map<String, dynamic>? _detectedSignal;
  final Set<String> _detectedSessionIds = {};
  String? _currentWifiName;
  bool _isBroadcasting = false;
  Map<String, dynamic>? _currentWifiInfo;

  // Broadcast state
  Timer? _broadcastTimer;
  Timer? _scanTimer;

  // Getters
  WifiConnectionStatus get status => _status;
  bool get isBroadcasting => _isBroadcasting;
  String get errorMessage => _errorMessage;
  Map<String, dynamic>? get detectedSignal => _detectedSignal;
  String? get currentWifiName => _currentWifiName;
  Map<String, dynamic>? get currentWifiInfo => _currentWifiInfo;

  // Method to check and reset WiFi state
  Future<bool> checkAndResetWifiState() async {
    try {
      // Reset error state
      _status = WifiConnectionStatus.idle;
      _errorMessage = '';
      notifyListeners();
      
      // Check if WiFi is enabled now
      final wifiEnabled = await isWifiEnabled();
      if (!wifiEnabled) {
        _status = WifiConnectionStatus.disconnected;
        _errorMessage = 'WiFi is not enabled';
        notifyListeners();
        return false;
      }
      
      // Try to get WiFi name to verify connectivity
      final wifiName = await _networkInfo.getWifiName();
      if (wifiName == null) {
        _status = WifiConnectionStatus.disconnected;
        _errorMessage = 'Not connected to any WiFi network';
        notifyListeners();
        return false;
      }
      
      // WiFi is connected
      _status = WifiConnectionStatus.connected;
      _currentWifiName = wifiName;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error checking WiFi state: $e');
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Error checking WiFi: $e';
      notifyListeners();
      return false;
    }
  }

  // Get device details
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown';
    String deviceId = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        if (iosInfo.name != null) {
          deviceName = iosInfo.name;
        } else if (iosInfo.model != null) {
          deviceName = iosInfo.model;
        } else {
          deviceName = 'iOS Device';
        }
        deviceId = iosInfo.identifierForVendor ?? '';
      }

      return {
        'deviceName': deviceName,
        'deviceId': deviceId,
      };
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'deviceName': deviceName,
        'deviceId': deviceId,
        'error': e.toString(),
      };
    }
  }

  // Validate if the device has detected a signal for a specific session
  Future<bool> hasDetectedSessionSignal(String sessionId) async {
    // First check local cache
    if (_detectedSessionIds.contains(sessionId)) {
      return true;
    }

    // Then check Firestore for recorded detections (useful if app restarted)
    try {
      final userId = FirebaseFirestore.instance.collection('users').doc().id;
      final doc =
          await FirebaseFirestore.instance
              .collection('wifi_signal_detections')
              .doc('${sessionId}_${userId}')
              .get();

      return doc.exists;
    } catch (e) {
      print('Error checking detected signal: $e');
      return false;
    }
  }

  // Check and request necessary permissions for WiFi
  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // For Android, we need location permission to get WiFi information
      Map<Permission, PermissionStatus> statuses =
          await [
            Permission.location,
          ].request();

      // Debug: Log permission status
      statuses.forEach((permission, status) {
        print(
          'Permission $permission: ${status.isGranted ? "Granted" : "Denied"}',
        );
      });

      // Check if all permissions are granted
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
          _errorMessage = 'Missing permission: $permission';
        }
      });

      return allGranted;
    }
    
    return true; // iOS doesn't need special permissions for this implementation
  }

  // Get current WiFi network name
  Future<String?> getCurrentWifiName() async {
    try {
      // Check permissions first
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'WiFi permissions not granted';
        notifyListeners();
        return null;
      }

      _status = WifiConnectionStatus.searching;
      notifyListeners();

      try {
        // Get WiFi name using network_info_plus
        _currentWifiName = await _networkInfo.getWifiName();
        
        // Clean up the WiFi name (remove quotes if present)
        if (_currentWifiName != null) {
          _currentWifiName = _currentWifiName!.replaceAll('"', '');
          
          // On Android, the WiFi name might have a prefix
          if (_currentWifiName!.startsWith('<')) {
            _currentWifiName = _currentWifiName!.substring(1);
          }
          if (_currentWifiName!.endsWith('>')) {
            _currentWifiName = _currentWifiName!.substring(0, _currentWifiName!.length - 1);
          }
          
          // Update current WiFi info
          _currentWifiInfo = {
            'name': _currentWifiName,
            'bssid': await _networkInfo.getWifiBSSID() ?? 'unknown',
            'ipAddress': await _networkInfo.getWifiIP() ?? 'unknown',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };
          
          _status = WifiConnectionStatus.connected;
          notifyListeners();
          return _currentWifiName;
        } else {
          _status = WifiConnectionStatus.disconnected;
          _errorMessage = 'Not connected to any WiFi network';
          notifyListeners();
          return null;
        }
      } catch (e) {
        print('Error getting WiFi name: $e');
        _status = WifiConnectionStatus.error;
        _errorMessage = 'Failed to get WiFi name: $e';
        notifyListeners();
        return null;
      }
    } catch (e) {
      print('Error in getCurrentWifiName: $e');
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return null;
    }
  }

  // Check if WiFi is enabled
  Future<bool> isWifiEnabled() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      return wifiIP != null && wifiIP.isNotEmpty;
    } catch (e) {
      print('Error checking if WiFi is enabled: $e');
      return false;
    }
  }

  // Request user to enable WiFi
  Future<bool> requestWifiEnable() async {
    // We can't directly enable WiFi from the app, so we show a message
    _errorMessage = 'Please enable WiFi in your device settings';
    notifyListeners();
    return await isWifiEnabled();
  }

  // Start scanning for attendance signals
  Future<void> startScanningForSignals({
    String? sessionId,
    int scanDuration = 15,
  }) async {
    if (sessionId == null) {
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Session ID is required';
      notifyListeners();
      return;
    }

    // Check permissions first
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      _status = WifiConnectionStatus.error;
      _errorMessage = 'WiFi permissions not granted';
      notifyListeners();
      return;
    }

    // Check if WiFi is enabled
    final wifiEnabled = await isWifiEnabled();
    if (!wifiEnabled) {
      _status = WifiConnectionStatus.error;
      _errorMessage = 'WiFi is not enabled';
      notifyListeners();
      return;
    }

    // Start scanning
    _status = WifiConnectionStatus.searching;
    _errorMessage = '';
    notifyListeners();

    // Get current WiFi information
    await getCurrentWifiName();

    // Set up a timer to scan periodically
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      // Check if we've already detected this session
      if (_detectedSessionIds.contains(sessionId)) {
        timer.cancel();
        return;
      }

      // Check Firestore for active signals
      try {
        final signalDoc = await FirebaseFirestore.instance
            .collection('attendance_signals')
            .doc(sessionId)
            .get();

        if (signalDoc.exists && signalDoc.data() != null) {
          final signalData = signalDoc.data()!;
          final signalWifiName = signalData['wifiName'];

          // Compare with current WiFi
          if (_currentWifiName == signalWifiName) {
            _detectedSignal = {
              'sessionId': sessionId,
              'wifiName': signalWifiName,
              'detectedAt': DateTime.now().millisecondsSinceEpoch,
            };
            _detectedSessionIds.add(sessionId);
            _status = WifiConnectionStatus.signalDetected;
            notifyListeners();

            // Record detection
            await _recordSignalDetection(_detectedSignal!);

            // Stop scanning
            timer.cancel();
          }
        }
      } catch (e) {
        print('Error scanning for signals: $e');
      }

      // Stop scanning after the specified duration
      if (timer.tick >= scanDuration) {
        timer.cancel();
        if (_status != WifiConnectionStatus.signalDetected) {
          _status = WifiConnectionStatus.error;
          _errorMessage = 'No attendance signal detected';
          notifyListeners();
        }
      }
    });
  }

  // Stop scanning for signals
  Future<void> stopScanning() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    return;
  }

  // Verify WiFi connection for attendance
  Future<bool> verifyWifiConnection({
    required String sessionId,
    required String courseId,
    required String networkName,
    required String networkId,
    required String bssid,
  }) async {
    try {
      // Check permissions first
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'WiFi permissions not granted';
        notifyListeners();
        return false;
      }

      // Get current WiFi information
      final currentWifi = await getCurrentWifiName();
      if (currentWifi == null) {
        _status = WifiConnectionStatus.disconnected;
        _errorMessage = 'Not connected to any WiFi network';
        notifyListeners();
        return false;
      }

      // Compare with expected network
      if (currentWifi == networkName) {
        // Get additional info for verification
        final currentBssid = await _networkInfo.getWifiBSSID() ?? '';
        
        // For stronger verification, we can check BSSID (MAC address of router)
        // This is optional and depends on your security requirements
        if (bssid.isNotEmpty && currentBssid != bssid) {
          _status = WifiConnectionStatus.error;
          _errorMessage = 'Connected to the correct network name, but router details do not match';
          notifyListeners();
          return false;
        }
        
        // Store session ID in detected sessions
        _detectedSessionIds.add(sessionId);
        _status = WifiConnectionStatus.signalDetected;
        _detectedSignal = {
          'sessionId': sessionId,
          'courseId': courseId,
          'networkName': networkName,
          'networkId': networkId,
          'bssid': currentBssid,
          'detectedAt': DateTime.now().millisecondsSinceEpoch,
        };

        // Record detection in Firestore
        await _recordSignalDetection(_detectedSignal!);

        notifyListeners();
        return true;
      } else {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'Not connected to the correct WiFi network';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error verifying WiFi connection: $e');
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // Verify if the WiFi network for a session is still available
  Future<bool> verifyWifiNetworkStillAvailable(String sessionId) async {
    try {
      // Check if we have the session in our detected list
      if (!_detectedSessionIds.contains(sessionId)) {
        return false;
      }

      // Get current WiFi name
      final currentWifi = await getCurrentWifiName();
      if (currentWifi == null) {
        return false;
      }

      // Check if the signal document still exists and is active
      final signalDoc = await FirebaseFirestore.instance
          .collection('attendance_signals')
          .doc(sessionId)
          .get();

      if (!signalDoc.exists || signalDoc.data() == null) {
        return false;
      }

      final signalData = signalDoc.data()!;
      return signalData['wifiName'] == currentWifi && signalData['active'] == true;
    } catch (e) {
      print('Error verifying WiFi network availability: $e');
      return false;
    }
  }

  // Broadcast attendance signal (for instructors)
  Future<bool> broadcastAttendanceSignal({
    required String sessionId,
    required String courseId,
    required String instructorId,
    int validityDuration = 30, // in minutes, with default value
  }) async {
    try {
      // Check permissions first
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'WiFi permissions not granted';
        notifyListeners();
        return false;
      }

      // Check if WiFi is enabled
      final wifiEnabled = await isWifiEnabled();
      if (!wifiEnabled) {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'WiFi is not enabled';
        notifyListeners();
        return false;
      }

      // Get current WiFi name
      final wifiName = await getCurrentWifiName();
      if (wifiName == null) {
        _status = WifiConnectionStatus.error;
        _errorMessage = 'Failed to get WiFi name';
        notifyListeners();
        return false;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Get current WiFi BSSID (MAC address of the access point)
      final bssid = await _networkInfo.getWifiBSSID() ?? 'unknown';
      
      // Get WiFi IP address
      final ipAddress = await _networkInfo.getWifiIP() ?? 'unknown';

      // Create a unique signal ID
      final signalId = '$sessionId';

      // Calculate expiry time
      final expiryTime = DateTime.now().add(Duration(minutes: validityDuration));

      // Create signal data with detailed WiFi information
      final signalData = {
        'sessionId': sessionId,
        'courseId': courseId,
        'instructorId': instructorId,
        'wifiName': wifiName,         // Store the WiFi network name
        'bssid': bssid,               // Store the WiFi BSSID (MAC address)
        'ipAddress': ipAddress,       // Store the IP address
        'deviceInfo': deviceInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryTime': expiryTime.millisecondsSinceEpoch,
        'wifiSignalActive': true,
      };

      print('📡 Broadcasting attendance signal for session $sessionId on WiFi: $wifiName');

      // Store signal in Firestore
      await FirebaseFirestore.instance
          .collection('attendance_signals')
          .doc(signalId)
          .set(signalData);

      // Start a timer to update the signal periodically
      _broadcastTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          // Check if the signal document still exists
          final doc = await FirebaseFirestore.instance
              .collection('attendance_signals')
              .doc(signalId)
              .get();

          if (doc.exists) {
            // Update the timestamp and ensure WiFi info is still current
            final currentWifiName = await getCurrentWifiName();
            final currentBssid = await _networkInfo.getWifiBSSID() ?? 'unknown';
            final currentIpAddress = await _networkInfo.getWifiIP() ?? 'unknown';
            
            await FirebaseFirestore.instance
                .collection('attendance_signals')
                .doc(sessionId)
                .update({
                  'updatedAt': FieldValue.serverTimestamp(),
                  'wifiName': currentWifiName,
                  'bssid': currentBssid,
                  'ipAddress': currentIpAddress,
                });
          }
        } catch (e) {
          print('Error updating signal: $e');
        }
      });

      _status = WifiConnectionStatus.broadcasting;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error broadcasting attendance signal: $e');
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // Stop broadcasting attendance signal
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _isBroadcasting = false;

    // Update all active signals to inactive
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('attendance_signals')
          .where('wifiSignalActive', isEqualTo: true)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'wifiSignalActive': false});
      }
    } catch (e) {
      print('Error stopping broadcast: $e');
    }

    notifyListeners();
  }

  // Check if student's WiFi matches the teacher's for attendance
  Future<bool> checkWifiMatchForAttendance({
    String? courseId,
    String? sessionId,
  }) async {
    try {
      if (sessionId != null) {
        // Check permissions first
        final hasPermission = await checkAndRequestPermissions();
        if (!hasPermission) {
          _status = WifiConnectionStatus.error;
          _errorMessage = 'WiFi permissions not granted';
          notifyListeners();
          return false;
        }

        // Get current WiFi name
        final studentWifiName = await getCurrentWifiName();
        if (studentWifiName == null) {
          _status = WifiConnectionStatus.error;
          _errorMessage = 'Unable to get current WiFi network name';
          notifyListeners();
          return false;
        }

        print("📱 Student's WiFi network: $studentWifiName");

        // If we have a session ID, fetch teacher's WiFi info from Firestore
        try {
          final signalDoc =
              await _firestore
                  .collection('attendance_signals')
                  .doc(sessionId)
                  .get();

          if (signalDoc.exists) {
            final data = signalDoc.data();
            if (data != null) {
              final teacherWifiName = data['wifiName'];
              print("🔍 Teacher's WiFi network: $teacherWifiName");

              // Check if the session is still active
              final sessionDoc =
                  await _firestore
                      .collection('attendance_sessions')
                      .doc(sessionId)
                      .get();

              if (sessionDoc.exists &&
                  sessionDoc.data()?['wifiSignalActive'] == true) {
                
                // Check if student is on the same WiFi network as the teacher
                if (studentWifiName == teacherWifiName) {
                  // Store session ID in detected sessions
                  _detectedSessionIds.add(sessionId);
                  _status = WifiConnectionStatus.signalDetected;
                  _detectedSignal = {
                    'sessionId': sessionId,
                    'courseId': courseId,
                    'teacherWifiName': teacherWifiName,
                    'studentWifiName': studentWifiName,
                    'detectedAt': DateTime.now().millisecondsSinceEpoch,
                  };

                  // Record detection in Firestore
                  if (_detectedSignal != null) {
                    _recordSignalDetection(_detectedSignal!);
                  }

                  notifyListeners();
                  print("✅ WiFi MATCH: Student is on the same network as teacher");
                  return true;
                } else {
                  _status = WifiConnectionStatus.error;
                  _errorMessage = 'You are not connected to the same WiFi network as your instructor';
                  notifyListeners();
                  print("❌ WiFi MISMATCH: Student is on a different network");
                  return false;
                }
              } else {
                print("⚠️ WiFi signal not active for session: $sessionId");
                _status = WifiConnectionStatus.error;
                _errorMessage = 'Attendance session is not active';
                notifyListeners();
                return false;
              }
            } else {
              print("⚠️ No WiFi data found for session: $sessionId");
              _status = WifiConnectionStatus.error;
              _errorMessage = 'No attendance signal found';
              notifyListeners();
              return false;
            }
          } else {
            print("⚠️ No signal document found for session: $sessionId");
            _status = WifiConnectionStatus.error;
            _errorMessage = 'No attendance signal found';
            notifyListeners();
            return false;
          }
        } catch (e) {
          print('❌ Error fetching teacher WiFi info: $e');
          _status = WifiConnectionStatus.error;
          _errorMessage = 'Failed to get instructor WiFi info: $e';
          notifyListeners();
          return false;
        }
      }

      _status = WifiConnectionStatus.error;
      _errorMessage = 'Session ID is required';
      notifyListeners();
      return false;
    } catch (e) {
      print("❌ General error in checkWifiMatchForAttendance: $e");
      _status = WifiConnectionStatus.error;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // Record signal detection in Firestore for validation
  Future<void> _recordSignalDetection(Map<String, dynamic> signal) async {
    try {
      final userId = FirebaseFirestore.instance.collection('users').doc().id;
      final sessionId = signal['sessionId'];

      await FirebaseFirestore.instance
          .collection('wifi_signal_detections')
          .doc('${sessionId}_${userId}')
          .set({
            'sessionId': sessionId,
            'userId': userId,
            'detectedAt': FieldValue.serverTimestamp(),
            'signal': signal,
          });
    } catch (e) {
      print('Error recording signal detection: $e');
    }
  }

  // Public method to record signal detection (to be used from outside)
  Future<void> recordSignalDetection(Map<String, dynamic> signal) async {
    return _recordSignalDetection(signal);
  }

  // Public method to add a session ID to detected IDs (to be used from outside)
  void addDetectedSessionId(String sessionId) {
    _detectedSessionIds.add(sessionId);
  }

  // Reset provider state to initial values
  void resetState() {
    _status = WifiConnectionStatus.idle;
    _errorMessage = '';
    _detectedSignal = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    super.dispose();
  }
}
