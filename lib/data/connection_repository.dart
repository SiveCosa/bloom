import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Accept an incoming connection request.
  Future<void> acceptRequest(String targetUserId) async {
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

    batch.update(currentUserConnRef, {
      'status': 'connected',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(targetUserConnRef, {
      'status': 'connected',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Remove a connection or cancel a pending request.
  Future<void> removeConnection(String targetUserId) async {
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

    batch.delete(currentUserConnRef);
    batch.delete(targetUserConnRef);

    await batch.commit();
  }
}
