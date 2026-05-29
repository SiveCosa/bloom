import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class ConnectionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ConnectionRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Send a connection request to the target user.
  Future<void> sendRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    
    final currentUserConnRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('connections')
        .doc(targetUserId);
        
    final targetUserConnRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('connections')
        .doc(currentUserId);

    batch.set(currentUserConnRef, {
      'status': 'pending',
      'initiated_by': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.set(targetUserConnRef, {
      'status': 'pending',
      'initiated_by': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Accept an incoming connection request (both users updated on the server).
  Future<void> acceptRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
    final callable = functions.httpsCallable('acceptConnection');
    await callable.call(<String, dynamic>{'targetUserId': targetUserId});
  }

  /// Remove a connection or cancel a pending request.
  Future<void> removeConnection(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final currentUserConnRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('connections')
        .doc(targetUserId);

    final snap = await currentUserConnRef.get();
    final isAlreadyConnected = snap.exists && snap.data()?['status'] == 'connected';

    final batch = _firestore.batch();
    
    final targetUserConnRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('connections')
        .doc(currentUserId);

    batch.delete(currentUserConnRef);
    batch.delete(targetUserConnRef);

    // If they were friends, decrement the counts safely (avoid going below 0 for legacy users)
    if (isAlreadyConnected) {
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      
      final currentUserDoc = await currentUserRef.get();
      final targetUserDoc = await targetUserRef.get();

      final currentFriendsCount = (currentUserDoc.data()?['counts'] as Map?)?['friends'] as num? ?? 0;
      final targetFriendsCount = (targetUserDoc.data()?['counts'] as Map?)?['friends'] as num? ?? 0;

      if (currentFriendsCount > 0) {
        batch.update(currentUserRef, {
          'counts.friends': FieldValue.increment(-1),
        });
      }
      if (targetFriendsCount > 0) {
        batch.update(targetUserRef, {
          'counts.friends': FieldValue.increment(-1),
        });
      }
    }

    await batch.commit();
  }
}
