import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/event/event.dart';
import '../../domain/calendar/scheduled_event.dart';
import '../firebase_provider.dart';

class EventRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  EventRepository(this._firestore, this._storage);

  Map<String, dynamic> _schedulePayload(
    Event event,
    String eventId, {
    String hostName = 'Me',
    String? rsvpStatus,
  }) {
    return {
      'eventId': eventId,
      'event_id': eventId,
      'title': event.title,
      'hostId': event.metadata.hostId,
      'host_id': event.metadata.hostId,
      'hostName': hostName,
      'host_name': hostName,
      if (event.timing.startDate != null)
        'startTime': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.startDate != null)
        'start_time': Timestamp.fromDate(event.timing.startDate!),
      if (event.timing.endDate != null) 'endTime': Timestamp.fromDate(event.timing.endDate!),
      if (event.timing.endDate != null) 'end_time': Timestamp.fromDate(event.timing.endDate!),
      if (event.visuals.posterUrl != null) 'posterUrl': event.visuals.posterUrl,
      if (event.visuals.posterUrl != null) 'poster_url': event.visuals.posterUrl,
      'auroraColors': event.visuals.auroraColors,
      'aurora_colors': event.visuals.auroraColors,
      if (event.location != null) 'locationName': event.location!.displayName,
      if (event.location != null) 'location_name': event.location!.displayName,
      if (event.location != null) 'subtitle_info': event.location!.displayName,
      'co_host_ids': event.coHostIds,
      'coHostIds': event.coHostIds,
      if (rsvpStatus != null) 'rsvp_status': rsvpStatus,
      if (rsvpStatus != null) 'rsvpStatus': rsvpStatus,
    };
  }

  void _writeSchedulesForHostAndCoHosts(
    WriteBatch batch,
    Event event,
    String eventId, {
    String hostName = 'Me',
  }) {
    final participantIds = {event.metadata.hostId, ...event.coHostIds};
    for (final uid in participantIds) {
      if (uid.isEmpty) continue;
      final ref = _firestore.collection('users').doc(uid).collection('schedule').doc(eventId);
      batch.set(ref, _schedulePayload(event, eventId, hostName: hostName));
    }
  }

  List<Event> _parseEventDocs(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final events = <Event>[];
    for (final doc in docs) {
      try {
        events.add(Event.fromMap(doc.data(), doc.id));
      } catch (e, stack) {
        debugPrint('Failed to parse event ${doc.id}: $e\n$stack');
      }
    }
    return events;
  }

  List<Event> _mergeEventsById(List<Event> a, List<Event> b) {
    final byId = <String, Event>{};
    for (final e in [...a, ...b]) {
      byId[e.id] = e;
    }
    final merged = byId.values.toList();
    merged.sort((x, y) => y.metadata.createdAt.compareTo(x.metadata.createdAt));
    return merged;
  }

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
    
    _writeSchedulesForHostAndCoHosts(batch, eventWithId, docRef.id);
    
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
    
    _writeSchedulesForHostAndCoHosts(batch, event, event.id, hostName: 'Me');
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
    
    final scheduleParticipantIds = {event.metadata.hostId, ...event.coHostIds};
    for (final uid in scheduleParticipantIds) {
      if (uid.isEmpty) continue;
      batch.delete(
        _firestore.collection('users').doc(uid).collection('schedule').doc(event.id),
      );
    }
        
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
    if (id.trim().isEmpty) return null;
    final doc = await _firestore.collection('events').doc(id).get();
    if (!doc.exists) return null;
    try {
      return Event.fromMap(doc.data()!, doc.id);
    } catch (e, stack) {
      debugPrint('Failed to parse event ${doc.id}: $e\n$stack');
      return null;
    }
  }

  Stream<List<Event>> getHostedEventsStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('events')
        .where('metadata.hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final events = _parseEventDocs(snapshot.docs);
      events.sort((a, b) => b.metadata.createdAt.compareTo(a.metadata.createdAt));
      return events;
    });
  }

  Stream<List<Event>> getCoHostedEventsStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('events')
        .where('co_host_ids', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final events = _parseEventDocs(snapshot.docs);
      events.sort((a, b) => b.metadata.createdAt.compareTo(a.metadata.createdAt));
      return events;
    });
  }

  Stream<List<Event>> getHostedAndCoHostedEventsStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value([]);

    final controller = StreamController<List<Event>>();
    List<Event>? hosted;
    List<Event>? coHosted;

    void emitMerged() {
      if (hosted == null || coHosted == null) return;
      if (!controller.isClosed) {
        controller.add(_mergeEventsById(hosted!, coHosted!));
      }
    }

    final hostSub = _firestore
        .collection('events')
        .where('metadata.hostId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      hosted = _parseEventDocs(snap.docs);
      emitMerged();
    }, onError: controller.addError);

    final coSub = _firestore
        .collection('events')
        .where('co_host_ids', arrayContains: userId)
        .snapshots()
        .listen((snap) {
      coHosted = _parseEventDocs(snap.docs);
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () {
      hostSub.cancel();
      coSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getScheduleStream(String profileUserId) {
    if (profileUserId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(profileUserId)
        .collection('schedule')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  static const int publicProfileUpcomingLimit = 10;

  /// Upcoming joining + hosting events for [profileUserId] (not the signed-in viewer).
  Stream<List<ScheduledEvent>> watchProfileUpcomingEvents(
    String profileUserId, {
    String profileDisplayName = '',
  }) {
    if (profileUserId.trim().isEmpty) return Stream.value([]);

    final controller = StreamController<List<ScheduledEvent>>();
    List<ScheduledEvent>? scheduleEvents;
    List<Event>? hostedEvents;

    void emitMerged() {
      if (scheduleEvents == null || hostedEvents == null) return;
      if (controller.isClosed) return;

      final now = DateTime.now();
      final result = scheduleEvents!
          .where((e) {
            final status = e.rsvpStatus;
            if (status == 'maybe' || status == 'interested') return false;
            return status == null || status == 'going';
          })
          .where((e) => e.endTime.isAfter(now))
          .toList();

      final seenIds = result.map((e) => e.id).toSet();

      for (final event in hostedEvents!) {
        if (seenIds.contains(event.id)) continue;
        final end = event.timing.effectiveEndDate ??
            event.timing.startDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!end.isAfter(now)) continue;

        result.add(
          ScheduledEvent(
            id: event.id,
            title: event.title,
            posterUrl: event.visuals.posterUrl,
            startTime: event.timing.startDate,
            endTime: end,
            hostName: event.metadata.hostId == profileUserId
                ? profileDisplayName
                : '',
            hostId: event.metadata.hostId,
            auroraColors: event.visuals.auroraColors,
            locationName: event.location?.displayName ?? '',
            coHostIds: event.coHostIds,
          ),
        );
        seenIds.add(event.id);
      }

      result.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return a.startTime!.compareTo(b.startTime!);
      });

      controller.add(result.take(publicProfileUpcomingLimit).toList());
    }

    final scheduleSub = getScheduleStream(profileUserId).listen(
      (list) {
        scheduleEvents = list
            .map((data) => ScheduledEvent.fromMap(data, data['id'] as String))
            .toList();
        emitMerged();
      },
      onError: controller.addError,
    );

    final hostedSub = getHostedAndCoHostedEventsStream(profileUserId).listen(
      (events) {
        hostedEvents = events;
        emitMerged();
      },
      onError: controller.addError,
    );

    controller.onCancel = () {
      scheduleSub.cancel();
      hostedSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getUpcomingScheduleStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value([]);
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
    if (id.trim().isEmpty) return Stream.value(null);
    return _firestore.collection('events').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return Event.fromMap(doc.data()!, doc.id);
      } catch (e, stack) {
        debugPrint('Failed to parse event ${doc.id}: $e\n$stack');
        return null;
      }
    });
  }

  Future<void> updateRSVPReminders(String eventId, List<String> reminders) async {
    if (eventId.trim().isEmpty) return;
    await _firestore.collection('events').doc(eventId).update({
      'rsvpReminders': reminders,
    });
  }

  Future<void> updateRSVP(String eventId, String userId, String status) async {
    if (eventId.trim().isEmpty || userId.trim().isEmpty) return;
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

  Future<void> removeRSVP(String eventId, String userId) async {
    if (eventId.trim().isEmpty || userId.trim().isEmpty) return;
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('guests')
        .doc(userId)
        .delete();
  }

  Stream<String?> getUserRSVPStream(String eventId, String userId) {
    if (eventId.trim().isEmpty || userId.trim().isEmpty) return Stream.value(null);
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('guests')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['status'] as String?);
  }

  Stream<List<Map<String, dynamic>>> getEventGuestsStream(String eventId) {
    if (eventId.trim().isEmpty) return Stream.value([]);
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
