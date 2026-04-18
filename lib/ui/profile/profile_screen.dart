import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/media/avatar_image_helper.dart';
import '../../domain/auth/auth_providers.dart';

/// Profile tab: avatar (tap to update), username, name, log out, delete account.
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

  Future<void> _logout() async {
    await ref.read(firebaseAuthProvider).signOut();
    ref.read(signUpFormProvider.notifier).clearForm();
    if (mounted) {
      context.go('/auth/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
             onPressed: () => Navigator.pop(ctx, true),
             child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Attempt to delete auth user natively. Requires recent login.
          await user.delete();
          await FirebaseAuth.instance.signOut();
          ref.read(signUpFormProvider.notifier).clearForm();
          if (mounted) {
            context.go('/auth/login');
          }
        } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Failed to delete account. You may need to log in again to verify your identity. Error: $e')),
             );
          }
        }
      }
    }
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
                  onPressed: _logout,
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text('Delete Account'),
                ),
              ),
              // Extra space at bottom to not stick to the nav bar
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
