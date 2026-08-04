import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/media/avatar_image_helper.dart';
import '../../domain/auth/auth_providers.dart';
import '../../core/media/image_loader_helper.dart';
import '../../ui/shared/widgets/gradient_top_bar.dart';
import '../../ui/shared/widgets/bloom_modal_shell.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../../domain/event/event_providers.dart';
import '../../domain/friendship/friendship_providers.dart';
import '../../domain/navigation/navigation_providers.dart';
import './widgets/recommended_friend_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;
  bool _isLoading = false;
  bool _isBioExpanded = false;
  bool _nsfwDetected = false;

  Future<void> _uploadAndSaveProfilePhoto(AvatarProcessResult result) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    Future<String> uploadVariant(String localPath, String size) async {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile_pic_$size.webp');

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/webp'),
      );
      return await storageRef.getDownloadURL();
    }

    final largeUrl = await uploadVariant(result.largePath, 'large');
    final mediumUrl = await uploadVariant(result.mediumPath, 'medium');
    final smallUrl = await uploadVariant(result.smallPath, 'small');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'profile_image_url': mediumUrl, // Keep for backward compatibility or default
      'profile_image_large_url': largeUrl,
      'profile_image_medium_url': mediumUrl,
      'profile_image_small_url': smallUrl,
    });
  }

  Future<void> _onChangePhoto() async {
    await showAvatarSourceSheet(
      context,
      onChosen: (source) async {
        setState(() {
          _uploading = true;
          _nsfwDetected = false;
        });
        try {
          final result = await pickAndProcessAvatar(source);
          if (!mounted) return;
          if (result != null) {
            await _uploadAndSaveProfilePhoto(result);
          }
        } on Exception catch (e) {
          if (e.toString().contains('NSFW')) {
            if (mounted) setState(() => _nsfwDetected = true);
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      },
    );
  }

  void _showImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    // Render a full-screen immersive image viewer with a blurred background overlay
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: const ui.Color.fromARGB(
            0,
            255,
            255,
            255,
          ), // Fully transparent background
          body: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: const ui.Color.fromARGB(66, 255, 255, 255),
                  ),
                ),
              ),
              Center(
                child: Hero(
                  tag: 'avatar_preview',
                  child: Image(
                    image: getAvatarImageProvider(imageUrl)!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _onChangePhoto();
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    // Clear local auth session state and sign out from third-party services (e.g. CometChat)
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) {
      // The router's AuthState listening should theoretically handle this,
      // but explicitly going to the new unified entry point prevents errors.
      context.go('/auth/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent, cannot be undone, and will delete all your hosted events, RSVPs, and profile data.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Invalidate recommendedFriendsProvider when switching away from the profile tab
    ref.listen<int>(mainShellIndexProvider, (prev, next) {
      if (prev == 3 && next != 3) {
        ref.invalidate(recommendedFriendsProvider);
      }
    });

    final profileAsync = ref.watch(currentUserProfileProvider);
    final friendsAsync = ref.watch(friendsMadeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          const GradientTopBar(height: 100, showDarkOverlay: false),

          profileAsync.when(
            loading: () {
              return Skeletonizer(
                enabled: true,
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'loading_user',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                                  const SizedBox(width: 10),
                                  Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: Column(
                            children: [
                              Container(width: 116, height: 116, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                              const SizedBox(height: 15),
                              const Text('Loading Name', style: TextStyle(fontSize: 18, color: Colors.white)),
                              const SizedBox(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(children: const [Text('0', style: TextStyle(fontSize: 16, color: Colors.white)), SizedBox(height: 2), Text('Friends', style: TextStyle(fontSize: 12, color: Colors.white))]),
                                  Column(children: const [Text('0', style: TextStyle(fontSize: 16, color: Colors.white)), SizedBox(height: 2), Text('Hosted', style: TextStyle(fontSize: 12, color: Colors.white))]),
                                  Column(children: const [Text('0', style: TextStyle(fontSize: 16, color: Colors.white)), SizedBox(height: 2), Text('Joined', style: TextStyle(fontSize: 12, color: Colors.white))]),
                                ],
                              ),
                              const SizedBox(height: 40),
                              const Text('Loading bio description...', style: TextStyle(color: Colors.white)),
                              const SizedBox(height: 25),
                              Row(
                                children: [
                                  Expanded(child: Container(height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Container(height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            data: (doc) {
              final username = (doc?['username']?.toString() ?? '—').replaceAll(
                '@',
                '',
              );
              final name = doc?['name']?.toString() ?? 'Anonymous';
              final bio = doc?['bio']?.toString() ?? 'No bio yet.';
              final imageUrl = doc?['profile_image_url']?.toString();

              final counts = doc?['counts'] as Map<String, dynamic>?;
              final friendsCount =
                  (friendsAsync.value?.length ?? counts?['friends'] ?? 0)
                      .toString();
              final hostedCount = ref
                  .watch(profileHostedCountProvider)
                  .toString();
              final joinedCount = ref
                  .watch(profileJoinedCountProvider)
                  .toString();

              final socialLinks = doc?['social_links'] as Map<String, dynamic>?;
              final instagram = socialLinks?['instagram']?.toString() ?? '';
              final x = socialLinks?['x']?.toString() ?? '';
              final snapchat = socialLinks?['snapchat']?.toString() ?? '';

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 24, // Username font size
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Row(
                              children: [
                                _buildTopIcon(
                                  assetPath:
                                      'assets/icons/profile/star_fill.svg',
                                  onTap: () {
                                    ref.invalidate(recommendedFriendsProvider);
                                    context.push('/profile/interested');
                                  },
                                ),
                                const SizedBox(
                                  width: 10,
                                ), // Spacing between icons
                                _buildTopIcon(
                                  icon: Icons.menu,
                                  onTap: () => _showSettingsModal(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20), // Small spacing below top row
                      // Profile Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                if (_nsfwDetected)
                                  GestureDetector(
                                    onTap: _onChangePhoto,
                                    child: Container(
                                      width: 116,
                                      height: 116,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.redAccent,
                                      ),
                                      child: const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'NSFW content detected!\nPlease upload another image or try again.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: imageUrl != null
                                        ? () => _showImagePreview(imageUrl)
                                        : null,
                                    child: Hero(
                                      tag: 'avatar_preview',
                                      child: buildAvatarImage(
                                        source: imageUrl,
                                        radius: 58,
                                      ),
                                    ),
                                  ),
                                if (_uploading)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black45,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!_nsfwDetected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: _uploading ? null : _onChangePhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0086D8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 15), // Spacing below avatar
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(
                              height: 25,
                            ), // Spacing between name and stats
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Friends made',
                                    friendsCount,
                                    () {
                                      ref.invalidate(
                                        recommendedFriendsProvider,
                                      );
                                      context.push('/profile/friends');
                                    },
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Hosted events',
                                    hostedCount,
                                    () {
                                      ref.invalidate(
                                        recommendedFriendsProvider,
                                      );
                                      context.push('/profile/hosted');
                                    },
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Joined events',
                                    joinedCount,
                                    () {
                                      ref.invalidate(
                                        recommendedFriendsProvider,
                                      );
                                      context.push('/profile/joined');
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (instagram.isNotEmpty ||
                                x.isNotEmpty ||
                                snapchat.isNotEmpty) ...[
                              const SizedBox(
                                height: 28,
                              ), // Spacing between stats and social links
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    if (instagram.isNotEmpty)
                                      _buildSocialLink(
                                        'instagram',
                                        instagram,
                                        false,
                                      ),
                                    if (x.isNotEmpty)
                                      _buildSocialLink(
                                        'x',
                                        x,
                                        instagram.isNotEmpty,
                                      ),
                                    if (snapchat.isNotEmpty)
                                      _buildSocialLink(
                                        'snapchat',
                                        snapchat,
                                        instagram.isNotEmpty || x.isNotEmpty,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ), // Spacing between social links and bio
                              _buildBioText(bio),
                            ] else ...[
                              const SizedBox(height: 20),
                              _buildBioText(bio),
                            ],

                            const SizedBox(
                              height: 25,
                            ), // Spacing before action buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0.0,
                              ),
                              child: SizedBox(
                                height: 40, // Button height
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionButton(
                                        'Edit profile',
                                        () {
                                          ref.invalidate(
                                            recommendedFriendsProvider,
                                          );
                                          context.push('/profile/edit');
                                        },
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildActionButton(
                                        'Share profile',
                                        () {
                                          final cleanUsername = username
                                              .replaceAll('@', '');
                                          Share.share(
                                            'Follow my profile on Bloom, $cleanUsername',
                                          );
                                        },
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildRecommendedFriendsSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          if (_uploading || _isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0086D8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildTopIcon({
    IconData? icon,
    String? assetPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(
          child: assetPath != null
              ? assetPath.endsWith('.svg')
                    ? SvgPicture.asset(
                        assetPath,
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      )
                    : Image.asset(
                        assetPath,
                        width: 20,
                        height: 20,
                        color: Colors.white,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.error,
                          color: Colors.white,
                          size: 22,
                        ),
                      )
              : Icon(icon ?? Icons.error, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: Colors.white12);
  }

  Widget _buildSocialLink(String platform, String handle, bool hasPrevious) {
    String assetName = platform;

    return GestureDetector(
      onTap: () {
        if (handle.isEmpty) return;
        String url;
        switch (assetName) {
          case 'instagram':
            url = 'https://www.instagram.com/$handle/';
            break;
          case 'x':
            url = 'https://x.com/$handle';
            break;
          case 'snapchat':
            url = 'https://www.snapchat.com/add/$handle';
            break;
          default:
            return;
        }
        _launchUrl(url);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetName.isNotEmpty)
            SvgPicture.asset(
              'assets/icons/profile/${assetName}_icon.svg',
              width: 15,
              height: 15,
              colorFilter: const ColorFilter.mode(
                Colors.white70,
                BlendMode.srcIn,
              ),
            )
          else
            const Icon(Icons.link, size: 14, color: Colors.white10),
          const SizedBox(width: 4), // Spacing between icon and handle
          Text(
            handle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ), // Social handle text
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onTap, {
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              //Leave as gradient please incase I change my mind and want to add a gradient later
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: fontWeight,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBioText(String bio) {
    if (bio.isEmpty) {
      return const SizedBox(
        width: double.infinity,
        child: Text(
          'Add a bio to tell people more about you.',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.white24,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isBioExpanded = !_isBioExpanded;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const style = TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            );
            const moreStyle = TextStyle(
              color: Colors.blue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            );

            final textPainter = TextPainter(
              text: TextSpan(text: bio, style: style),
              maxLines: 3,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            if (!textPainter.didExceedMaxLines) {
              return Text(bio, style: style);
            }

            if (_isBioExpanded) {
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: bio, style: style),
                    const TextSpan(text: ' ...less', style: moreStyle),
                  ],
                ),
              );
            }

            int start = 0;
            int end = bio.length;
            int cutOff = end;

            while (start <= end) {
              int mid = (start + end) ~/ 2;
              final tp = TextPainter(
                text: TextSpan(
                  text: '${bio.substring(0, mid)} ...more',
                  style: style,
                ),
                maxLines: 3,
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: constraints.maxWidth);

              if (tp.didExceedMaxLines) {
                end = mid - 1;
              } else {
                cutOff = mid;
                start = mid + 1;
              }
            }

            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: bio.substring(0, cutOff), style: style),
                  const TextSpan(text: ' ...more', style: moreStyle),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendedFriendsSection() {
    final recommendedAsync = ref.watch(recommendedFriendsProvider);
    final dismissed = ref.watch(dismissedRecommendationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              BloomIconButton(
                icon: Icons.search,
                onTap: () {
                  ref.invalidate(recommendedFriendsProvider);
                  context.push('/profile/search');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        recommendedAsync.when(
          data: (users) {
            final filteredUsers = users.where((u) {
              final uid = u['uid'] ?? u['id'] ?? '';
              return !dismissed.contains(uid);
            }).toList();

            if (filteredUsers.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, color: Colors.white54, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Check back later for more friend recommendations.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredUsers.length > 10
                    ? 10
                    : filteredUsers.length,
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  final targetUser = filteredUsers[index];
                  final uid = targetUser['uid'] ?? targetUser['id'] ?? '';
                  return RecommendedFriendCard(
                    key: ValueKey<String>(uid),
                    user: targetUser,
                    onDismiss: () {
                      ref
                          .read(dismissedRecommendationsProvider.notifier)
                          .dismiss(uid);
                    },
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BloomModalShell(
          title: 'Options',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalOption(
                  icon: Icons.logout,
                  label: 'Log Out',
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  isDestructive: true,
                ),
                _buildModalOption(
                  icon: Icons.delete_forever,
                  label: 'Delete Account',
                  onTap: () {
                    Navigator.pop(context);
                    _deleteAccount();
                  },
                  isDestructive: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white70,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
