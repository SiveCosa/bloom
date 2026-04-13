import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/media/avatar_image_helper.dart';
import '../../domain/auth/auth_providers.dart';

/// Profile tab: avatar (tap to update), username, name, temporary log out.
/// Bottom navigation is provided by [ShellScreen].
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _uploadAndSaveProfilePhoto(String localPath) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final file = File(localPath);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('avatar.jpg');
    await storageRef.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await storageRef.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
      {'profile_image_url': url},
    );
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final username = data?['username']?.toString() ?? '—';
          final name = data?['name']?.toString() ?? '—';
          final imageUrl = data?['profile_image_url']?.toString();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _uploading ? null : _onChangePhoto,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        backgroundImage: imageUrl != null &&
                                imageUrl.isNotEmpty &&
                                imageUrl.startsWith('http')
                            ? NetworkImage(imageUrl)
                            : null,
                        child: imageUrl == null ||
                                imageUrl.isEmpty ||
                                !imageUrl.startsWith('http')
                            ? const Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                    ),
                    if (_uploading)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _uploading ? null : _onChangePhoto,
                  child: const Text('Change profile photo'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Username',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Name',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(firebaseAuthProvider).signOut();
                    ref.read(signUpFormProvider.notifier).clearForm();
                    if (context.mounted) {
                      context.go('/auth/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0086D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
