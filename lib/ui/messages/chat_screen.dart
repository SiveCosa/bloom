import 'dart:io';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/chat/chat_providers.dart';
import '../../domain/event/event.dart';
import 'widgets/camera_picker_sheet.dart';
import 'widgets/chat_input_bar.dart';
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
  List<BaseMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _myUid;
  _ChatMessageListener? _listener;

  @override
  void initState() {
    super.initState();
    CometChat.getLoggedInUser().then((user) {
      if (mounted) setState(() => _myUid = user?.uid);
    });
    _listener = _ChatMessageListener(
      peerUid: widget.peerUid,
      onMessage: _onIncomingMessage,
    );
    CometChat.addMessageListener(_chatListenerId, _listener!);
    _bootstrap();
  }

  @override
  void dispose() {
    CometChat.removeMessageListener(_chatListenerId);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onIncomingMessage(BaseMessage message) {
    if (!_isForThisChat(message)) return;
    setState(() {
      final exists = _messages.any((m) => m.id == message.id && message.id != 0);
      if (!exists) {
        _messages = [..._messages, message];
      }
    });
    _scrollToBottom();
    ref.read(totalUnreadCountProvider.notifier).refresh();
  }

  bool _isForThisChat(BaseMessage message) {
    final senderId = message.sender?.uid;
    final receiverId = message.receiverUid;
    return senderId == widget.peerUid || receiverId == widget.peerUid;
  }

  Future<void> _bootstrap() async {
    if (widget.peerUid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final loggedIn = await CometChat.getLoggedInUser();
      if (loggedIn == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      await _loadMessages();
      await _markRead();
      if (mounted) {
        ref.read(totalUnreadCountProvider.notifier).refresh();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final request = (MessagesRequestBuilder()
            ..setUID(widget.peerUid)
            ..setLimit(40))
          .build();

      final list = await request.fetchPrevious(onSuccess: null, onError: null);
      if (mounted) {
        setState(() {
          _messages = list;
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
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    final message = TextMessage(
      text: text,
      receiverUid: widget.peerUid,
      type: CometChatMessageType.text,
      receiverType: CometChatReceiverType.user,
    );

    final sent = await CometChat.sendMessage(message, onSuccess: null, onError: null);
    if (mounted) {
      setState(() => _sending = false);
      if (sent != null) {
        setState(() => _messages = [..._messages, sent]);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendImage(File file) async {
    if (_sending) return;
    setState(() => _sending = true);

    final message = MediaMessage(
      receiverUid: widget.peerUid,
      type: CometChatMessageType.image,
      receiverType: CometChatReceiverType.user,
      file: file.path,
    );

    final sent =
        await CometChat.sendMediaMessage(message, onSuccess: null, onError: null);
    if (mounted) {
      setState(() => _sending = false);
      if (sent != null) {
        setState(() => _messages = [..._messages, sent]);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendEventInvite(Event event) async {
    if (_sending) return;
    setState(() => _sending = true);

    final custom = CustomMessage(
      receiverUid: widget.peerUid,
      type: 'event_invite',
      receiverType: CometChatReceiverType.user,
      customData: {
        'eventId': event.id,
        'eventName': event.title,
        'posterUrl': event.visuals.posterUrl ?? '',
      },
    );

    final sent =
        await CometChat.sendCustomMessage(custom, onSuccess: null, onError: null);
    if (mounted) {
      setState(() => _sending = false);
      if (sent != null) {
        setState(() => _messages = [..._messages, sent]);
        _scrollToBottom();
      }
    }
  }

  Future<void> _onCameraTap() async {
    final file = await showCameraPickerSheet(context);
    if (file != null) await _sendImage(file);
  }

  Future<void> _onPlusTap() async {
    await showShareEventSheet(
      context,
      onEventSelected: _sendEventInvite,
    );
  }

  String _bubbleText(BaseMessage message) {
    if (message is TextMessage) return message.text;
    if (message is MediaMessage) return message.caption ?? 'Photo';
    if (message is CustomMessage) {
      return message.customData?['eventName']?.toString() ?? 'Event invite';
    }
    return 'Message';
  }

  bool _isMine(BaseMessage message) {
    final myUid = _myUid;
    return myUid != null && message.sender?.uid == myUid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E12),
        foregroundColor: Colors.white,
        title: Text(
          widget.peerUsername,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0086D8)),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello to ${widget.peerUsername}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine = _isMine(message);
                          return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? const Color(0xFF0086D8)
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (message is MediaMessage) ...[
                                        Builder(
                                          builder: (context) {
                                            final url =
                                                message.attachment?.fileUrl;
                                            final localPath = message.file;
                                            if (url != null && url.isNotEmpty) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    url,
                                                    height: 160,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        const SizedBox.shrink(),
                                                  ),
                                                ),
                                              );
                                            }
                                            if (localPath != null &&
                                                localPath.isNotEmpty) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(localPath),
                                                    height: 160,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                      Text(
                                        _bubbleText(message),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      if (message.sentAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('h:mm a').format(message.sentAt!),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                        },
                      ),
          ),
          ChatInputBar(
            controller: _textController,
            onSend: _sendText,
            onCameraTap: _onCameraTap,
            onPlusTap: _onPlusTap,
            isSending: _sending,
          ),
        ],
      ),
    );
  }
}

class _ChatMessageListener with MessageListener {
  _ChatMessageListener({
    required this.peerUid,
    required this.onMessage,
  });

  final String peerUid;
  final void Function(BaseMessage message) onMessage;

  bool _matches(BaseMessage message) {
    final senderId = message.sender?.uid;
    final receiverId = message.receiverUid;
    return senderId == peerUid || receiverId == peerUid;
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
}
