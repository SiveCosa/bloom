import 'dart:io';

import 'package:flutter/material.dart';


bool chatMediaHasCaption(String? caption) {
  final text = caption?.trim() ?? '';
  if (text.isEmpty) return false;
  return text.toLowerCase() != 'photo';
}

class ChatMediaImage extends StatefulWidget {
  const ChatMediaImage({
    super.key,
    this.networkUrl,
    this.filePath,
    required this.maxWidth,
    this.borderRadius = 8,
    this.onTap,
  });

  final String? networkUrl;
  final String? filePath;
  final double maxWidth;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<ChatMediaImage> createState() => _ChatMediaImageState();
}

class _ChatMediaImageState extends State<ChatMediaImage> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(ChatMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.filePath != widget.filePath) {
      _disposeStream();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  void _disposeStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    final provider = _imageProvider();
    if (provider == null) return;

    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width;
      final h = info.image.height;
      if (!mounted || h <= 0) return;
      setState(() => _aspectRatio = w / h);
    });
    _stream!.addListener(_listener!);
  }

  ImageProvider? _imageProvider() {
    final url = widget.networkUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    final path = widget.filePath;
    if (path != null && path.isNotEmpty) return FileImage(File(path));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider();
    if (provider == null) return const SizedBox.shrink();

    final ratio = _aspectRatio ?? 1.0;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.maxWidth,
        child: AspectRatio(
          aspectRatio: ratio,
          child: Image(
            image: provider,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Container(
              color: Colors.white12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: Colors.white38),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) return image;

    return GestureDetector(onTap: widget.onTap, child: image);
  }
}