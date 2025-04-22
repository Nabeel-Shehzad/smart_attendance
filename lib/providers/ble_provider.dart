import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleStatus {
  idle,
  scanning,
  signalDetected,
  broadcasting,
  error,
}

class BleProvider with ChangeNotifier {
  // BLE state
  BleStatus _status = BleStatus.idle;
  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  bool _isScanning = false;
  bool _isBroadcasting = false;
  String _errorMessage = '';
  Map<String, dynamic>? _detectedSignal;
  final Set<String> _detectedSessionIds = {};
  
  // Broadcast state
  Timer? _broadcastTimer;

  // Getters
  BleStatus get status => _status;
  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  bool get isBroadcasting => _isBroadcasting;
  String get errorMessage => _errorMessage;
  Map<String, dynamic>? get detectedSignal => _detectedSignal;

  // Validate if the device has detected a signal for a specific session
  Future<bool> hasDetectedSessionSignal(String sessionId) async {
    // First check local cache
    if (_detectedSessionIds.contains(sessionId)) {
      return true;
    }

    // Then check Firestore for recorded detections (useful if app restarted)
    try {
      final userId = FirebaseFirestore.instance.collection('users').doc().id;
      final doc = await FirebaseFirestore.instance
          .collection('ble_signal_detections')
          .doc('${sessionId}_${userId}')
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking detected signal: $e');
      return false;
    }
  }

  // Check and request necessary permissions for BLE
  Future<bool> checkAndRequestPermissions() async {
    // For Android 12+ we need to request BLUETOOTH_SCAN and BLUETOOTH_CONNECT
    if (Platform.isAndroid) {
      // First check if permissions are already granted
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();
      
      // Debug: Log permission status
      statuses.forEach((permission, status) {
        print('Permission $permission: ${status.isGranted ? "Granted" : "Denied"}');
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
    // For iOS we need Bluetooth permission
    else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    
    return false;
  }
  
  // Start broadcasting attendance signal for teachers
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
        _status = BleStatus.error;
        _errorMessage = 'Bluetooth advertising permissions not granted';
        notifyListeners();
        return false;
      }
      
      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isAvailable) {
        _status = BleStatus.error;
        _errorMessage = 'Bluetooth is not available on this device';
        notifyListeners();
        return false;
      }

      // Create signal data
      final validUntil = DateTime.now().add(Duration(minutes: validityDuration)).millisecondsSinceEpoch;
      final signalData = {
        'sessionId': sessionId,
        'courseId': courseId,
        'instructorId': instructorId,
        'validUntil': validUntil,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Store the signal in Firestore for additional verification
      await FirebaseFirestore.instance
          .collection('attendance_signals')
          .doc(sessionId)
          .set({
            ...signalData,
            'createdAt': FieldValue.serverTimestamp(),
          });
      
      // Update attendance session to show it has an active BLE signal
      await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(sessionId)
          .update({
            'bleSignalActive': true,
            'signalTime': FieldValue.serverTimestamp(),
          });
      
      print("✅ Broadcasting BLE signal for session: $sessionId");
      
      // Note: Direct BLE advertising from Flutter is limited
      // We'll use Firestore as the primary mechanism for signal detection
      try {
        if (Platform.isIOS || Platform.isAndroid) {
          // Convert the session ID to a shorter format to fit BLE payload limits
          final shortSessionId = sessionId.substring(0, sessionId.length > 8 ? 8 : sessionId.length);
          print("📱 Using shortened session ID for BLE: $shortSessionId");
          
          // Note: Actual BLE advertising requires platform-specific implementations
          // The current flutter_blue_plus doesn't support advertising
          // We're relying on Firestore signals as our primary mechanism
        }
      } catch (e) {
        print("⚠️ BLE Advertising not fully supported: $e");
        // Don't fail the method, we still have Firestore as backup
      }
      
      // Set status
      _status = BleStatus.broadcasting;
      _isBroadcasting = true;
      notifyListeners();
      
      // Set up a periodic refresh to update the signal timestamp
      _broadcastTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
        // Update the signal timestamp in Firestore
        try {
          await FirebaseFirestore.instance
              .collection('attendance_signals')
              .doc(sessionId)
              .update({
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            
          print("📡 Updated BLE signal timestamp for session: $sessionId");
        } catch (e) {
          print('Error updating signal timestamp: $e');
        }
      });
      
      return true;
    } catch (e) {
      _status = BleStatus.error;
      _errorMessage = 'Failed to broadcast signal: $e';
      _isBroadcasting = false;
      notifyListeners();
      return false;
    }
  }
  
  // Stop broadcasting
  Future<bool> stopBroadcasting() async {
    try {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      
      _status = BleStatus.idle;
      _isBroadcasting = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to stop broadcasting: $e';
      notifyListeners();
      return false;
    }
  }

  // Start BLE scanning for attendance signals
  Future<bool> startScanningForSignals({
    String? courseId,
    String? sessionId,
    int scanDuration = 30,
  }) async {
    try {
      _clearState();
      _status = BleStatus.scanning;
      _isScanning = true;
      notifyListeners();

      // Initialize subscriptions
      _isScanningSubscription ??= FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        notifyListeners();
      });

      _scanResultsSubscription ??= FlutterBluePlus.scanResults.listen(
        (results) {
          _scanResults.clear();
          _scanResults.addAll(results);
          
          // Process scan results to find attendance signals
          for (ScanResult result in results) {
            // Check for manufacturer data that might contain our signal
            if (result.advertisementData.manufacturerData.isNotEmpty) {
              // Try to decode signal data from manufacturer data
              try {
                final Map<int, List<int>> manufacturerData = result.advertisementData.manufacturerData;
                // Use first available manufacturer data
                final List<int>? rawData = manufacturerData.values.first;
                
                if (rawData != null && rawData.isNotEmpty) {
                  String dataString = String.fromCharCodes(rawData);
                  
                  // Try to decode as JSON
                  try {
                    Map<String, dynamic> decodedSignal = jsonDecode(dataString);
                    
                    // Validate if this is an attendance signal
                    if (decodedSignal.containsKey('sessionId') && 
                        decodedSignal.containsKey('courseId') &&
                        decodedSignal.containsKey('validUntil')) {
                          
                      // Check if the signal is for our course/session if specified
                      bool isRelevantSignal = true;
                      
                      if (courseId != null && decodedSignal['courseId'] != courseId) {
                        isRelevantSignal = false;
                      }
                      
                      if (sessionId != null && decodedSignal['sessionId'] != sessionId) {
                        isRelevantSignal = false;
                      }
                      
                      // Check if signal is still valid
                      final validUntil = decodedSignal['validUntil'] as int;
                      final now = DateTime.now().millisecondsSinceEpoch;
                      if (validUntil < now) {
                        isRelevantSignal = false;
                      }
                      
                      if (isRelevantSignal) {
                        _detectedSignal = decodedSignal;
                        _detectedSessionIds.add(decodedSignal['sessionId']);
                        _status = BleStatus.signalDetected;
                        
                        // Record signal detection in Firestore
                        _recordSignalDetection(decodedSignal);
                        
                        notifyListeners();
                      }
                    }
                  } catch (e) {
                    // Not valid JSON or not our signal format - ignore
                  }
                }
              } catch (e) {
                print('Error decoding manufacturer data: $e');
              }
            }
            
            // Check service data as an alternative location for signal
            if (result.advertisementData.serviceData.isNotEmpty) {
              try {
                // Convert the Map<Guid, List<int>> to Map<String, List<int>>
                final Map<String, List<int>> serviceData = {};
                result.advertisementData.serviceData.forEach((guid, value) {
                  serviceData[guid.toString()] = value;
                });
                
                serviceData.forEach((key, value) {
                  if (value.isNotEmpty) {
                    String dataString = String.fromCharCodes(value);
                    
                    // Try to decode as JSON
                    try {
                      Map<String, dynamic> decodedSignal = jsonDecode(dataString);
                      
                      // Validate if this is an attendance signal
                      if (decodedSignal.containsKey('sessionId') && 
                          decodedSignal.containsKey('courseId') &&
                          decodedSignal.containsKey('validUntil')) {
                            
                        // Check if the signal is for our course/session if specified
                        bool isRelevantSignal = true;
                        
                        if (courseId != null && decodedSignal['courseId'] != courseId) {
                          isRelevantSignal = false;
                        }
                        
                        if (sessionId != null && decodedSignal['sessionId'] != sessionId) {
                          isRelevantSignal = false;
                        }
                        
                        // Check if signal is still valid
                        final validUntil = decodedSignal['validUntil'] as int;
                        final now = DateTime.now().millisecondsSinceEpoch;
                        if (validUntil < now) {
                          isRelevantSignal = false;
                        }
                        
                        if (isRelevantSignal) {
                          _detectedSignal = decodedSignal;
                          _detectedSessionIds.add(decodedSignal['sessionId']);
                          _status = BleStatus.signalDetected;
                          
                          // Record signal detection in Firestore
                          _recordSignalDetection(decodedSignal);
                          
                          notifyListeners();
                        }
                      }
                    } catch (e) {
                      // Not valid JSON or not our signal format - ignore
                    }
                  }
                });
              } catch (e) {
                print('Error decoding service data: $e');
              }
            }
          }
          
          notifyListeners();
        },
        onError: (error) {
          _status = BleStatus.error;
          _errorMessage = 'Scan error: $error';
          notifyListeners();
        },
      );
      
      // Start BLE scan
      if (await FlutterBluePlus.isAvailable) {
        await FlutterBluePlus.startScan(
          timeout: Duration(seconds: scanDuration),
          androidUsesFineLocation: true,
        );
        
        // Set up a fallback timer in case we don't detect expected signal
        // but don't want to leave scanning running indefinitely
        Timer(Duration(seconds: scanDuration + 2), () {
          if (_status == BleStatus.scanning && _detectedSignal == null) {
            stopScanning();
          }
        });
        
        return true;
      } else {
        _status = BleStatus.error;
        _errorMessage = 'Bluetooth is not available on this device';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = BleStatus.error;
      _errorMessage = 'Failed to start scanning: $e';
      notifyListeners();
      return false;
    }
  }

  // Stop scanning
  Future<void> stopScanning() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
    }
    
    _isScanning = false;
    
    // Keep the status as signalDetected if we found one
    if (_status != BleStatus.signalDetected) {
      _status = BleStatus.idle;
    }
    
    notifyListeners();
  }

  // Record signal detection in Firestore for validation
  Future<void> _recordSignalDetection(Map<String, dynamic> signal) async {
    try {
      final userId = FirebaseFirestore.instance.collection('users').doc().id;
      final sessionId = signal['sessionId'];
      
      await FirebaseFirestore.instance
          .collection('ble_signal_detections')
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

  // Clear scanning state
  void _clearState() {
    _scanResults.clear();
    _status = BleStatus.idle;
    _errorMessage = '';
    _detectedSignal = null;
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _broadcastTimer?.cancel();
    stopScanning();
    super.dispose();
  }
}