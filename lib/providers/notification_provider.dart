import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  String? _fcmToken;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;

  // Initialize notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _notificationService.initialize();
      _fcmToken = await _notificationService.getToken();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send attendance notification to students in a course
  Future<bool> sendAttendanceNotification({
    required String courseId,
    required String sessionId,
    required String title,
    required String message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _notificationService.sendAttendanceNotificationToCourse(
        courseId, 
        sessionId, 
        title, 
        message
      );

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send a test notification directly to the current device
  Future<bool> sendTestNotification() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create a test notification
      await _notificationService.sendTestNotification();
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user notifications
  Stream<QuerySnapshot> getUserNotifications() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _notificationService.currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear all notifications
  Future<bool> clearAllNotifications() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _notificationService.currentUserId)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get the current FCM token - useful for debugging
  Future<String?> getToken() async {
    try {
      _fcmToken = await _notificationService.getToken();
      notifyListeners();
      return _fcmToken;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}