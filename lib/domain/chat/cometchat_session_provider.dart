import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../../data/cometchat_provider.dart';
import 'cometchat_auth_service.dart';
import 'cometchat_config_loader.dart';

enum CometChatSessionStatus { idle, loggingIn, ready, failed }

class CometChatSessionState {
  const CometChatSessionState({
    required this.status,
    this.error,
  });

  final CometChatSessionStatus status;
  final String? error;

  bool get isReady => status == CometChatSessionStatus.ready;
}

class CometChatSessionNotifier extends Notifier<CometChatSessionState> {
  @override
  CometChatSessionState build() {
    ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        unawaited(_establishSession());
      } else {
        unawaited(_clearSession());
      }
    }, fireImmediately: true);

    return const CometChatSessionState(status: CometChatSessionStatus.idle);
  }

  Future<void> _establishSession() async {
    if (state.status == CometChatSessionStatus.loggingIn) return;

    state = const CometChatSessionState(
      status: CometChatSessionStatus.loggingIn,
    );

    try {
      final configOk = await CometChatConfigLoader.loadFromServer();
      if (!configOk) {
        state = const CometChatSessionState(
          status: CometChatSessionStatus.failed,
          error:
              'CometChat is not configured. Set COMETCHAT_APP_ID in functions/.env and redeploy.',
        );
        return;
      }

      await CometChatProvider.ensureInitialized();
      await CometChatAuthService.loginWithFirebaseSession();

      state = const CometChatSessionState(
        status: CometChatSessionStatus.ready,
      );
    } catch (e, stack) {
      debugPrint('CometChat session failed: $e\n$stack');
      state = CometChatSessionState(
        status: CometChatSessionStatus.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> _clearSession() async {
    try {
      await CometChatAuthService.logout();
    } catch (e, stack) {
      debugPrint('CometChat logout on sign-out: $e\n$stack');
    }
    CometChatProvider.reset();
    state = const CometChatSessionState(status: CometChatSessionStatus.idle);
  }

  /// Retry login (e.g. from chat screen banner).
  Future<bool> retry() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    await _establishSession();
    return state.isReady;
  }
}

final cometChatSessionProvider =
    NotifierProvider<CometChatSessionNotifier, CometChatSessionState>(
  CometChatSessionNotifier.new,
);