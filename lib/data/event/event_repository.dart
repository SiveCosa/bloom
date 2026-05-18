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
    
    // Operation 1: Main Event
    batch.set(docRef, eventWithId.toMap());
    
    // Operation 2: Host Schedule (Denormalized)
    final scheduleRef = _firestore
        .collection('users')
        .doc(event.metadata.hostId)
        .collection('schedule')
        .doc(docRef.id);
        
    final scheduleData = <String, dynamic>{
      'eventId': docRef.id,
      'event_id': docRef.id,
      'title': event.title,
      'hostId': event.metadata.hostId,
      'host_id': event.metadata.hostId,
      'hostName': 'Me', 
      'host_name': 'Me',
      if (event.timing.startDate != null) 'startTime': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.startDate != null) 'start_time': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.endDate != null) 'endTime': Timestamp.fromDate(event.timing.endDate!),
      if (event.timing.endDate != null) 'end_time': Timestamp.fromDate(event.timing.endDate!),
      if (event.visuals.posterUrl != null) 'posterUrl': event.visuals.posterUrl,
      if (event.visuals.posterUrl != null) 'poster_url': event.visuals.posterUrl,
      'auroraColors': event.visuals.auroraColors,
      'aurora_colors': event.visuals.auroraColors,
      if (event.location != null) 'locationName': event.location!.displayName,
      if (event.location != null) 'location_name': event.location!.displayName,
      if (event.location != null) 'subtitle_info': event.location!.displayName,
    };
    batch.set(scheduleRef, scheduleData);
    
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
    final batch = _firestore.batch();
    batch.set(_firestore.collection('events').doc(event.id), event.toMap(), SetOptions(merge: true));
    
    final scheduleRef = _firestore
        .collection('users')
        .doc(event.metadata.hostId)
        .collection('schedule')
        .doc(event.id);
        
    final scheduleData = <String, dynamic>{
      'title': event.title,
      if (event.timing.startDate != null) 'startTime': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.startDate != null) 'start_time': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.endDate != null) 'endTime': Timestamp.fromDate(event.timing.endDate!),
      if (event.timing.endDate != null) 'end_time': Timestamp.fromDate(event.timing.endDate!),
      if (event.visuals.posterUrl != null) 'posterUrl': event.visuals.posterUrl,
      if (event.visuals.posterUrl != null) 'poster_url': event.visuals.posterUrl,
      'auroraColors': event.visuals.auroraColors,
      'aurora_colors': event.visuals.auroraColors,
      if (event.location != null) 'locationName': event.location!.displayName,
      if (event.location != null) 'location_name': event.location!.displayName,
      if (event.location != null) 'subtitle_info': event.location!.displayName,
    };
    batch.set(scheduleRef, scheduleData, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteEvent(Event event) async {
    // Delete the poster image from Firebase Storage if it has one
    if (event.visuals.posterUrl != null && event.visuals.posterUrl!.isNotEmpty) {
      try {
        final ref = _storage.ref().child('posters').child(event.id).child('poster.webp');
        await ref.delete();
      } catch (e) {
        // If file doesn't exist or deletion fails, log and continue
        debugPrint('Failed to delete event poster from Storage: $e');
      }
    }

    final batch = _firestore.batch();
    
    // Remove from main collection
    batch.delete(_firestore.collection('events').doc(event.id));
    
    // Remove from host schedule
    batch.delete(_firestore
        .collection('users')
        .doc(event.metadata.hostId)
        .collection('schedule')
        .doc(event.id));
        
    // Decrement hosted count for the user
    final userRef = _firestore.collection('users').doc(event.metadata.hostId);
    batch.set(userRef, {
      'counts': {
        'hosted': FieldValue.increment(-1),
      }
    }, SetOptions(merge: true));
    
    await batch.commit();
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

  Stream<List<Map<String, dynamic>>> getScheduleStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('schedule')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> getUpcomingScheduleStream(String userId) {
    final now = DateTime.now();
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('schedule')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('startTime', descending: false)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Stream<Event?> getEventStream(String id) {
    return _firestore.collection('events').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Event.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> updateRSVPReminders(String eventId, List<String> reminders) async {
    await _firestore.collection('events').doc(eventId).update({
      'rsvpReminders': reminders,
    });
  }

  Future<void> updateRSVP(String eventId, String userId, String status) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('guests')
        .doc(userId)
        .set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<String?> getUserRSVPStream(String eventId, String userId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('guests')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['status'] as String?);
  }

  Stream<List<Map<String, dynamic>>> getEventGuestsStream(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('guests')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'uid': doc.id}).toList());
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(storageProvider);
  return EventRepository(firestore, storage);
});
