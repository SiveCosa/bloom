import 'package:flutter/material.dart';

/// Incoming peer typing indicator styled like a received message bubble.
class ChatTypingBubble extends StatelessWidget {
  const ChatTypingBubble({super.key, this.maxWidth = 280});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Typing...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}