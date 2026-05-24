import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/cometchat_config.dart';
import '../../data/cometchat_provider.dart';
import 'cometchat_auth_service.dart';
import 'cometchat_config_loader.dart';

const Duration kChatSendTimeout = Duration(seconds: 25);

String? lastChatSendError;

void _logCometChatError(String action, CometChatException e) {
  final message = '${e.code}: ${e.message ?? 'unknown'}';
  lastChatSendError = message;
  debugPrint('CometChat $action failed: $message');
}

Future<BaseMessage?> sendTextMessageSafe(TextMessage message) async {
  lastChatSendError = null;
  try {
    final completer = Completer<BaseMessage?>();
    await CometChat.sendMessage(
      message,
      onSuccess: (TextMessage msg) {
        if (!completer.isCompleted) completer.complete(msg);
      },
      onError: (CometChatException e) {
        _logCometChatError('sendMessage', e);
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    return await completer.future.timeout(kChatSendTimeout);
  } on TimeoutException catch (e, stack) {
    lastChatSendError = 'Send timed out';
    debugPrint('sendMessage timed out: $e\n$stack');
    return null;
  } catch (e, stack) {
    lastChatSendError = e.toString();
    debugPrint('sendMessage failed: $e\n$stack');
    return null;
  }
}

Future<BaseMessage?> sendMediaMessageSafe(MediaMessage message) async {
  lastChatSendError = null;
  try {
    final completer = Completer<BaseMessage?>();
    await CometChat.sendMediaMessage(
      message,
      onSuccess: (MediaMessage msg) {
        if (!completer.isCompleted) completer.complete(msg);
      },
      onError: (CometChatException e) {
        _logCometChatError('sendMediaMessage', e);
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    return await completer.future.timeout(kChatSendTimeout);
  } on TimeoutException catch (e, stack) {
    lastChatSendError = 'Send timed out';
    debugPrint('sendMediaMessage timed out: $e\n$stack');
    return null;
  } catch (e, stack) {
    lastChatSendError = e.toString();
    debugPrint('sendMediaMessage failed: $e\n$stack');
    return null;
  }
}

Future<BaseMessage?> sendCustomMessageSafe(CustomMessage message) async {
  lastChatSendError = null;
  try {
    final completer = Completer<BaseMessage?>();
    await CometChat.sendCustomMessage(
      message,
      onSuccess: (CustomMessage msg) {
        if (!completer.isCompleted) completer.complete(msg);
      },
      onError: (CometChatException e) {
        _logCometChatError('sendCustomMessage', e);
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    return await completer.future.timeout(kChatSendTimeout);
  } on TimeoutException catch (e, stack) {
    lastChatSendError = 'Send timed out';
    debugPrint('sendCustomMessage timed out: $e\n$stack');
    return null;
  } catch (e, stack) {
    lastChatSendError = e.toString();
    debugPrint('sendCustomMessage failed: $e\n$stack');
    return null;
  }
}

Future<bool> ensureCometChatLoggedIn() async {
  final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
  if (firebaseUid == null) {
    lastChatSendError = 'Not signed in';
    return false;
  }

  try {
    final existing = await CometChat.getLoggedInUser().timeout(
      const Duration(seconds: 8),
    );
    if (existing?.uid.toLowerCase() == firebaseUid.toLowerCase()) return true;
  } catch (e, stack) {
    debugPrint('CometChat getLoggedInUser: $e\n$stack');
  }

  try {
    if (!CometChatConfig.isConfigured) {
      final loaded = await CometChatConfigLoader.loadFromServer();
      if (!loaded) {
        lastChatSendError = 'Chat not configured on server';
        return false;
      }
    }
    await CometChatProvider.ensureInitialized();
    await CometChatAuthService.loginWithFirebaseSession();

    final user = await CometChat.getLoggedInUser().timeout(
      const Duration(seconds: 8),
    );
    if (user?.uid.toLowerCase() == firebaseUid.toLowerCase()) return true;

    lastChatSendError = 'Could not connect to chat';
    return false;
  } catch (e, stack) {
    lastChatSendError = e.toString();
    debugPrint('ensureCometChatLoggedIn failed: $e\n$stack');
    return false;
  }
}

String chatSendFailureLabel() {
  final err = lastChatSendError?.toLowerCase() ?? '';
  if (err.contains('not found') || err.contains('does not exist')) {
    return 'This user is not on chat yet';
  }
  if (err.contains('not configured')) {
    return 'Chat is not set up';
  }
  if (err.contains('timed out')) {
    return 'Send timed out — try again';
  }
  return 'Failed to send';
}