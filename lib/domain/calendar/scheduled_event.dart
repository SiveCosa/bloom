import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledEvent {
  final String id;
  final String title;
  final String? posterUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String hostName;
  final String hostId;
  final String? hostImageUrl;
  final List<String> auroraColors;
  final String locationName;

  const ScheduledEvent({
    required this.id,
    required this.title,
    this.posterUrl,
    required this.startTime,
    required this.endTime,
    required this.hostName,
    required this.hostId,
    this.hostImageUrl,
    required this.auroraColors,
    required this.locationName,
  });

  factory ScheduledEvent.fromMap(Map<String, dynamic> map, String id) {
    return ScheduledEvent(
      id: id,
      title: map['title'] as String? ?? '',
      posterUrl: map['posterUrl'] as String? ?? map['poster_url'] as String?,
      startTime: (map['startTime'] as Timestamp? ?? map['start_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp? ?? map['end_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostName: map['hostName'] as String? ?? map['host_name'] as String? ?? '',
      hostId: map['hostId'] as String? ?? map['host_id'] as String? ?? '',
      hostImageUrl: map['hostImageUrl'] as String? ?? map['host_image_url'] as String?,
      auroraColors: List<String>.from(map['auroraColors'] ?? map['aurora_colors'] ?? []),
      locationName: map['locationName'] as String? ?? map['location_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (posterUrl != null) 'posterUrl': posterUrl,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'hostName': hostName,
      'hostId': hostId,
      if (hostImageUrl != null) 'hostImageUrl': hostImageUrl,
      'auroraColors': auroraColors,
      'locationName': locationName,
    };
  }
}
