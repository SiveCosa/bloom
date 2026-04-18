import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';

class FirebaseProvider {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Firebase App Check Enforcement
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use`n      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use`n      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  }
}
