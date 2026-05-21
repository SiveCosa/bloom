import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledEvent {
  final String id;
  final String title;
  final String? posterUrl;
  final DateTime? startTime;
  final DateTime endTime;
  final String hostName;
  final String hostId;
  final String? hostImageUrl;
  final List<String> auroraColors;
  final String locationName;
  final List<String> coHostIds;
  final String? rsvpStatus;

  bool get isOngoing {
    if (startTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(startTime!) && now.isBefore(endTime);
  }

  bool get isPast => DateTime.now().isAfter(endTime);

  const ScheduledEvent({
    required this.id,
    required this.title,
    this.posterUrl,
    this.startTime,
    required this.endTime,
    required this.hostName,
    required this.hostId,
    this.hostImageUrl,
    required this.auroraColors,
    required this.locationName,
    this.coHostIds = const [],
    this.rsvpStatus,
  });

  factory ScheduledEvent.fromMap(Map<String, dynamic> map, String id) {
    final start = (map['startTime'] as Timestamp? ?? map['start_time'] as Timestamp?)?.toDate();
    final location = map['locationName'] as String? ?? map['location_name'] as String? ?? map['subtitle_info'] as String? ?? '';
    
    return ScheduledEvent(
      id: id,
      title: map['title'] as String? ?? '',
      posterUrl: map['posterUrl'] as String? ?? map['poster_url'] as String?,
      startTime: start,
      endTime: (map['endTime'] as Timestamp? ?? map['end_time'] as Timestamp?)?.toDate() ?? 
               (start != null ? DateTime(start.year, start.month, start.day, 23, 59, 59) : DateTime.now()),
      hostName: map['hostName'] as String? ?? map['host_name'] as String? ?? '',
      hostId: map['hostId'] as String? ?? map['host_id'] as String? ?? '',
      hostImageUrl: map['hostImageUrl'] as String? ?? map['host_image_url'] as String?,
      auroraColors: List<String>.from(map['auroraColors'] ?? map['aurora_colors'] ?? []),
      locationName: location,
      coHostIds: List<String>.from(map['coHostIds'] ?? map['co_host_ids'] ?? []),
      rsvpStatus: map['rsvpStatus'] as String? ?? map['rsvp_status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (posterUrl != null) 'posterUrl': posterUrl,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime!),
      'endTime': Timestamp.fromDate(endTime),
      'hostName': hostName,
      'hostId': hostId,
      if (hostImageUrl != null) 'hostImageUrl': hostImageUrl,
      'auroraColors': auroraColors,
      'locationName': locationName,
      if (coHostIds.isNotEmpty) 'coHostIds': coHostIds,
      if (rsvpStatus != null) 'rsvpStatus': rsvpStatus,
    };
  }
}
