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
  AvatarProcessResult? _avatarResult;
  bool _busy = false;
  bool _nsfwDetected = false;
  bool _isCreatingProfile = false;

  bool get _hasAvatar => _avatarResult != null;

  Future<void> _runPickerFlow(ImageSource source) async {
    setState(() {
      _busy = true;
      _nsfwDetected = false;
    });
    try {
      final result = await pickAndProcessAvatar(source);
      if (!mounted) return;
      if (result != null) {
        setState(() => _avatarResult = result);
        ref.read(signUpFormProvider.notifier).updateAvatar(result);
      }
    } on Exception catch (e) {
      if (e.toString().contains('NSFW')) {
        if (mounted) setState(() => _nsfwDetected = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAvatarTap() async {
    await showAvatarSourceSheet(context, onChosen: _runPickerFlow);
  }

  Future<void> _createProfile() async {
    setState(() => _isCreatingProfile = true);
    try {
      if (!_hasAvatar) {
        ref.read(signUpFormProvider.notifier).updateAvatar(null);
      }
      final formData = ref.read(signUpFormProvider);
      await ref.read(authControllerProvider.notifier).createUserProfile(formData);

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile creation failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        rightAction: AuthAppBarAction.skip,
        onBack: () => context.go('/auth/signup/details'),
        onSkip: _isCreatingProfile ? null : _createProfile,
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
                      onTap: (_busy || _isCreatingProfile) ? null : _onAvatarTap,
                      child: Column(
                        children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_nsfwDetected)
                                  Container(
                                    width: 160,
                                    height: 160,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.redAccent,
                                    ),
                                    child: const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'NSFW content detected!\nPlease upload another image or try again.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  buildAvatarImage(
                                    source: _avatarResult?.mediumPath,
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
                              _nsfwDetected
                                  ? 'Tap to try again'
                                  : _hasAvatar
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
                    text: 'Create Account',
                    isLoading: _isCreatingProfile,
                    onPressed: (_nsfwDetected || _isCreatingProfile)
                        ? null
                        : _createProfile,
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
