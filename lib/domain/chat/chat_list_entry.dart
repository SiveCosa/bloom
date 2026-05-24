import 'package:cometchat_sdk/cometchat_sdk.dart';

enum ChatSendStatus { sending, sent, failed }

class ChatListEntry {
  const ChatListEntry({
    required this.clientId,
    required this.message,
    this.status = ChatSendStatus.sent,
  });

  final String clientId;
  final BaseMessage message;
  final ChatSendStatus status;

  ChatListEntry copyWith({
    BaseMessage? message,
    ChatSendStatus? status,
  }) {
    return ChatListEntry(
      clientId: clientId,
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }
}