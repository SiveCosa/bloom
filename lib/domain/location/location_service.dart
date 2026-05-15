import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:bloom/data/firebase_provider.dart';

class LocationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  LocationService(this._firestore, this._auth);

  Future<void> updateUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );

      final user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'location': GeoPoint(position.latitude, position.longitude),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating user location: $e');
    }
  }
}

final locationServiceProvider = Provider((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return LocationService(firestore, auth);
});
