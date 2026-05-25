import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_providers.dart';
import '../auth/auth_providers.dart';
import '../friendship/friendship_providers.dart';

final eventGuestFilterProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final guests = await ref.watch(eventGuestsProvider(eventId).future);
  if (guests.isEmpty) return [];

  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return guests;

  final firestore = FirebaseFirestore.instance;
  final friendsConnections = await ref.watch(userFriendsProvider(currentUid).future);
  final friendUids = friendsConnections.map((c) => c['uid'] as String).toSet();
  
  final currentUserProfile = await ref.watch(userProfileStreamProvider(currentUid).future);
  final currentUserInterests = List<String>.from(currentUserProfile?['interests'] ?? []);

  final List<Map<String, dynamic>> populatedGuests = [];

  // Fetch full profiles for guests
  final futures = guests.map((guest) async {
    final uid = guest['uid'] as String?;
    if (uid == null) return null;

    final snap = await firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;

    return {
      ...guest, // contains rsvp_status etc.
      ...snap.data()!, // contains name, interests, etc.
      'uid': uid,
      'isFriend': friendUids.contains(uid),
    };
  });

  final results = await Future.wait(futures);
  populatedGuests.addAll(results.whereType<Map<String, dynamic>>());

  // Dual-Phase Sorting
  final friends = <Map<String, dynamic>>[];
  final nonFriends = <Map<String, dynamic>>[];

  for (final guest in populatedGuests) {
    if (guest['uid'] == currentUid) continue; // Skip current user

    if (guest['isFriend'] == true) {
      guest['computedSubtitle'] = 'Friends';
      friends.add(guest);
    } else {
      final guestInterests = List<String>.from(guest['interests'] ?? []);
      final intersection = guestInterests.where((i) => currentUserInterests.contains(i)).toList();
      guest['mutualInterestsCount'] = intersection.length;
      
      if (intersection.isNotEmpty) {
        final count = intersection.length - 1;
        guest['computedSubtitle'] = count > 0
            ? '${intersection.first} +$count other mutual interests'
            : '${intersection.first} mutual interest';
      } else {
        guest['computedSubtitle'] = '';
      }
      nonFriends.add(guest);
    }
  }

  friends.sort((a, b) {
    final nameA = (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
    final nameB = (b['name'] ?? b['username'] ?? '').toString().toLowerCase();
    return nameA.compareTo(nameB);
  });

  nonFriends.sort((a, b) {
    final countA = (a['mutualInterestsCount'] as int? ?? 0);
    final countB = (b['mutualInterestsCount'] as int? ?? 0);
    return countB.compareTo(countA); // Descending
  });

  return [...friends, ...nonFriends];
});
