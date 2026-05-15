import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

class FirebaseProvider {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Initialize App Check in the background to avoid blocking the main thread
    unawaited(FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    ));
  }
}

// Helper to avoid lints for unawaited futures
void unawaited(Future<void> future) {}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});
