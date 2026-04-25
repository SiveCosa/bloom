import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/media/avatar_image_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key});

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  String? _localImagePath;
  bool _busy = false;

  bool get _hasAvatar => _localImagePath != null && _localImagePath!.isNotEmpty;

  Future<void> _runPickerFlow(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final path = await pickAndCropSquareAvatar(source);
      if (!mounted) return;
      if (path != null) {
        setState(() => _localImagePath = path);
        ref.read(signUpFormProvider.notifier).updateAvatar(path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAvatarTap() async {
    await showAvatarSourceSheet(context, onChosen: _runPickerFlow);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        rightAction: AuthAppBarAction.skip,
        onBack: () => context.go('/auth/signup/campus'),
        onSkip: () => context.go('/auth/signup/interests'),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                height: 100,
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
              height: 265,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  Center(
                    child: Image.asset(
                      'assets/bloom_logo.png',
                      width: 65,
                      height: 65,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Add a profile image?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload a profile image. This will make your profile easier to identify and could lead to more invites.',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const Spacer(),
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : _onAvatarTap,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 80,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundImage: _hasAvatar
                                    ? FileImage(File(_localImagePath!))
                                    : null,
                                child: _hasAvatar
                                    ? null
                                    : const Icon(
                                        Icons.person_outline,
                                        size: 80,
                                        color: Colors.white54,
                                      ),
                              ),
                              if (_busy)
                                const Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _hasAvatar
                                ? 'Tap to change photo'
                                : 'Tap to add photo (optional)',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_hasAvatar) {
                          ref
                              .read(signUpFormProvider.notifier)
                              .updateAvatar('');
                        }
                        context.go('/auth/signup/interests');
                      },

                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
