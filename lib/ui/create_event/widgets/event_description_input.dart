import 'dart:ui';
import 'package:flutter/material.dart';
import 'format_text_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = FormatTextController(text: widget.initialValue);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DefaultSelectionStyle(
            cursorColor: Colors.white,
            selectionColor: Colors.white.withValues(alpha: 0.2),
            child: TextFormField(
              controller: _controller,
              cursorColor: Colors.white,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    "Add an event description... (Use bold, !heading!, and * lists)",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
