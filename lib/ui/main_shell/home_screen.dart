import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../core/theme/app_theme.dart';
import '../../domain/auth/auth_providers.dart';

/// Main Home tab. Bottom navigation (Home, Discover, Create, Calendar, Profile)
/// is on [ShellScreen] — this widget is only the Home tab body.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateChangesProvider);
    final user = userAsync.value;

    final displayName = user?.displayName?.trim();
    final greeting = displayName != null && displayName.isNotEmpty
        ? 'Hi, $displayName'
        : 'Welcome to Bloom';

    final subtitle = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.coreGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x000B0E12), Color(0xFF0B0E12)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: userAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Center(
                          child: Image.asset(
                            'assets/bloom_logo.png',
                            width: 72,
                            height: 72,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          greeting,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        Text(
                          'Your feed and events will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
