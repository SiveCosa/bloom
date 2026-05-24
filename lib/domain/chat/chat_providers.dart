import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

const _listenerId = 'bloom_global_message_listener';

final totalUnreadCountProvider =
    NotifierProvider<TotalUnreadCountNotifier, int>(TotalUnreadCountNotifier.new);

class TotalUnreadCountNotifier extends Notifier<int> {
  _BloomMessageListener? _listener;
  bool _listenerRegistered = false;

  @override
  int build() {
    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        Future.microtask(() async {
          await refresh();
          _ensureListener();
        });
      } else {
        _tearDownListener();
        state = 0;
      }
    }, fireImmediately: true);

    ref.onDispose(_tearDownListener);
    return 0;
  }

  Future<void> refresh() async {
    final loggedIn = await CometChat.getLoggedInUser();
    if (loggedIn == null) {
      state = 0;
      return;
    }

    final map = await CometChat.getUnreadMessageCountForAllUsers(
      onSuccess: null,
      onError: null,
    );
    state = map?.values.fold<int>(0, (sum, count) => sum + count) ?? 0;
  }

  void _ensureListener() {
    if (_listenerRegistered) return;
    _listener = _BloomMessageListener(() {
      refresh();
    });
    CometChat.addMessageListener(_listenerId, _listener!);
    _listenerRegistered = true;
  }

  void _tearDownListener() {
    if (_listenerRegistered) {
      CometChat.removeMessageListener(_listenerId);
      _listenerRegistered = false;
      _listener = null;
    }
  }
}

class _BloomMessageListener with MessageListener {
  _BloomMessageListener(this._onUpdate);

  final VoidCallback _onUpdate;

  @override
  void onTextMessageReceived(TextMessage textMessage) => _onUpdate();

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) => _onUpdate();

  @override
  void onCustomMessageReceived(CustomMessage customMessage) => _onUpdate();

  @override
  void onMessagesRead(MessageReceipt messageReceipt) => _onUpdate();

  @override
  void onMessagesReadByAll(MessageReceipt messageReceipt) => _onUpdate();
}
