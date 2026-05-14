import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_visibility.dart';
import 'event_location.dart';
import 'event_extra.dart';

enum EventStatus {
  active,
  cancelled,
  completed,
  draft,
}

class Event {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final EventVisuals visuals;
  final EventTiming timing;
  final EventLocation? location;
  final EventAudience audience;
  final List<EventExtra> extras;
  final List<String> rsvpReminders;
  final EventLiveCounts liveCounts;
  final List<String> previewGuests;
  final EventMetadata metadata;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.visuals,
    required this.timing,
    this.location,
    required this.audience,
    required this.extras,
    required this.rsvpReminders,
    required this.liveCounts,
    required this.previewGuests,
    required this.metadata,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    EventVisuals? visuals,
    EventTiming? timing,
    EventLocation? location,
    EventAudience? audience,
    EventLiveCounts? liveCounts,
    List<String>? previewGuests,
    List<EventExtra>? extras,
    List<String>? rsvpReminders,
    EventMetadata? metadata,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      visuals: visuals ?? this.visuals,
      timing: timing ?? this.timing,
      location: location ?? this.location,
      audience: audience ?? this.audience,
      liveCounts: liveCounts ?? this.liveCounts,
      previewGuests: previewGuests ?? this.previewGuests,
      extras: extras ?? this.extras,
      rsvpReminders: rsvpReminders ?? this.rsvpReminders,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'tags': tags,
      'visuals': visuals.toMap(),
      'timing': timing.toMap(),
      'location': location?.toMap(),
      'audience': audience.toMap(),
      'live_counts': liveCounts.toMap(),
      'preview_guests': previewGuests,
      'extras': extras.map((e) => e.toMap()).toList(),
      'rsvpReminders': rsvpReminders,
      'metadata': metadata.toMap(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map, String id) {
    return Event(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      visuals: EventVisuals.fromMap(map['visuals'] ?? {}),
      timing: EventTiming.fromMap(map['timing'] ?? {}),
      location: map['location'] != null ? EventLocation.fromMap(map['location']) : null,
      audience: EventAudience.fromMap(map['audience'] ?? {}),
      liveCounts: EventLiveCounts.fromMap(map['live_counts'] ?? {}),
      previewGuests: List<String>.from(map['preview_guests'] ?? []),
      extras: (map['extras'] as List? ?? []).map((e) => EventExtra.fromMap(e)).toList(),
      rsvpReminders: List<String>.from(map['rsvpReminders'] ?? []),
      metadata: EventMetadata.fromMap(map['metadata'] ?? {}),
    );
  }

  EventStatus get computedStatus {
    if (metadata.status == EventStatus.cancelled) return EventStatus.cancelled;
    if (metadata.status == EventStatus.draft) return EventStatus.draft;
    if (timing.isPast) return EventStatus.completed;
    return metadata.status;
  }

  String get statusLabel {
    final status = computedStatus;
    if (status == EventStatus.active) {
      if (timing.isOngoing) return 'LIVE NOW';
      return 'UPCOMING';
    }
    return status.name.toUpperCase();
  }

  // Simplified color helper for UI use
  int get statusColorValue {
    final status = computedStatus;
    switch (status) {
      case EventStatus.cancelled: return 0xFFFF4D4D; // Red
      case EventStatus.completed: return 0xFF8E8E93; // Gray
      case EventStatus.draft: return 0xFFFFD60A; // Yellow
      case EventStatus.active:
        if (timing.isOngoing) return 0xFF32D74B; // Green
        return 0xFFAD83FE; // Brand Purple
    }
  }

  bool get isFull {
    if (audience.capacity == null || audience.capacity == 0) return false;
    return liveCounts.going >= audience.capacity!;
  }

  bool get shouldShowWaitlist => isFull && audience.waitlistEnabled;
}

class EventLiveCounts {
  final int going;
  final int maybe;
  final int interested;

  const EventLiveCounts({
    this.going = 0,
    this.maybe = 0,
    this.interested = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'going': going,
      'maybe': maybe,
      'interested': interested,
    };
  }

  factory EventLiveCounts.fromMap(Map<String, dynamic> map) {
    return EventLiveCounts(
      going: map['going'] as int? ?? 0,
      maybe: map['maybe'] as int? ?? 0,
      interested: map['interested'] as int? ?? 0,
    );
  }
}

class EventVisuals {
  final String? posterUrl;
  final double aspectRatio;
  final List<String> auroraColors; // Hex strings

  const EventVisuals({
    this.posterUrl,
    required this.aspectRatio,
    required this.auroraColors,
  });

  EventVisuals copyWith({
    Object? posterUrl = _undefined,
    double? aspectRatio,
    List<String>? auroraColors,
  }) {
    return EventVisuals(
      posterUrl: posterUrl == _undefined ? this.posterUrl : (posterUrl as String?),
      aspectRatio: aspectRatio ?? this.aspectRatio,
      auroraColors: auroraColors ?? this.auroraColors,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (posterUrl != null) 'posterUrl': posterUrl,
      'aspectRatio': aspectRatio,
      'auroraColors': auroraColors,
    };
  }

  factory EventVisuals.fromMap(Map<String, dynamic> map) {
    return EventVisuals(
      posterUrl: map['posterUrl'] as String?,
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      auroraColors: List<String>.from(map['auroraColors'] ?? []),
    );
  }
}

class EventTiming {
  final DateTime? startDate;
  final bool startTimeTbd;
  final DateTime? endDate;
  final bool endTimeTbd;

  const EventTiming({
    this.startDate,
    this.startTimeTbd = true,
    this.endDate,
    this.endTimeTbd = true,
  });

  EventTiming copyWith({
    Object? startDate = _undefined,
    bool? startTimeTbd,
    Object? endDate = _undefined,
    bool? endTimeTbd,
  }) {
    return EventTiming(
      startDate: startDate == _undefined ? this.startDate : (startDate as DateTime?),
      startTimeTbd: startTimeTbd ?? this.startTimeTbd,
      endDate: endDate == _undefined ? this.endDate : (endDate as DateTime?),
      endTimeTbd: endTimeTbd ?? this.endTimeTbd,
    );
  }

  DateTime? get effectiveEndDate {
    if (endDate != null) return endDate;
    if (startDate == null) return null;
    // Default to end of day if no end date provided
    return DateTime(startDate!.year, startDate!.month, startDate!.day, 23, 59, 59);
  }

  bool get isUpcoming => startDate != null && DateTime.now().isBefore(startDate!);
  bool get isPast => effectiveEndDate != null && DateTime.now().isAfter(effectiveEndDate!);
  bool get isOngoing => !isUpcoming && !isPast && startDate != null;

  Map<String, dynamic> toMap() {
    return {
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      'startTimeTbd': startTimeTbd,
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'endTimeTbd': endTimeTbd,
    };
  }

  factory EventTiming.fromMap(Map<String, dynamic> map) {
    return EventTiming(
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      startTimeTbd: map['startTimeTbd'] as bool? ?? true,
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      endTimeTbd: map['endTimeTbd'] as bool? ?? true,
    );
  }
}

class EventAudience {
  final EventVisibility visibility;
  final int? capacity;
  final bool waitlistEnabled;
  final int maxPlusOnes;
  final bool requireApproval;
  final bool allowMaybe;
  final DateTime? rsvpDeadline;

  const EventAudience({
    required this.visibility,
    this.capacity,
    this.waitlistEnabled = false,
    this.maxPlusOnes = 0,
    this.requireApproval = false,
    this.allowMaybe = true,
    this.rsvpDeadline,
  });

  EventAudience copyWith({
    EventVisibility? visibility,
    Object? capacity = _undefined,
    bool? waitlistEnabled,
    int? maxPlusOnes,
    bool? requireApproval,
    bool? allowMaybe,
    Object? rsvpDeadline = _undefined,
  }) {
    return EventAudience(
      visibility: visibility ?? this.visibility,
      capacity: capacity == _undefined ? this.capacity : (capacity as int?),
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      maxPlusOnes: maxPlusOnes ?? this.maxPlusOnes,
      requireApproval: requireApproval ?? this.requireApproval,
      allowMaybe: allowMaybe ?? this.allowMaybe,
      rsvpDeadline: rsvpDeadline == _undefined ? this.rsvpDeadline : (rsvpDeadline as DateTime?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visibility': visibility.name,
      if (capacity != null) 'capacity': capacity,
      'waitlistEnabled': waitlistEnabled,
      'maxPlusOnes': maxPlusOnes,
      'requireApproval': requireApproval,
      'allowMaybe': allowMaybe,
      if (rsvpDeadline != null) 'rsvpDeadline': Timestamp.fromDate(rsvpDeadline!),
    };
  }

  factory EventAudience.fromMap(Map<String, dynamic> map) {
    return EventAudience(
      visibility: EventVisibility.values.firstWhere(
        (e) => e.name == map['visibility'],
        orElse: () => EventVisibility.public,
      ),
      capacity: map['capacity'] as int?,
      waitlistEnabled: map['waitlistEnabled'] as bool? ?? false,
      maxPlusOnes: map['maxPlusOnes'] as int? ?? 0,
      requireApproval: map['requireApproval'] as bool? ?? false,
      allowMaybe: map['allowMaybe'] as bool? ?? true,
      rsvpDeadline: (map['rsvpDeadline'] as Timestamp?)?.toDate(),
    );
  }
}

class EventMetadata {
  final String hostId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventStatus status;

  const EventMetadata({
    required this.hostId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  EventMetadata copyWith({
    String? hostId,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventStatus? status,
  }) {
    return EventMetadata(
      hostId: hostId ?? this.hostId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.name,
    };
  }

  factory EventMetadata.fromMap(Map<String, dynamic> map) {
    return EventMetadata(
      hostId: map['hostId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: EventStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => EventStatus.active,
      ),
    );
  }
}

const _undefined = Object();
