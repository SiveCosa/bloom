import 'dart:ui';
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SizedBox(
          height: 60,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: null, // Global state updated on unfocus
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
              fillColor: Colors.white.withValues(alpha: 0.15),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
