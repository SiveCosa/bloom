import 'package:cometchat_sdk/cometchat_sdk.dart';

void test() {
  CometChat.startTyping(receiverUid: 'uid', receiverType: 'user');
  CometChat.endTyping(receiverUid: 'uid', receiverType: 'user');
}

class MyListener with MessageListener {
  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
     var senderUid = typingIndicator.sender?.uid;
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {}
}
