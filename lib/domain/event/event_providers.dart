import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import 'event.dart';

final hostedEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(eventRepositoryProvider).getHostedEventsStream(user.uid);
});
