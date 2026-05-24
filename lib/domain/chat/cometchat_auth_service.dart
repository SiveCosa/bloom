import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CometChatAuthService {
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'africa-south1');

  static Future<void> registerAndLogin({required String name}) async {
    final callable = _functions.httpsCallable('cometChatCreateUser');
    final result = await callable.call({'name': name});
    final data = Map<String, dynamic>.from(result.data as Map);
    final token = data['authToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('CometChat signup failed: no auth token returned.');
    }
    await _loginWithAuthToken(token);
  }

  static Future<void>? _loginFuture;

  static Future<void> loginWithFirebaseSession() async {
    if (_loginFuture != null) return _loginFuture;
    _loginFuture = _loginWithFirebaseSessionInternal();
    try {
      await _loginFuture;
    } finally {
      _loginFuture = null;
    }
  }

  static Future<void> _loginWithFirebaseSessionInternal() async {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null) {
      throw Exception('Must be signed in to Firebase before CometChat login.');
    }

    final loggedIn = await cc.CometChat.getLoggedInUser();
    if (loggedIn?.uid.toLowerCase() == firebaseUid.toLowerCase()) {
      return;
    }

    final callable = _functions.httpsCallable('cometChatGetAuthToken');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final token = data['authToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('CometChat login failed: no auth token returned.');
    }
    await _loginWithAuthToken(token);
  }

  static Future<void> logout() async {
    final loggedIn = await cc.CometChat.getLoggedInUser();
    if (loggedIn == null) return;

    final completer = Completer<void>();
    await cc.CometChat.logout(
      onSuccess: (String message) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (cc.CometChatException e) {
        debugPrint('CometChat logout error: ${e.message}');
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    await completer.future;
  }

  static Future<void> _loginWithAuthToken(String authToken) async {
    final completer = Completer<cc.User>();
    
    await cc.CometChat.loginWithAuthToken(
      authToken,
      onSuccess: (cc.User user) {
        if (!completer.isCompleted) completer.complete(user);
      },
      onError: (cc.CometChatException e) {
        if (!completer.isCompleted) completer.completeError(Exception('CometChat login failed: ${e.message}'));
      },
    );

    final user = await completer.future;
    debugPrint('CometChat login success: ${user.uid}');
  }
}
