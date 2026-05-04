import 'package:flutter/material.dart';

class EventDescriptionInput extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const EventDescriptionInput({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<EventDescriptionInput> createState() => _EventDescriptionInputState();
}

class _EventDescriptionInputState extends State<EventDescriptionInput> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 4,
      maxLines: 5,
      maxLength: 2000,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Add event description...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        contentPadding: const EdgeInsets.all(16),
        counterText: '',
      ),
    );
  }
}
