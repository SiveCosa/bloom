import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';

import '../../../domain/chat/chat_list_entry.dart';

enum ChatReceiptState { sending, sent, delivered, read }

ChatReceiptState chatReceiptState(BaseMessage message, ChatSendStatus status) {
  if (status == ChatSendStatus.sending) return ChatReceiptState.sending;
  if (status == ChatSendStatus.failed) return ChatReceiptState.sent;
  if (message.readAt != null) return ChatReceiptState.read;
  if (message.deliveredAt != null) return ChatReceiptState.delivered;
  if (message.id != 0) return ChatReceiptState.sent;
  return ChatReceiptState.sent;
}

/// Time + optional delivery/read status for sent messages.
class ChatBubbleFooter extends StatelessWidget {
  const ChatBubbleFooter({
    super.key,
    required this.message,
    required this.status,
    required this.isMine,
    this.topPadding = 4,
  });

  final BaseMessage message;
  final ChatSendStatus status;
  final bool isMine;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    if (message.sentAt == null && !isMine) return const SizedBox.shrink();

    final time = message.sentAt;
    final receipt = isMine ? chatReceiptState(message, status) : null;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null)
            Text(
              _formatTime(time),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          if (receipt != null) ...[
            const SizedBox(width: 6),
            ChatReceiptIndicator(state: receipt),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

class ChatReceiptIndicator extends StatelessWidget {
  const ChatReceiptIndicator({super.key, required this.state});

  final ChatReceiptState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ChatReceiptState.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        );
      case ChatReceiptState.sent:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 14,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 3),
            Text(
              'Sent',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
              ),
            ),
          ],
        );
      case ChatReceiptState.delivered:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.done_all,
              size: 14,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 3),
            Text(
              'Delivered',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
              ),
            ),
          ],
        );
      case ChatReceiptState.read:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.done_all,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              'Read',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
    }
  }
}