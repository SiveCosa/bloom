import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/event/event.dart';
import '../firebase_provider.dart';

class EventRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  EventRepository(this._firestore, this._storage);

  Future<String> uploadPoster(String eventId, Uint8List bytes) async {
    final ref = _storage.ref().child('posters').child(eventId).child('poster.webp');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/webp'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> createEvent(Event event) async {
    final docRef = event.id.isNotEmpty 
        ? _firestore.collection('events').doc(event.id)
        : _firestore.collection('events').doc();
    
    final eventWithId = event.copyWith(id: docRef.id);
    
    // Use a transaction or batch to ensure both happen or neither
    final batch = _firestore.batch();
    batch.set(docRef, eventWithId.toMap());
    
    // Increment hosted count for the user
    final userRef = _firestore.collection('users').doc(event.metadata.hostId);
    batch.set(userRef, {
      'counts': {
        'hosted': FieldValue.increment(1),
      }
    }, SetOptions(merge: true));
    
    await batch.commit();
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

  Stream<List<Event>> getHostedEventsStream(String userId) {
    return _firestore
        .collection('events')
        .where('metadata.hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
      // Sort in memory to avoid needing a composite index
      events.sort((a, b) => (b.metadata.createdAt).compareTo(a.metadata.createdAt));
      return events;
    });
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(storageProvider);
  return EventRepository(firestore, storage);
});
