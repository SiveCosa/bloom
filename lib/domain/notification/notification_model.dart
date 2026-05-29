import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  eventInvite,
  friendPostedEvent,
  eventRsvp,
  eventWaitlist,
  eventRequestToJoin,
  friendRequestAccepted,
  eventUpdate,
  eventReminder,
  waitlistApproved,
  coHostInvite,
  eventNudge,
  unknown
}

class AppNotification {
  final String id;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  
  // Who triggered the notification (if applicable)
  final String? actorId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  
  // Used for grouped notifications (e.g., "+10 others")
  final int groupedCount;
  
  // Target IDs (e.g., event ID)
  final String? targetId;
  final String? targetName;
  final String? targetImageUrl;
  
  final String? message;

  AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actorId,
    this.actorUsername,
    this.actorAvatarUrl,
    this.groupedCount = 0,
    this.targetId,
    this.targetName,
    this.targetImageUrl,
    this.message,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    NotificationType type;
    final typeStr = data['type'] as String?;
    switch (typeStr) {
      case 'friend_request':
        type = NotificationType.friendRequest;
        break;
      case 'event_invite':
        type = NotificationType.eventInvite;
        break;
      case 'friend_posted_event':
        type = NotificationType.friendPostedEvent;
        break;
      case 'event_rsvp':
        type = NotificationType.eventRsvp;
        break;
      case 'event_waitlist':
        type = NotificationType.eventWaitlist;
        break;
      case 'event_request_to_join':
        type = NotificationType.eventRequestToJoin;
        break;
      case 'friend_request_accepted':
        type = NotificationType.friendRequestAccepted;
        break;
      case 'event_update':
        type = NotificationType.eventUpdate;
        break;
      case 'event_reminder':
        type = NotificationType.eventReminder;
        break;
      case 'waitlist_approved':
        type = NotificationType.waitlistApproved;
        break;
      case 'co_host_invite':
        type = NotificationType.coHostInvite;
        break;
      case 'event_nudge':
        type = NotificationType.eventNudge;
        break;
      default:
        type = NotificationType.unknown;
    }

    DateTime createdAt = DateTime.now();
    if (data['created_at'] != null) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    }

    return AppNotification(
      id: doc.id,
      type: type,
      createdAt: createdAt,
      isRead: data['is_read'] ?? false,
      actorId: data['actor_id'],
      actorUsername: data['actor_username'],
      actorAvatarUrl: data['actor_avatar_url'],
      groupedCount: data['grouped_count'] ?? 0,
      targetId: data['target_id'],
      targetName: data['target_name'],
      targetImageUrl: data['target_image_url'],
      message: data['message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    String typeStr;
    switch (type) {
      case NotificationType.friendRequest:
        typeStr = 'friend_request';
        break;
      case NotificationType.eventInvite:
        typeStr = 'event_invite';
        break;
      case NotificationType.friendPostedEvent:
        typeStr = 'friend_posted_event';
        break;
      case NotificationType.eventRsvp:
        typeStr = 'event_rsvp';
        break;
      case NotificationType.eventWaitlist:
        typeStr = 'event_waitlist';
        break;
      case NotificationType.eventRequestToJoin:
        typeStr = 'event_request_to_join';
        break;
      case NotificationType.friendRequestAccepted:
        typeStr = 'friend_request_accepted';
        break;
      case NotificationType.eventUpdate:
        typeStr = 'event_update';
        break;
      case NotificationType.eventReminder:
        typeStr = 'event_reminder';
        break;
      case NotificationType.waitlistApproved:
        typeStr = 'waitlist_approved';
        break;
      case NotificationType.coHostInvite:
        typeStr = 'co_host_invite';
        break;
      case NotificationType.eventNudge:
        typeStr = 'event_nudge';
        break;
      default:
        typeStr = 'unknown';
    }

    return {
      'type': typeStr,
      'created_at': Timestamp.fromDate(createdAt),
      'is_read': isRead,
      if (actorId != null) 'actor_id': actorId,
      if (actorUsername != null) 'actor_username': actorUsername,
      if (actorAvatarUrl != null) 'actor_avatar_url': actorAvatarUrl,
      'grouped_count': groupedCount,
      if (targetId != null) 'target_id': targetId,
      if (targetName != null) 'target_name': targetName,
      if (targetImageUrl != null) 'target_image_url': targetImageUrl,
      if (message != null) 'message': message,
    };
  }
}
