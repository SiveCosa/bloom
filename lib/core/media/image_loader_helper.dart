import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider getAvatarImageProvider(String? source) {
  if (source == null || source.isEmpty) {
    return const AssetImage(
      'assets/images/default_avatar.png',
    ); // Fallback if exists, or handle elsewhere
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
  if (source == null || source.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[900],
      child: Icon(Icons.person, size: radius, color: Colors.white24),
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.grey[900],
    backgroundImage: getAvatarImageProvider(source),
  );
}
