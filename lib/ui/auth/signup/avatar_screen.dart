import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/avatar_image_helper.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/bloom_button.dart';
import '../../../core/media/image_loader_helper.dart';

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
          const GradientTopBar(showDarkOverlay: true),
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
                              buildAvatarImage(
                                source: _localImagePath,
                                radius: 80,
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
                  BloomButton(
                    text: 'Continue',
                    onPressed: () {
                      if (!_hasAvatar) {
                        ref.read(signUpFormProvider.notifier).updateAvatar('');
                      }
                      context.go('/auth/signup/interests');
                    },
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
