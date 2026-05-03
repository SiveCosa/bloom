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
    final bool isFocused = _focusNode.hasFocus;

    return SizedBox(
      height: 60,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: _controller.text.isNotEmpty
              ? FontWeight.bold
              : FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Event title',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: isFocused
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.05),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
      ),
    );
  }
}
