import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/foundation.dart';

import '../core/config/cometchat_config.dart';

class CometChatProvider {
  static Future<void> initialize() async {
    final completer = Completer<void>();

    final appSettings = (cc.AppSettingsBuilder()
          ..subscriptionType = cc.CometChatSubscriptionType.allUsers
          ..region = CometChatConfig.region
          ..autoEstablishSocketConnection = true)
        .build();

    await cc.CometChat.init(
      CometChatConfig.appId,
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

    return completer.future;
  }
}
