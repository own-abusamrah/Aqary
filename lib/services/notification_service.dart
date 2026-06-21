//import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import '../screens/buyer/notifications_screen.dart';
import 'firebase.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Real-time stream of all notifications for the current user,
  /// ordered newest first.
  /// Uses client-side sorting to avoid requiring a Firestore composite index.
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return Firebase.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        return AppNotification(
          id: doc.id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          type: data['type'] as String? ?? 'broadcast',
          linkedId: data['linkedId'] as String?,
          targetRole: data['targetRole'] as String?,
          senderCopy: data['senderCopy'] as bool? ?? false,
          isRead: data['isRead'] as bool? ?? false,
          createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      // Sort newest first on the client — no composite index needed
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Count of unread notifications — used for badge on nav bar icon.
  Stream<int> watchUnreadCount(String userId) {
    return Firebase.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    await Firebase.firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await Firebase.firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snap = await Firebase.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = Firebase.firestore.batch();

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> deleteNotificationsByType({
    required String userId,
    required List<String> types,
    bool senderCopyOnly = false,
  }) async {
    final snap = await Firebase.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    final docsToDelete = snap.docs.where((doc) {
      final data = doc.data();

      if (!types.contains(data['type'])) return false;

      if (!senderCopyOnly) return true;

      return data['senderCopy'] == true;
    }).toList();

    if (docsToDelete.isEmpty) return;

    final batch = Firebase.firestore.batch();

    for (final doc in docsToDelete) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Mark all of the user's notifications as read in one batched write.
  Future<void> markAllAsRead(String userId) async {
    final snap = await Firebase.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = Firebase.firestore.batch();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Delete all notifications (across all users) linked to a specific listing.
  /// Used when a seller hides a listing — buyers no longer need those notifications.
  /// Filters client-side to avoid requiring a Firestore composite index.
  Future<void> deleteNotificationsByLinkedId(String linkedId) async {
    // We fetch without .where('linkedId') to avoid index requirements,
    // then filter client-side. For large datasets this is fine since
    // notifications per listing are typically small in number.
    final snap = await Firebase.firestore
        .collection('notifications')
        .where('linkedId', isEqualTo: linkedId)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = Firebase.firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Admin: send broadcast notification to a user group via Cloud Function.
  Future<({int sent, int total})> sendBroadcast({
    required String title,
    required String body,
    required String targetRole, // 'all' | 'buyer' | 'seller' | 'provider'
  }) async {
    final uid = Firebase.auth.currentUser?.uid;

    final result = await Firebase.call('sendBroadcast', {
      'title': title,
      'body': body,
      'targetRole': targetRole,
      if (uid != null) 'callerUid': uid,
    });

    return (
      sent: (result['sent'] as num).toInt(),
      total: (result['total'] as num).toInt(),
    );
  }
}
