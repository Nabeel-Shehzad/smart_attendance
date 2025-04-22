const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function that sends FCM notifications to students
 * Triggered when a new document is created in the notification_triggers collection
 */
exports.sendAttendanceNotifications = onDocumentCreated('notification_triggers/{triggerId}', async (event) => {
    const snapshot = event.data;
    const triggerData = snapshot.data();
    
    // Skip if already processed
    if (triggerData.processed) {
      logger.log('Notification already processed, skipping:', event.params.triggerId);
      return null;
    }
    
    const fcmToken = triggerData.fcmToken;
    if (!fcmToken) {
      logger.error('No FCM token provided in trigger document');
      await snapshot.ref.update({
        processed: true, 
        success: false,
        error: 'No FCM token provided'
      });
      return {success: false, error: 'No FCM token provided'};
    }
    
    // Prepare the notification message
    const message = {
      token: fcmToken,
      notification: {
        title: triggerData.title,
        body: triggerData.body,
      },
      data: triggerData.data || {},
      android: {
        priority: "high",
        notification: {
          channelId: "attendance_channel",
          priority: "max",
          sound: "default",
          icon: "@mipmap/ic_launcher"
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            contentAvailable: true
          }
        },
        headers: {
          "apns-priority": "10"
        }
      }
    };
    
    try {
      // Send the FCM message
      logger.log(`Sending notification to token: ${fcmToken.substring(0, 10)}...`);
      const response = await admin.messaging().send(message);
      logger.log('Successfully sent notification:', response);
      
      // Mark as processed
      await snapshot.ref.update({
        processed: true, 
        success: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return {success: true, messageId: response};
    } catch (error) {
      logger.error('Error sending notification:', error);
      
      // Check if token is invalid
      let errorDetails = error.message;
      let shouldDeleteToken = false;
      
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        errorDetails = 'Invalid or unregistered FCM token';
        shouldDeleteToken = true;
      }
      
      // Mark as failed
      await snapshot.ref.update({
        processed: true,
        success: false,
        error: errorDetails,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // If token is invalid, update user record
      if (shouldDeleteToken && triggerData.data && triggerData.data.userId) {
        try {
          const userRef = admin.firestore().collection('users').doc(triggerData.data.userId);
          await userRef.update({
            fcmToken: admin.firestore.FieldValue.delete(),
            tokenInvalidAt: admin.firestore.FieldValue.serverTimestamp()
          });
          logger.log(`Removed invalid token for user: ${triggerData.data.userId}`);
        } catch (userUpdateError) {
          logger.error('Error updating user token status:', userUpdateError);
        }
      }
      
      return {success: false, error: errorDetails};
    }
});