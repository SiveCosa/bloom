import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/media/avatar_image_helper.dart';
import '../../domain/auth/auth_providers.dart';
import '../../core/media/image_compression_helper.dart';
import '../../core/media/image_loader_helper.dart';
import '../../ui/shared/widgets/gradient_top_bar.dart';
import '../../domain/friendship/friendship_providers.dart';
import './widgets/recommended_friend_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;
  bool _isBioExpanded = false;

  Future<void> _uploadAndSaveProfilePhoto(String localPath) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final file = File(localPath);
    final bytes = await file.readAsBytes();
    
    // Ensure all uploads are WebP 80%
    final compressedBytes = await ImageCompressionHelper.compressToWebP(bytes);

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('avatar.webp');
        
    await storageRef.putData(
      compressedBytes, 
      SettableMetadata(contentType: 'image/webp'),
    );
    final url = await storageRef.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'profile_image_url': url,
    });
  }

  Future<void> _onChangePhoto() async {
    await showAvatarSourceSheet(
      context,
      onChosen: (source) async {
        setState(() => _uploading = true);
        try {
          final path = await pickAndCropSquareAvatar(source);
          if (!mounted) return;
          if (path != null) {
            await _uploadAndSaveProfilePhoto(path);
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      },
    );
  }

  void _showImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

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
                        // Close Button
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      TextButton.icon(
                        // Edit Button
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
    await ref.read(firebaseAuthProvider).signOut();
    ref.read(signUpFormProvider.notifier).clearForm();
    if (mounted) {
      context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // Layer 0: Background Gradient
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),

          // Layer 1: Foreground Content
          profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF0086D8)),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            data: (doc) {
              final username = doc?['username']?.toString() ?? '—';
              final name = doc?['name']?.toString() ?? 'Anonymous';
              final bio = doc?['bio']?.toString() ?? 'No bio yet.';
              final imageUrl = doc?['profile_image_url']?.toString();

              final counts = doc?['counts'] as Map<String, dynamic>?;
              final friendsCount = (counts?['friends'] ?? 0).toString();
              final hostedCount = (counts?['hosted'] ?? 0).toString();
              final joinedCount = (counts?['joined'] ?? 0).toString();

              final socialLinks = doc?['social_links'] as Map<String, dynamic>?;
              final instagram = socialLinks?['instagram']?.toString() ?? '';
              final x = socialLinks?['x']?.toString() ?? '';
              final snapchat = socialLinks?['snapchat']?.toString() ?? '';

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Top Action Row
                      Padding(
                        // Interested & Settings Icons
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              //Username
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
                                      'assets/icons/profile/interested_icon.svg',
                                  icon: Icons.star_outline,
                                  onTap: () =>
                                      context.push('/profile/interested'),
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
                            // Avatar
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: imageUrl != null ? () => _showImagePreview(imageUrl) : null,
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

                            // Real Name
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
                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Friends made',
                                    friendsCount,
                                    () => context.push('/profile/friends'),
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Hosted events',
                                    hostedCount,
                                    () => context.push('/profile/hosted'),
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Joined events',
                                    joinedCount,
                                    () => context.push('/profile/joined'),
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
                              // Bio Section
                              _buildBioText(bio),
                            ] else ...[
                              const SizedBox(height: 20),
                              _buildBioText(bio),
                            ],

                            const SizedBox(
                              height: 25,
                            ), // Spacing before action buttons
                            // Action Buttons
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
                                        // Edit Profile Button
                                        'Edit profile',
                                        () => context.push('/profile/edit'),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildActionButton(
                                        // Share Profile Button
                                        'Share profile',
                                        () {}, // Logic needed to share profile
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

          if (_uploading)
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
          // Center the icon within the circular container
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
    // Stat item with label and count
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            // Stat Count
            count,
            style: const TextStyle(
              // Stat Number
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // Stat
            label,
            style: TextStyle(
              // Stat Label
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
    // Vertical divider between stats
    return Container(width: 1, height: 50, color: Colors.white12);
  }

  Widget _buildSocialLink(String platform, String handle, bool hasPrevious) {
    // Social media link with icon and handle
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
        // Social link with icon and handle
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
            const Icon(
              // Fallback icon if platform is unknown
              Icons.link,
              size: 14,
              color: Colors.white10,
            ),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5),
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

            if (filteredUsers.isEmpty) return const SizedBox.shrink();
            
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredUsers.length > 10 ? 10 : filteredUsers.length,
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  final targetUser = filteredUsers[index];
                  final uid = targetUser['uid'] ?? targetUser['id'] ?? '';
                  return RecommendedFriendCard(
                    key: ValueKey<String>(uid),
                    user: targetUser,
                    onDismiss: () {
                      ref.read(dismissedRecommendationsProvider.notifier).dismiss(uid);
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
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF191B1D).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),

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
