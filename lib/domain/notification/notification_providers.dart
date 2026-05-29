import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'notification_model.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  // Auto-delete notifications older than 30 days on the client side during fetch
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where(
        'created_at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
      )
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();
      });
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('is_read', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

class NotificationController {
  final String uid;

  NotificationController(this.uid);

  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'is_read': true});
  }

  Future<void> markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'is_read': true});
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<void> markAsReadByType(List<NotificationType> types) async {
    final typeStrs = types.map((t) {
      switch (t) {
        case NotificationType.friendRequest:
          return 'friend_request';
        case NotificationType.eventInvite:
          return 'event_invite';
        case NotificationType.friendPostedEvent:
          return 'friend_posted_event';
        case NotificationType.eventRsvp:
          return 'event_rsvp';
        case NotificationType.eventWaitlist:
          return 'event_waitlist';
        case NotificationType.eventRequestToJoin:
          return 'event_request_to_join';
        case NotificationType.friendRequestAccepted:
          return 'friend_request_accepted';
        case NotificationType.eventUpdate:
          return 'event_update';
        case NotificationType.eventReminder:
          return 'event_reminder';
        case NotificationType.waitlistApproved:
          return 'waitlist_approved';
        case NotificationType.coHostInvite:
          return 'co_host_invite';
        default:
          return 'unknown';
      }
    }).toList();

    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .where('type', whereIn: typeStrs)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'is_read': true});
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}

final notificationControllerProvider = Provider<NotificationController?>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return null;
  return NotificationController(user.uid);
});
