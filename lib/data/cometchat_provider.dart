import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/foundation.dart';

import '../core/config/cometchat_config.dart';

class CometChatProvider {
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static bool get isInitialized => _initialized;

  /// Initializes the CometChat SDK once per app run (after config is resolved).
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;

    if (!CometChatConfig.isConfigured) {
      throw Exception(
        'CometChat App ID is not configured. '
        'Set COMETCHAT_APP_ID in functions/.env or use --dart-define.',
      );
    }

    final completer = Completer<void>();
    _initFuture = completer.future;

    final appSettings = (cc.AppSettingsBuilder()
          ..subscriptionType = cc.CometChatSubscriptionType.allUsers
          ..region = CometChatConfig.effectiveRegion
          ..autoEstablishSocketConnection = true)
        .build();

    await cc.CometChat.init(
      CometChatConfig.effectiveAppId,
      appSettings,
      onSuccess: (String message) {
        debugPrint('CometChat init success: $message');
        if (!completer.isCompleted) completer.complete();
      },
      onError: (cc.CometChatException e) {
        debugPrint('CometChat init failed: ${e.message}');
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(e.message ?? 'CometChat initialization failed'),
          );
        }
      },
    );

    try {
      await _initFuture;
      _initialized = true;
    } catch (e) {
      _initFuture = null; // Allow retry on failure
      rethrow;
    }
  }

  static void reset() {
    _initialized = false;
    _initFuture = null;
    CometChatConfig.clearResolved();
  }
}