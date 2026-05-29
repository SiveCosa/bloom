import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<File?> showCameraPickerSheet(BuildContext context) {
  return showModalBottomSheet<File>(
    context: context,
    backgroundColor: const Color(0xFF1A1F26),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera, color: Colors.white),
              title: const Text(
                'Take a picture',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (!context.mounted) return;
                Navigator.pop(
                  context,
                  picked != null ? File(picked.path) : null,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (!context.mounted) return;
                Navigator.pop(
                  context,
                  picked != null ? File(picked.path) : null,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
