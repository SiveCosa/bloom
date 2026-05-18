import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'friendship_models.dart';

final connectionStateProvider = StreamProvider.family<FriendshipState, String>((ref, targetUid) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value(FriendshipState.none);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .doc(targetUid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return FriendshipState.none;
        final data = snap.data();
        if (data == null) return FriendshipState.none;
        final status = data['status'] as String?;
        if (status == 'pending') {
          final initiatedBy = data['initiated_by'] as String?;
          if (initiatedBy == currentUid) {
            return FriendshipState.sentPending;
          } else {
            return FriendshipState.receivedPending;
          }
        }
        if (status == 'connected') return FriendshipState.connected;
        return FriendshipState.none;
      });
});

final userFriendsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, targetUid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('connections')
      .where('status', isEqualTo: 'connected')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList();
      });
});

final recommendedFriendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
    final result = await functions.httpsCallable('getFriendRecommendations').call();
    
    final data = result.data as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('Error fetching recommendations: $e');
    return [];
  }
});

class DismissedRecommendationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void dismiss(String uid) {
    state = {...state, uid};
  }
}

final dismissedRecommendationsProvider = NotifierProvider<DismissedRecommendationsNotifier, Set<String>>(() {
  return DismissedRecommendationsNotifier();
});

final recommendedFriendAffinityProvider = FutureProvider.family<String, String>((ref, targetUid) async {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return '';

  final firestore = FirebaseFirestore.instance;

  try {
    // Fetch in parallel: current user, target user, current connections, target connections
    final futures = await Future.wait([
      firestore.collection('users').doc(currentUid).get(),
      firestore.collection('users').doc(targetUid).get(),
      firestore.collection('users').doc(currentUid).collection('connections').where('status', isEqualTo: 'connected').get(),
      firestore.collection('users').doc(targetUid).collection('connections').where('status', isEqualTo: 'connected').get(),
    ]);

    final currentUserDoc = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
    final targetUserDoc = futures[1] as DocumentSnapshot<Map<String, dynamic>>;
    final currentConnectionsSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;
    final targetConnectionsSnap = futures[3] as QuerySnapshot<Map<String, dynamic>>;

    if (!currentUserDoc.exists || !targetUserDoc.exists) {
      return '';
    }

    final currentUserData = currentUserDoc.data()!;
    final targetUserData = targetUserDoc.data()!;

    // 1. Check Mutual Connections
    final currentFriendUids = currentConnectionsSnap.docs.map((d) => d.id).toSet();
    final targetFriendUids = targetConnectionsSnap.docs.map((d) => d.id).toSet();
    final mutualFriendUids = currentFriendUids.intersection(targetFriendUids);

    if (mutualFriendUids.isNotEmpty) {
      if (mutualFriendUids.length == 1) {
        return "1 mutual friend";
      }
      return "${mutualFriendUids.length} mutual friends";
    }

    // 2. Check Shared Interests
    final currentUserInterests = List<String>.from(currentUserData['interests'] ?? []);
    final targetUserInterests = List<String>.from(targetUserData['interests'] ?? []);
    final sharedInterests = currentUserInterests.toSet().intersection(targetUserInterests.toSet());

    if (sharedInterests.isNotEmpty) {
      final first = sharedInterests.first;
      final others = sharedInterests.length - 1;
      if (others > 0) {
        return "Into $first +$others other mutual interest${others > 1 ? 's' : ''}";
      } else {
        return "Into $first";
      }
    }

    // 3. Check Same Campus
    final currentUserCampus = currentUserData['campus'] as String? ?? '';
    final targetUserCampus = targetUserData['campus'] as String? ?? '';
    if (currentUserCampus.isNotEmpty && currentUserCampus == targetUserCampus) {
      return "At $currentUserCampus";
    }

    // 4. Check Event Affiliation
    final now = Timestamp.now();
    final scheduleSnap = await firestore
        .collection('users')
        .doc(targetUid)
        .collection('schedule')
        .where('startTime', isGreaterThanOrEqualTo: now)
        .orderBy('startTime', descending: false)
        .limit(1)
        .get();

    if (scheduleSnap.docs.isNotEmpty) {
      final eventTitle = scheduleSnap.docs.first.data()['title'] ?? 'an event';
      return "Attending $eventTitle tonight";
    }

    return '';
  } catch (e) {
    debugPrint('Error calculating affinity: $e');
    return '';
  }
});

/// Stream provider for incoming pending friend requests
final incomingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .where((data) => data['initiated_by'] != currentUid)
            .toList();
      });
});

/// Stream provider for the count of incoming pending friend requests
final incomingRequestsCountProvider = StreamProvider<int>((ref) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .where((data) => data['initiated_by'] != currentUid)
            .length;
      });
});

/// Stream provider for outgoing pending friend requests
final outgoingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .where((data) => data['initiated_by'] == currentUid)
            .toList();
      });
});

/// Stream provider for the count of outgoing pending friend requests
final outgoingRequestsCountProvider = StreamProvider<int>((ref) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .where((data) => data['initiated_by'] == currentUid)
            .length;
      });
});

/// Stream provider for accepted friends (status == 'connected')
final friendsMadeProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (currentUid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('connections')
      .where('status', isEqualTo: 'connected')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList();
      });
});



