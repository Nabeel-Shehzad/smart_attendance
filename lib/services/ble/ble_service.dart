import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleService {
  // Singleton implementation
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();
  
  // Constants
  static const String SERVICE_UUID = "9A48ECBA-2E92-082F-C079-9E75AAE428B1"; // Custom UUID for the app
  static const int BROADCAST_DURATION_SECONDS = 60; // Duration for broadcasting (1 minute)
  static const int SIGNAL_VALID_DURATION_SECONDS = 300; // Signal validity period (5 minutes)
  
  // Controller for broadcasting state
  final StreamController<bool> _broadcastingController = StreamController<bool>.broadcast();
  Stream<bool> get broadcastingStream => _broadcastingController.stream;
  
  // Controller for scan results
  final StreamController<Map<String, dynamic>> _signalDetectedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signalDetectedStream => _signalDetectedController.stream;
  
  // State variables
  bool _isScanning = false;
  bool _isBroadcasting = false;
  Timer? _broadcastTimer;
  Timer? _scanTimer;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      // Use the newer API to check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error checking Bluetooth availability: $e');
      return false;
    }
  }
  
  // Request Bluetooth and location permissions
  Future<bool> requestPermissions() async {
    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    // Check if all required permissions are granted
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });
    
    return allGranted;
  }
  
  // Turn on Bluetooth
  Future<bool> turnOnBluetooth() async {
    try {
      // In newer Flutter Blue Plus versions, we use a different approach to enable Bluetooth
      // First check if it's already on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.on) {
        return true;
      }
      
      // Request user to turn on Bluetooth via system dialog
      // Note: This doesn't actually turn on Bluetooth directly but prompts the user
      await FlutterBluePlus.turnOn();
      
      // Wait for a short time and check if Bluetooth is on
      await Future.delayed(const Duration(seconds: 2));
      final newState = await FlutterBluePlus.adapterState.first;
      return newState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error turning on Bluetooth: $e');
      return false;
    }
  }
  
  // Generate a session token for security
  String _generateSessionToken(String sessionId, String courseId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$sessionId:$courseId:$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars for simplicity
  }
  
  // Start broadcasting BLE signal (Instructor side)
  Future<Map<String, dynamic>> startBroadcasting({
    required String sessionId, 
    required String courseId,
    required String instructorId
  }) async {
    if (_isBroadcasting) {
      return {
        'success': false,
        'message': 'Already broadcasting signal'
      };
    }
    
    // Check Bluetooth availability
    if (!await isBluetoothAvailable()) {
      return {
        'success': false,
        'message': 'Bluetooth is not available'
      };
    }
    
    try {
      // Generate token for session
      final token = _generateSessionToken(sessionId, courseId);
      
      // Signal details
      final signalData = {
        'sessionId': sessionId,
        'courseId': courseId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'validUntil': DateTime.now().add(
          Duration(seconds: SIGNAL_VALID_DURATION_SECONDS)
        ).millisecondsSinceEpoch,
        'token': token,
        'instructorId': instructorId
      };
      
      // Convert to JSON and then to bytes
      final jsonData = jsonEncode(signalData);
      
      // Save signal details to Firestore for verification
      await _firestore.collection('attendance_signals').doc(sessionId).set({
        ...signalData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Start broadcasting
      _isBroadcasting = true;
      _broadcastingController.add(true);
      
      // Note: In a real implementation, we would use platform-specific code for BLE advertising
      // Flutter Blue Plus doesn't directly support advertising in all platforms
      // We're using Firestore as the primary mechanism and BLE scanning as a proximity check
      debugPrint('Started broadcasting BLE signal for session: $sessionId');
      debugPrint('Signal data: $jsonData');
      
      // Start timer to auto-stop broadcasting
      _broadcastTimer = Timer(Duration(seconds: BROADCAST_DURATION_SECONDS), () {
        stopBroadcasting();
      });
      
      return {
        'success': true,
        'message': 'Started broadcasting attendance signal',
        'data': signalData
      };
    } catch (e) {
      debugPrint('Error broadcasting BLE signal: $e');
      return {
        'success': false,
        'message': 'Failed to broadcast signal: $e'
      };
    }
  }
  
  // Stop broadcasting
  Future<bool> stopBroadcasting() async {
    if (!_isBroadcasting) {
      return false;
    }
    
    _broadcastTimer?.cancel();
    _isBroadcasting = false;
    _broadcastingController.add(false);
    
    debugPrint('Stopped broadcasting BLE signal');
    return true;
  }
  
  // Start scanning for BLE signals (Student side)
  Future<bool> startScanning({
    required String courseId,
    required Function(Map<String, dynamic>) onSignalDetected
  }) async {
    if (_isScanning) {
      return false;
    }
    
    // Check Bluetooth availability
    if (!await isBluetoothAvailable()) {
      return false;
    }
    
    try {
      _isScanning = true;
      
      // Start scanning for BLE devices using updated API
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 10),
        withServices: [Guid(SERVICE_UUID)],
      );
      
      // Listen for scan results with updated API
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Check if this device is advertising our service UUID
          if (result.advertisementData.serviceUuids.contains(SERVICE_UUID)) {
            _processDetectedSignal(result, courseId, onSignalDetected);
          }
        }
      });
      
      // Auto-restart scanning every 10 seconds
      _scanTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
        if (_isScanning) {
          await FlutterBluePlus.stopScan();
          await FlutterBluePlus.startScan(
            timeout: Duration(seconds: 10),
            withServices: [Guid(SERVICE_UUID)],
          );
        } else {
          _scanTimer?.cancel();
        }
      });
      
      return true;
    } catch (e) {
      debugPrint('Error scanning for BLE signals: $e');
      _isScanning = false;
      return false;
    }
  }
  
  // Process a detected signal
  void _processDetectedSignal(
    ScanResult result, 
    String courseId, 
    Function(Map<String, dynamic>) onSignalDetected
  ) async {
    try {
      // In a real implementation, we'd extract the payload from the scan record
      // Here we'll fetch the signal from Firestore for simplicity
      
      // Get active signals for this course
      final signalQuery = await _firestore.collection('attendance_signals')
          .where('courseId', isEqualTo: courseId)
          .where('validUntil', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
          .get();
      
      if (signalQuery.docs.isNotEmpty) {
        // Get the latest signal
        final signalData = signalQuery.docs.first.data();
        
        // Check proximity using RSSI value
        if (result.rssi > -80) { // -80dBm is a reasonable proximity threshold
          debugPrint('Valid attendance signal detected for course: $courseId');
          
          // Add session ID to detected signals in shared preferences
          final prefs = await SharedPreferences.getInstance();
          final detectedSignals = prefs.getStringList('detected_signals') ?? [];
          if (!detectedSignals.contains(signalData['sessionId'])) {
            detectedSignals.add(signalData['sessionId']);
            await prefs.setStringList('detected_signals', detectedSignals);
          }
          
          // Notify listeners
          onSignalDetected(signalData);
          _signalDetectedController.add(signalData);
        }
      }
    } catch (e) {
      debugPrint('Error processing detected signal: $e');
    }
  }
  
  // Stop scanning
  Future<bool> stopScanning() async {
    if (!_isScanning) {
      return false;
    }
    
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    
    debugPrint('Stopped scanning for BLE signals');
    return true;
  }
  
  // Check if a signal has been detected for a session
  Future<bool> hasDetectedSignal(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final detectedSignals = prefs.getStringList('detected_signals') ?? [];
    return detectedSignals.contains(sessionId);
  }
  
  // Verify if a student is in range of the instructor's signal
  Future<bool> verifyStudentProximity(String sessionId) async {
    try {
      // Check if we have detected this signal
      final hasSignal = await hasDetectedSignal(sessionId);
      if (!hasSignal) {
        return false;
      }
      
      // In a real implementation, we'd also check the timestamp and RSSI
      // For simplicity, we're just checking if the signal was detected
      return true;
    } catch (e) {
      debugPrint('Error verifying student proximity: $e');
      return false;
    }
  }
  
  // Dispose resources
  void dispose() {
    _broadcastTimer?.cancel();
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    stopBroadcasting();
    stopScanning();
    _broadcastingController.close();
    _signalDetectedController.close();
  }
}