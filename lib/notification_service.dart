import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification.dart';

/// Notification Service - Handles all notification-related operations
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a notification to a user
  Future<void> sendNotification({
    required String toUserId,
    required String type,
    required String fromUserId,
    required String fromUserName,
    String? fromUserAvatar,
    String? message,
  }) async {
    try {
      final notificationRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('notifications')
          .doc();

      final notification = AppNotification(
        id: notificationRef.id,
        type: type,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        fromUserAvatar: fromUserAvatar,
        message: message,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await notificationRef.set(notification.toJson());
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      rethrow;
    }
  }

  /// Get all notifications for a user
  Stream<List<AppNotification>> streamNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Get unread notification count
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  /// Send a nudge notification
  Future<void> sendNudge({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String? fromUserAvatar,
  }) async {
    await sendNotification(
      toUserId: toUserId,
      type: 'nudge',
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      message: 'nudged you for motivation!',
    );
  }
}
