import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/event/event.dart';
import '../firebase_provider.dart';

class EventRepository {
  final FirebaseFirestore _firestore;

  EventRepository(this._firestore);

  Future<String> createEvent(Event event) async {
    final docRef = _firestore.collection('events').doc();
    final eventWithId = event.copyWith(id: docRef.id);
    
    await docRef.set(eventWithId.toMap());
    
    return docRef.id;
  }

  Future<void> updateEvent(Event event) async {
    await _firestore.collection('events').doc(event.id).update(event.toMap());
  }

  Future<Event?> getEvent(String id) async {
    final doc = await _firestore.collection('events').doc(id).get();
    if (!doc.exists) return null;
    return Event.fromMap(doc.data()!, doc.id);
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return EventRepository(firestore);
});
