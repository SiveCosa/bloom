import 'package:flutter/material.dart';

class FormatTextController extends TextEditingController {
  FormatTextController({super.text});

  static final _pattern = RegExp(
    r'(\*[^\s\*](?:.*?[^\s\*])?\*)|(![^\s!](?:.*?[^\s!])?!)',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    int lastMatchEnd = 0;

    for (final match in _pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final matchText = match.group(0)!;
      final ghostStyle = style?.copyWith(
        color: style.color?.withValues(alpha: 0.3) ?? Colors.white.withValues(alpha: 0.3),
        fontWeight: FontWeight.normal,
      );

      if (match.group(1) != null) {
        children.add(TextSpan(text: '*', style: ghostStyle));
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: style?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
        children.add(TextSpan(text: '*', style: ghostStyle));
      } else if (match.group(2) != null) {
        // Heading: !Heading!
        children.add(TextSpan(text: '!', style: ghostStyle));
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: style?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            color: Colors.white,
          ),
        ));
        children.add(TextSpan(text: '!', style: ghostStyle));
      } else {
        children.add(TextSpan(text: matchText, style: style));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
