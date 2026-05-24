import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'cometchat_session_provider.dart';

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

    ref.listen(cometChatSessionProvider, (previous, next) {
      if (next.isReady) {
        Future.microtask(() async {
          await refresh();
          _ensureListener();
        });
      }
    });

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

final conversationsListProvider =
    AsyncNotifierProvider<ConversationsListNotifier, List<Conversation>>(
  ConversationsListNotifier.new,
);

class ConversationsListNotifier extends AsyncNotifier<List<Conversation>> {
  static const _pageLimit = 30;
  static const _convListenerId = 'bloom_conversations_listener';
  _BloomMessageListener? _listener;
  bool _listenerRegistered = false;

  @override
  Future<List<Conversation>> build() {
    ref.listen(cometChatSessionProvider, (previous, next) {
      if (next.isReady) {
        Future.microtask(() {
          reload();
          _ensureListener();
        });
      }
    });

    ref.onDispose(_tearDownListener);
    
    // Initial setup if already ready
    if (ref.read(cometChatSessionProvider).isReady) {
      _ensureListener();
    }
    
    return _fetchConversations();
  }

  void _ensureListener() {
    if (_listenerRegistered) return;
    _listener = _BloomMessageListener(() {
      reload();
    });
    CometChat.addMessageListener(_convListenerId, _listener!);
    _listenerRegistered = true;
  }

  void _tearDownListener() {
    if (_listenerRegistered) {
      CometChat.removeMessageListener(_convListenerId);
      _listenerRegistered = false;
      _listener = null;
    }
  }

  Future<void> reload() async {
    // We intentionally do NOT use `state = const AsyncLoading()` here.
    // By directly setting the new state, Riverpod keeps the existing data 
    // on screen and just marks it as `isRefreshing`, preventing UI flashes.
    final newData = await AsyncValue.guard(_fetchConversations);
    state = newData;
  }

  Future<List<Conversation>> _fetchConversations() async {
    final loggedIn = await CometChat.getLoggedInUser();
    if (loggedIn == null) return [];

    final request = (ConversationsRequestBuilder()..setLimit(_pageLimit)).build();
    final list = await request.fetchNext(onSuccess: null, onError: null);

    return list
        .where((c) => c.conversationType == CometChatConversationType.user)
        .toList();
  }
}
