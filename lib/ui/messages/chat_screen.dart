import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/media/image_loader_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/chat/chat_list_entry.dart';
import '../../domain/chat/chat_providers.dart';
import '../../domain/chat/chat_send_helper.dart';
import '../../domain/chat/chat_share_providers.dart';
import '../../domain/chat/cometchat_session_provider.dart';
import '../../domain/event/event.dart';
import 'widgets/camera_picker_sheet.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/event_share_formatters.dart';
import 'widgets/share_event_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerUid,
    required this.peerUsername,
  });

  final String peerUid;
  final String peerUsername;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _chatListenerId = 'bloom_chat_screen_listener';
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  List<ChatListEntry> _messages = [];
  bool _loading = true;
  int _pendingId = 0;
  String? _myUid;
  String? _sessionError;
  _ChatMessageListener? _listener;
  bool _isTyping = false;
  bool _isPeerTyping = false;

  void _onTextChanged() {
    final hasText = _textController.text.isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      CometChat.startTyping(receiverUid: widget.peerUid, receiverType: 'user');
    } else if (!hasText && _isTyping) {
      _isTyping = false;
      CometChat.endTyping(receiverUid: widget.peerUid, receiverType: 'user');
    }
  }

  String _nextClientId() => 'pending_${_pendingId++}';

  ChatListEntry _entryFromMessage(
    BaseMessage message, {
    ChatSendStatus status = ChatSendStatus.sent,
  }) {
    return ChatListEntry(
      clientId: message.id != 0 ? 'srv_${message.id}' : _nextClientId(),
      message: message,
      status: status,
    );
  }

  void _appendOptimistic(BaseMessage message, String clientId) {
    setState(() {
      _messages = [
        ..._messages,
        ChatListEntry(
          clientId: clientId,
          message: message,
          status: ChatSendStatus.sending,
        ),
      ];
    });
    _scrollToBottom();
  }

  void _markEntryFailed(String clientId) {
    setState(() {
      _messages = _messages
          .map(
            (e) => e.clientId == clientId
                ? e.copyWith(status: ChatSendStatus.failed)
                : e,
          )
          .toList();
    });
  }

  void _markEntrySent(String clientId, BaseMessage sent) {
    setState(() {
      _messages = _messages.map((e) {
        if (e.clientId != clientId) return e;
        return ChatListEntry(
          clientId: sent.id != 0 ? 'srv_${sent.id}' : clientId,
          message: sent,
          status: ChatSendStatus.sent,
        );
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    CometChat.getLoggedInUser().then((user) {
      if (mounted) setState(() => _myUid = user?.uid);
    });
    _listener = _ChatMessageListener(
      peerUid: widget.peerUid,
      onMessage: _onIncomingMessage,
      onReceipt: _onMessageReceipt,
      onTyping: (isTyping) {
        if (mounted) setState(() => _isPeerTyping = isTyping);
      },
    );
    CometChat.addMessageListener(_chatListenerId, _listener!);
    _bootstrap();
  }

  @override
  void dispose() {
    if (_isTyping) {
      CometChat.endTyping(receiverUid: widget.peerUid, receiverType: 'user');
    }
    _inputFocusNode.dispose();
    CometChat.removeMessageListener(_chatListenerId);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _inputFocusNode.unfocus();
  }

  void _onMessageReceipt(MessageReceipt receipt) {
    if (receipt.sender.uid.toLowerCase() != widget.peerUid.toLowerCase() &&
        receipt.receiverId?.toLowerCase() != widget.peerUid.toLowerCase()) {
      return;
    }

    setState(() {
      _messages = _messages.map((entry) {
        if (entry.message.id.toString() == receipt.messageId.toString()) {
          if (receipt.receiptType == 'read') {
            entry.message.readAt = receipt.readAt ?? DateTime.now();
            entry.message.deliveredAt ??= entry.message.readAt;
          } else if (receipt.receiptType == 'delivery') {
            entry.message.deliveredAt = receipt.deliveredAt ?? DateTime.now();
          }
        }
        return entry;
      }).toList();
    });
  }

  void _onIncomingMessage(BaseMessage message) {
    if (!_isForThisChat(message)) return;
    setState(() {
      if (message.id != 0) {
        final byId = _messages.indexWhere((e) => e.message.id == message.id);
        if (byId >= 0) {
          _messages = _messages
              .map(
                (e) =>
                    e.message.id == message.id ? _entryFromMessage(message) : e,
              )
              .toList();
          return;
        }
      }

      if (message is TextMessage) {
        final pendingIdx = _messages.indexWhere(
          (e) =>
              e.status == ChatSendStatus.sending &&
              e.message is TextMessage &&
              (e.message as TextMessage).text == message.text,
        );
        if (pendingIdx >= 0) {
          _messages = [
            ..._messages.sublist(0, pendingIdx),
            _entryFromMessage(message),
            ..._messages.sublist(pendingIdx + 1),
          ];
          return;
        }
      }

      final exists = _messages.any(
        (e) => e.message.id == message.id && message.id != 0,
      );
      if (!exists) {
        _messages = [..._messages, _entryFromMessage(message)];
      }
    });
    _scrollToBottom();
    _markRead();
    ref.read(totalUnreadCountProvider.notifier).refresh();
  }

  bool _isForThisChat(BaseMessage message) {
    final senderId = message.sender?.uid;
    final receiverId = message.receiverUid;
    final peerLower = widget.peerUid.toLowerCase();
    return senderId?.toLowerCase() == peerLower ||
        receiverId.toLowerCase() == peerLower;
  }

  Future<void> _bootstrap() async {
    if (widget.peerUid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!await ensureCometChatLoggedIn()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _sessionError = lastChatSendError ?? 'Chat unavailable';
        });
      }
      return;
    }

    if (mounted) setState(() => _sessionError = null);

    try {
      await _loadMessages();
      await _markRead();
      if (mounted) {
        ref.read(totalUnreadCountProvider.notifier).refresh();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryChatSession() async {
    setState(() {
      _loading = true;
      _sessionError = null;
    });
    final ok = await ref.read(cometChatSessionProvider.notifier).retry();
    if (!ok && mounted) {
      final session = ref.read(cometChatSessionProvider);
      setState(() {
        _loading = false;
        _sessionError = session.error ?? 'Chat unavailable';
      });
      return;
    }
    await _bootstrap();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final request =
          (MessagesRequestBuilder()
                ..setUID(widget.peerUid)
                ..setLimit(40))
              .build();

      final list = await request.fetchPrevious(onSuccess: null, onError: null);
      if (mounted) {
        setState(() {
          _messages = list.map(_entryFromMessage).toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await CometChat.markConversationAsRead(
        widget.peerUid,
        CometChatReceiverType.user,
        onSuccess: null,
        onError: null,
      );
    } catch (_) {
      // Conversation may not exist yet for new chats.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final selected = ref.read(selectedEventForChatProvider);
    if (selected != null) {
      final attachedMessage = _textController.text;
      _textController.clear();
      ref.read(selectedEventForChatProvider.notifier).clear();
      await _sendEventInvite(selected, attachedMessage: attachedMessage);
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final clientId = _nextClientId();
    final message = TextMessage(
      text: text,
      receiverUid: widget.peerUid,
      type: CometChatMessageType.text,
      receiverType: CometChatReceiverType.user,
    );

    _textController.clear();
    _appendOptimistic(message, clientId);

    if (!await ensureCometChatLoggedIn()) {
      if (mounted) _markEntryFailed(clientId);
      return;
    }

    final sent = await sendTextMessageSafe(message);
    if (!mounted) return;
    if (sent != null) {
      _markEntrySent(clientId, sent);
      _scrollToBottom();
      unawaited(ref.read(conversationsListProvider.notifier).reload());
    } else {
      _markEntryFailed(clientId);
    }
  }

  Future<void> _sendImage(File file) async {
    final clientId = _nextClientId();
    final message = MediaMessage(
      receiverUid: widget.peerUid,
      type: CometChatMessageType.image,
      receiverType: CometChatReceiverType.user,
      file: file.path,
    );

    _appendOptimistic(message, clientId);

    if (!await ensureCometChatLoggedIn()) {
      if (mounted) _markEntryFailed(clientId);
      return;
    }

    final sent = await sendMediaMessageSafe(message);
    if (!mounted) return;
    if (sent != null) {
      _markEntrySent(clientId, sent);
      _scrollToBottom();
      unawaited(ref.read(conversationsListProvider.notifier).reload());
    } else {
      _markEntryFailed(clientId);
    }
  }

  Future<void> _sendEventInvite(
    Event event, {
    required String attachedMessage,
  }) async {
    final clientId = _nextClientId();
    final custom = CustomMessage(
      receiverUid: widget.peerUid,
      type: 'event_invite',
      receiverType: CometChatReceiverType.user,
      customData: buildEventSharePayload(
        event,
        attachedMessage: attachedMessage,
      ),
    );

    _appendOptimistic(custom, clientId);

    if (!await ensureCometChatLoggedIn()) {
      if (mounted) _markEntryFailed(clientId);
      return;
    }

    final sent = await sendCustomMessageSafe(custom);
    if (!mounted) return;
    if (sent != null) {
      _markEntrySent(clientId, sent);
      _scrollToBottom();
      unawaited(ref.read(conversationsListProvider.notifier).reload());
    } else {
      _markEntryFailed(clientId);
    }
  }

  Future<void> _onCameraTap() async {
    final file = await showCameraPickerSheet(context);
    if (file != null) await _sendImage(file);
  }

  Future<void> _onPlusTap() async {
    await showShareEventSheet(context);
  }

  bool _isMine(ChatListEntry entry) {
    if (entry.status == ChatSendStatus.sending ||
        entry.status == ChatSendStatus.failed) {
      return true;
    }
    final myUid = _myUid;
    return myUid != null && entry.message.sender?.uid == myUid;
  }

  Widget _buildTypingIndicator(double maxWidth) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Typing...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0086D8)),
      );
    }

    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    final itemCount = _messages.length + (_isPeerTyping ? 1 : 0);

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (_isPeerTyping && index == 0) {
          return _buildTypingIndicator(maxWidth);
        }
        final msgIndex = _isPeerTyping ? index - 1 : index;
        final entry = _messages[_messages.length - 1 - msgIndex];
        final mine = _isMine(entry);
        final failed = entry.status == ChatSendStatus.failed;
        return ChatMessageBubble(
          entry: entry,
          isMine: mine,
          maxWidth: maxWidth,
          failedLabel: failed ? chatSendFailureLabel() : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CometChatSessionState>(cometChatSessionProvider, (
      previous,
      next,
    ) {
      if (next.isReady && _sessionError != null) {
        _retryChatSession();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.coreGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ChatTopBar(
                  peerUid: widget.peerUid,
                  fallbackName: widget.peerUsername,
                  onBack: () => context.pop(),
                ),
                if (_sessionError != null)
                  Material(
                    color: Colors.red.shade900.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sessionError!,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryChatSession,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: _dismissKeyboard,
                    behavior: HitTestBehavior.translucent,
                    child: _buildMessages(),
                  ),
                ),
                ChatInputBar(
                  controller: _textController,
                  focusNode: _inputFocusNode,
                  onSend: _sendText,
                  onCameraTap: _onCameraTap,
                  onPlusTap: _onPlusTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTopBar extends ConsumerWidget {
  static const _avatarRadius = 20.0;

  const _ChatTopBar({
    required this.peerUid,
    required this.fallbackName,
    required this.onBack,
  });

  final String peerUid;
  final String fallbackName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider(peerUid));

    final displayName = profileAsync.when(
      data: (profile) {
        final name = profile?['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
        return fallbackName;
      },
      loading: () => fallbackName,
      error: (_, _) => fallbackName,
    );

    final username = profileAsync.when(
      data: (profile) => profile?['username']?.toString().trim() ?? '',
      loading: () => '',
      error: (_, _) => '',
    );

    final avatarUrl = profileAsync.when(
      data: (profile) =>
          profile?['profile_image_url']?.toString() ??
          profile?['avatar_url']?.toString() ??
          profile?['avatarUrl']?.toString(),
      loading: () => null,
      error: (_, _) => null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          buildAvatarImage(source: avatarUrl, radius: _avatarRadius),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (username.isNotEmpty) ...[
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _ChatMessageListener with MessageListener {
  _ChatMessageListener({
    required this.peerUid,
    required this.onMessage,
    required this.onReceipt,
    required this.onTyping,
  });

  final String peerUid;
  final void Function(BaseMessage message) onMessage;
  final void Function(MessageReceipt receipt) onReceipt;
  final void Function(bool isTyping) onTyping;

  bool _matches(BaseMessage message) {
    final senderId = message.sender?.uid;
    final receiverId = message.receiverUid;
    final peerLower = peerUid.toLowerCase();
    return senderId?.toLowerCase() == peerLower ||
        receiverId.toLowerCase() == peerLower;
  }

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    if (_matches(textMessage)) onMessage(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    if (_matches(mediaMessage)) onMessage(mediaMessage);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    if (_matches(customMessage)) onMessage(customMessage);
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    onReceipt(messageReceipt);
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    onReceipt(messageReceipt);
  }

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    if (typingIndicator.sender.uid.toLowerCase() == peerUid.toLowerCase()) {
      onTyping(true);
    }
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    if (typingIndicator.sender.uid.toLowerCase() == peerUid.toLowerCase()) {
      onTyping(false);
    }
  }
}
