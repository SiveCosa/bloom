import 'package:flutter/material.dart';

class EventTitleInput extends StatefulWidget {
  final Function(String) onChanged;
  final String initialValue;

  const EventTitleInput({
    super.key,
    required this.onChanged,
    this.initialValue = '',
  });

  @override
  State<EventTitleInput> createState() => _EventTitleInputState();
}

class _EventTitleInputState extends State<EventTitleInput> {
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
      setState(() {});
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
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: null, // Global state updated on unfocus
        maxLength: 50,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: 'Event title',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          filled: false,
          counterText: '', // Hide the bottom character counter
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
