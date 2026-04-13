import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class FirebaseProvider {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Firebase App Check Enforcement
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  }
}
