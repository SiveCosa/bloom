import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import 'event.dart';

final hostedEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(eventRepositoryProvider).getHostedEventsStream(user.uid);
});

final eventStreamProvider = StreamProvider.family<Event?, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEventStream(eventId);
});

final userEventRsvpProvider = StreamProvider.family<String?, String>((ref, eventId) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(null);
  return ref.watch(eventRepositoryProvider).getUserRSVPStream(eventId, user.uid);
});

final eventGuestsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEventGuestsStream(eventId);
});
