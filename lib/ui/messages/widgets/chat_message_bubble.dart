import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/chat/chat_list_entry.dart';
import 'chat_media_image.dart';
import 'chat_photo_viewer.dart';
import 'event_invite_snippet.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.entry,
    required this.isMine,
    required this.maxWidth,
    this.failedLabel,
  });

  final ChatListEntry entry;
  final bool isMine;
  final double maxWidth;
  final String? failedLabel;

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final failed = entry.status == ChatSendStatus.failed;

    if (message is CustomMessage && message.type == 'event_invite') {
      return _EventInviteBubble(
        message: message,
        isMine: isMine,
        maxWidth: maxWidth,
        failed: failed,
        failedLabel: failedLabel,
      );
    }

    if (message is MediaMessage) {
      return _MediaBubble(
        message: message,
        isMine: isMine,
        maxWidth: maxWidth,
        failed: failed,
        failedLabel: failedLabel,
      );
    }

    return _TextBubble(
      message: message,
      isMine: isMine,
      maxWidth: maxWidth,
      failed: failed,
      failedLabel: failedLabel,
    );
  }
}

class _EventInviteBubble extends StatelessWidget {
  const _EventInviteBubble({
    required this.message,
    required this.isMine,
    required this.maxWidth,
    required this.failed,
    this.failedLabel,
  });

  final CustomMessage message;
  final bool isMine;
  final double maxWidth;
  final bool failed;
  final String? failedLabel;

  @override
  Widget build(BuildContext context) {
    final data = message.customData ?? {};
    final attached = data['attachedMessage']?.toString().trim() ?? '';
    final eventId = data['eventId']?.toString();

    final bubbleColor = isMine
        ? const Color(0xFF0086D8)
        : Colors.white.withValues(alpha: 0.1);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: eventId != null && eventId.isNotEmpty
                        ? () => context.push('/event/$eventId')
                        : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: EventInviteSnippet.fromPayload(data),
                    ),
                  ),
                  if (attached.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        attached,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  if (message.sentAt != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('h:mm').format(message.sentAt!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 12),
                          _MessageReceipt(message: message),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (failed && failedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4, right: 4),
              child: Text(
                failedLabel!,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaBubble extends StatelessWidget {
  const _MediaBubble({
    required this.message,
    required this.isMine,
    required this.maxWidth,
    required this.failed,
    this.failedLabel,
  });

  final MediaMessage message;
  final bool isMine;
  final double maxWidth;
  final bool failed;
  final String? failedLabel;

  @override
  Widget build(BuildContext context) {
    final url = message.attachment?.fileUrl;
    final localPath = message.file;
    final caption = message.caption;
    final hasCaption = chatMediaHasCaption(caption);
    final imageMaxWidth = maxWidth - (hasCaption ? 28 : 8);

    void openViewer() {
      showChatPhotoViewer(context, networkUrl: url, filePath: localPath);
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(
              horizontal: hasCaption ? 14 : 4,
              vertical: hasCaption ? 10 : 4,
            ),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFF0086D8)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatMediaImage(
                    networkUrl: url,
                    filePath: localPath,
                    maxWidth: imageMaxWidth,
                    borderRadius: hasCaption ? 8 : 12,
                    onTap: openViewer,
                  ),
                  if (hasCaption) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        caption!.trim(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  if (message.sentAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.sentAt!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 12),
                          _MessageReceipt(message: message),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (failed && failedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4, right: 4),
              child: Text(
                failedLabel!,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.isMine,
    required this.maxWidth,
    required this.failed,
    this.failedLabel,
  });

  final BaseMessage message;
  final bool isMine;
  final double maxWidth;
  final bool failed;
  final String? failedLabel;

  String _bubbleText() {
    if (message is TextMessage) return (message as TextMessage).text;
    return 'Message';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFF0086D8)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _bubbleText(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (message.sentAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.sentAt!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 12),
                          _MessageReceipt(message: message),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (failed && failedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4, right: 4),
              child: Text(
                failedLabel!,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageReceipt extends StatelessWidget {
  const _MessageReceipt({required this.message});

  final BaseMessage message;

  @override
  Widget build(BuildContext context) {
    String text = 'Sent';
    IconData icon = Icons.check;
    Color color = Colors.white.withValues(alpha: 0.6);

    if (message.readAt != null) {
      text = 'Read';
      icon = Icons.done_all;
    } else if (message.deliveredAt != null) {
      text = 'Delivered';
      icon = Icons.done_all;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 2),
        Icon(icon, size: 14, color: color),
      ],
    );
  }
}
