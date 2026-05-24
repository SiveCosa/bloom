import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onCameraTap,
    required this.onPlusTap,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCameraTap;
  final VoidCallback onPlusTap;
  final bool isSending;

  static const _pillColor = Color(0xFF25282D);
  static const _mutedGrey = Color(0xFF8A8F98);
  static const _sendBlue = Color(0xFF0086D8);
  static const _animDuration = Duration(milliseconds: 200);
  static const _edgeInset = 5.0;
  static const _buttonSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E12),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final hasText = controller.text.isNotEmpty;

          return AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minHeight: 50),
            decoration: BoxDecoration(
              color: _pillColor,
              borderRadius: BorderRadius.circular(25),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(_edgeInset),
              child: Row(
                crossAxisAlignment: hasText
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
                children: [
                  AnimatedSize(
                    duration: _animDuration,
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: hasText ? 0 : _buttonSize,
                      height: hasText ? 0 : _buttonSize,
                      child: ClipRect(
                        child: AnimatedOpacity(
                          duration: _animDuration,
                          opacity: hasText ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: hasText,
                            child: GestureDetector(
                              onTap: isSending ? null : onPlusTap,
                              child: const _GradientPlusButton(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !isSending,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Type message...',
                        hintStyle: const TextStyle(color: _mutedGrey),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(
                          left: hasText ? 10 : 8,
                          right: 8,
                          top: 8,
                          bottom: 8,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _buttonSize,
                    height: _buttonSize,
                    child: AnimatedSwitcher(
                      duration: _animDuration,
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: hasText
                          ? GestureDetector(
                              key: const ValueKey('send'),
                              onTap: isSending ? null : onSend,
                              child: _SendButton(isSending: isSending),
                            )
                          : GestureDetector(
                              key: const ValueKey('camera'),
                              onTap: isSending ? null : onCameraTap,
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 25,
                                  color: _mutedGrey,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientPlusButton extends StatelessWidget {
  const _GradientPlusButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ChatInputBar._buttonSize,
      height: ChatInputBar._buttonSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFFC151FD),
            Color(0xFFF04A9F),
            Color(0xFFFFB965),
          ],
        ),
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 25),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending});

  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ChatInputBar._buttonSize,
      height: ChatInputBar._buttonSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ChatInputBar._sendBlue,
        shape: BoxShape.circle,
      ),
      child: isSending
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
    );
  }
}
