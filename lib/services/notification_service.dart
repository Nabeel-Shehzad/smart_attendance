import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Initialize the notification service
  Future<void> initialize() async {
    // Request permission for notifications with stronger permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
      announcement: true,
    );
    
    print('Notification permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Subscribe to topics
      await _messaging.subscribeToTopic('attendance');
      
      // Save the FCM token to Firestore for the current user
      if (currentUserId != null) {
        final token = await _messaging.getToken();
        print('FCM Token obtained: ${token?.substring(0, 10)}...');
        await _saveTokenToFirestore(token);
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
      }
      
      // Configure local notifications
      const AndroidInitializationSettings initSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
      const DarwinInitializationSettings initSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );
      
      const InitializationSettings initSettings = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
          print('Notification tapped: ${notificationResponse.payload}');
          // You can handle notification taps here later
        }
      );
      
      // Create notification channel for Android
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'attendance_channel',
          'Attendance Notifications',
          description: 'Notifications related to attendance',
          importance: Importance.max,
          playSound: true,
          enableLights: true,
          enableVibration: true,
          showBadge: true,
        );
        
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
            
        print('Android notification channel created successfully');
      }
      
      // Configure foreground notifications
      await _configureFirebaseMessaging();
      
      print('Notification service initialized successfully');
    } else {
      print('User declined notification permissions: ${settings.authorizationStatus}');
    }
  }
  
  // Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
  
  // Save the FCM token to Firestore
  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null || currentUserId == null) return;

    try {
      await _firestore
        .collection('users')
        .doc(currentUserId)
        .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'tokenActive': true,
        });
      print('FCM token saved to Firestore successfully');
    } catch (e) {
      print('Error saving FCM token to Firestore: $e');
    }
  }
  
  // Configure Firebase Messaging
  Future<void> _configureFirebaseMessaging() async {
    // Handle messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.messageId}');
      _showLocalNotification(message);
    });
    
    // Handle message when the app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state with message: ${message.messageId}');
        // Handle the initial message
      }
    });
    
    // Handle messages when the app is in the background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background with message: ${message.messageId}');
      // Handle the message
    });
  }
  
  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    if (notification != null) {
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title ?? 'Smart Attendance',
        notification.body ?? 'You have a new notification',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'attendance_channel',
            'Attendance Notifications',
            channelDescription: 'Notifications related to attendance',
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            enableVibration: true,
            enableLights: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['sessionId'],
      );
    }
  }
  
  // Send notification to specific students in a course
  Future<void> sendAttendanceNotificationToCourse(String courseId, String sessionId, String title, String message) async {
    try {
      print('Preparing to send notifications for course: $courseId');
      
      // Get all students in the course
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists) {
        throw Exception('Course not found');
      }
      
      final courseData = courseDoc.data() as Map<String, dynamic>;
      final students = List<Map<String, dynamic>>.from(courseData['students'] ?? []);
      print('Found ${students.length} students in the course');
      
      // Get the current user's role and info
      final currentId = currentUserId;
      
      if (currentId == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore.collection('users').doc(currentId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentUserRole = userData?['role'] as String?;
      print('Current user role: $currentUserRole');
      
      int sentCount = 0;
      
      // Process each student in the course
      for (final student in students) {
        final studentId = student['studentId'] as String;
        
        try {
          final studentDoc = await _firestore.collection('users').doc(studentId).get();
          
          if (!studentDoc.exists) {
            print('Student document not found: $studentId');
            continue;
          }
          
          final studentData = studentDoc.data() as Map<String, dynamic>;
          final fcmToken = studentData['fcmToken'] as String?;
          
          if (fcmToken == null || fcmToken.isEmpty) {
            print('No FCM token for student: $studentId');
            continue;
          }
          
          print('Processing notification for student: $studentId');
          
          // Store notification in Firestore
          final notificationRef = await _firestore.collection('notifications').add({
            'userId': studentId,
            'courseId': courseId,
            'sessionId': sessionId,
            'title': title,
            'message': message,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'attendance',
          });
          
          // If this is the current device and belongs to a student in the course, show notification immediately
          if (currentUserRole == 'student' && currentId == studentId) {
            print('Showing immediate notification for current student');
            await _flutterLocalNotificationsPlugin.show(
              sessionId.hashCode,
              title,
              message,
              NotificationDetails(
                android: const AndroidNotificationDetails(
                  'attendance_channel',
                  'Attendance Notifications',
                  channelDescription: 'Notifications related to attendance',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: sessionId,
            );
          }
          
          // Create a trigger for Cloud Functions to send FCM messages
          await _firestore.collection('notification_triggers').add({
            'type': 'attendance',
            'fcmToken': fcmToken,
            'title': title,
            'body': message,
            'data': {
              'sessionId': sessionId,
              'courseId': courseId,
              'userId': studentId,
              'notificationId': notificationRef.id,
              'type': 'attendance',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            'sentAt': FieldValue.serverTimestamp(),
            'processed': false,
          });
          
          sentCount++;
          print('Created notification trigger for student: $studentId');
          
        } catch (error) {
          print('Error processing student $studentId: $error');
          // Continue processing other students if one fails
          continue;
        }
      }
      
      print('Notifications prepared for $sentCount students');
      
    } catch (e) {
      print('Error sending notifications: $e');
      rethrow;
    }
  }
  
  // Send a test notification directly to the current device - for settings page only
  Future<void> sendTestNotification() async {
    try {
      print('Sending test notification to current device');
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for testing notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        'Notification Test',
        'This is a test notification from Smart Attendance. If you see this, notifications are working!',
        details,
      );
      
      // Also test the FCM trigger mechanism - this will validate the Cloud Function
      if (currentUserId != null) {
        final token = await _messaging.getToken();
        if (token != null) {
          await _firestore.collection('notification_triggers').add({
            'type': 'test',
            'fcmToken': token,
            'title': 'FCM Test',
            'body': 'Testing FCM notification delivery via Cloud Functions',
            'data': {
              'testId': DateTime.now().millisecondsSinceEpoch.toString(),
              'userId': currentUserId,
            },
            'sentAt': FieldValue.serverTimestamp(),
            'processed': false,
          });
          print('Created FCM test notification trigger');
        }
      }
      
      print('Test notification sent');
    } catch (e) {
      print('Error sending test notification: $e');
      rethrow;
    }
  }
}