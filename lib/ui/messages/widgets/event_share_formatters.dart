import 'package:intl/intl.dart';

import '../../../domain/event/event.dart';

String formatEventShareDate(DateTime? start) {
  if (start == null) return 'Date TBD';
  return DateFormat('EEE, d MMM').format(start);
}

String formatEventShareSubtitle(Event event) {
  final date = formatEventShareDate(event.timing.startDate);
  final location = event.location?.displayName ?? 'Location TBD';
  return '$date • $location';
}

String formatEventShareSubtitleFromPayload(Map<String, dynamic> data) {
  final date = data['date']?.toString() ?? 'Date TBD';
  final location = data['location']?.toString() ?? 'Location TBD';
  return '$date • $location';
}

Map<String, dynamic> buildEventSharePayload(
  Event event, {
  required String attachedMessage,
}) {
  return {
    'eventId': event.id,
    'eventName': event.title,
    'posterUrl': event.visuals.posterUrl ?? '',
    'date': formatEventShareDate(event.timing.startDate),
    'location': event.location?.displayName ?? 'Location TBD',
    'attachedMessage': attachedMessage,
  };
}