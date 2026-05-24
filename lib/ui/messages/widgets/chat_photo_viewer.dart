import 'dart:io';

import 'package:flutter/material.dart';

void showChatPhotoViewer(
  BuildContext context, {
  String? networkUrl,
  String? filePath,
}) {
  final hasNetwork = networkUrl != null && networkUrl.isNotEmpty;
  final hasFile = filePath != null && filePath.isNotEmpty;
  if (!hasNetwork && !hasFile) return;

  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (context, _, __) {
        return _ChatPhotoViewerPage(
          networkUrl: hasNetwork ? networkUrl : null,
          filePath: hasFile ? filePath : null,
        );
      },
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ChatPhotoViewerPage extends StatelessWidget {
  const _ChatPhotoViewerPage({
    this.networkUrl,
    this.filePath,
  });

  final String? networkUrl;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: networkUrl != null
                  ? Image.network(networkUrl!, fit: BoxFit.contain)
                  : Image.file(File(filePath!), fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}