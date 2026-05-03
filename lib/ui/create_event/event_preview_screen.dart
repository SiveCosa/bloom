import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EventPreviewScreen extends StatelessWidget {
  const EventPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Preview',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Stub: Save logic
              context.go('/');
            },
            child: const Text(
              'Save & post',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Event Preview stub',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
