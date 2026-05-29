import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_providers.dart';
import '../auth/auth_providers.dart';
import '../friendship/friendship_providers.dart';

final eventGuestFilterProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      eventId,
    ) async {
      final guests = await ref.watch(eventGuestsProvider(eventId).future);
      if (guests.isEmpty) return [];

      final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
      if (currentUid == null) return guests;

      final firestore = FirebaseFirestore.instance;
      final friendsConnections = await ref.watch(
        userFriendsProvider(currentUid).future,
      );
      final friendUids = friendsConnections
          .map((c) => c['uid'] as String)
          .toSet();

      final currentUserProfile = await ref.watch(
        userProfileStreamProvider(currentUid).future,
      );
      final currentUserInterests = List<String>.from(
        currentUserProfile?['interests'] ?? [],
      );

      final List<Map<String, dynamic>> populatedGuests = [];

      // Fetch full profiles for guests
      final futures = guests.map((guest) async {
        final uid = guest['uid'] as String?;
        if (uid == null) return null;

        final snap = await firestore.collection('users').doc(uid).get();
        if (!snap.exists) return null;

        return {
          ...guest, // contains status etc.
          ...snap.data()!, // contains name, interests, etc.
          'uid': uid,
          'isFriend': friendUids.contains(uid),
        };
      });

      final results = await Future.wait(futures);
      populatedGuests.addAll(results.whereType<Map<String, dynamic>>());

      // Dual-Phase Sorting (viewer pinned first on their RSVP tab)
      final friends = <Map<String, dynamic>>[];
      final nonFriends = <Map<String, dynamic>>[];
      Map<String, dynamic>? currentUserGuest;

      for (final guest in populatedGuests) {
        if (guest['uid'] == currentUid) {
          currentUserGuest = {
            ...guest,
            'computedSubtitle': 'You',
            'isCurrentUser': true,
          };
          continue;
        }

        if (guest['isFriend'] == true) {
          guest['computedSubtitle'] = 'Friends';
          friends.add(guest);
        } else {
          final username = guest['username'] as String? ?? '';
          guest['computedSubtitle'] = username.isNotEmpty ? username : '';

          final guestInterests = List<String>.from(guest['interests'] ?? []);
          final intersection = guestInterests
              .where((i) => currentUserInterests.contains(i))
              .toList();
          guest['mutualInterestsCount'] = intersection.length;
          nonFriends.add(guest);
        }
      }

      friends.sort((a, b) {
        final nameA = (a['name'] ?? a['username'] ?? '')
            .toString()
            .toLowerCase();
        final nameB = (b['name'] ?? b['username'] ?? '')
            .toString()
            .toLowerCase();
        return nameA.compareTo(nameB);
      });

      nonFriends.sort((a, b) {
        final countA = (a['mutualInterestsCount'] as int? ?? 0);
        final countB = (b['mutualInterestsCount'] as int? ?? 0);
        return countB.compareTo(countA); // Descending
      });

      final sorted = [...friends, ...nonFriends];
      if (currentUserGuest != null) {
        return [currentUserGuest, ...sorted];
      }
      return sorted;
    });
