import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledEvent {
  final String id;
  final String title;
  final String? posterUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String hostName;
  final String locationName;

  const ScheduledEvent({
    required this.id,
    required this.title,
    this.posterUrl,
    required this.startTime,
    required this.endTime,
    required this.hostName,
    required this.locationName,
  });

  factory ScheduledEvent.fromMap(Map<String, dynamic> map, String id) {
    return ScheduledEvent(
      id: id,
      title: map['title'] as String? ?? '',
      posterUrl: map['posterUrl'] as String?,
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostName: map['hostName'] as String? ?? '',
      locationName: map['locationName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (posterUrl != null) 'posterUrl': posterUrl,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'hostName': hostName,
      'locationName': locationName,
    };
  }
}
