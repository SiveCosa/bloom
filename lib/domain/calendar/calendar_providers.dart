import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import 'scheduled_event.dart';

enum CalendarFormat { month, week }

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void updateDate(DateTime date) => state = date;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(() {
  return SelectedDateNotifier();
});

class CalendarFormatNotifier extends Notifier<CalendarFormat> {
  @override
  CalendarFormat build() => CalendarFormat.month;

  void updateFormat(CalendarFormat format) => state = format;
}

final calendarFormatProvider = NotifierProvider<CalendarFormatNotifier, CalendarFormat>(() {
  return CalendarFormatNotifier();
});

final scheduleStreamProvider = StreamProvider<List<ScheduledEvent>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  final repository = ref.watch(eventRepositoryProvider);
  return repository.getScheduleStream(user.uid).map((list) {
    return list.map((data) => ScheduledEvent.fromMap(data, data['id'] as String)).toList();
  });
});
