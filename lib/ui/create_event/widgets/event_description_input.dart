import 'dart:async';
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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = FormatTextController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
    );
  }
}
