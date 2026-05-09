import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider? getAvatarImageProvider(String? source) {
  if (source == null || source.isEmpty) {
    return null;
  }

  if (source.startsWith('http') || source.startsWith('https')) {
    return NetworkImage(source);
  }

  // Handle file paths (with or without 'file://' prefix)
  String cleanPath = source;
  if (cleanPath.startsWith('file://')) {
    cleanPath = Uri.parse(source).toFilePath();
  }

  return FileImage(File(cleanPath));
}

Widget buildAvatarImage({
  required String? source,
  double radius = 60,
  BoxFit fit = BoxFit.cover,
}) {
  final hasImage = source != null && source.isNotEmpty;

  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF1A1D24),
    backgroundImage: getAvatarImageProvider(source),
    child: !hasImage
        ? Icon(
            Icons.person,
            size: radius,
            color: Colors.white.withValues(alpha: 0.4),
          )
        : null,
  );
}
