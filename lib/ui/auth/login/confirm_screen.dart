import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class ConfirmScreen extends ConsumerWidget {
  const ConfirmScreen({super.key});

  // Fetch the actual user data from the Firestore standard schema
  Future<Map<String, dynamic>?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.cancel,
        onCancel: () async {
          await FirebaseAuth.instance.signOut();
          ref.read(signUpFormProvider.notifier).clearForm();
          if (context.mounted) {
            context.go('/auth/login');
          }
        },
      ),
      // Wrap the UI in a FutureBuilder to await the database fetch
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          // Default loading states
          String displayUsername = "Loading...";
          String displayName = "Getting your details...";
          String? profileUrl;

          // Update values if fetch is successful
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData && snapshot.data != null) {
              displayUsername = snapshot.data!['username'] ?? '';
              displayName = snapshot.data!['name'] ?? '';
              profileUrl = snapshot.data!['profile_image_url'];
            } else {
              displayUsername = "User Not Found";
              displayName = "Please contact support";
            }
          }

          return Stack(
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
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
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
                        'Is this you?',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your next memory is one event away.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              backgroundImage:
                                  profileUrl != null && profileUrl.isNotEmpty
                                  ? NetworkImage(profileUrl)
                                  : null,
                              child: profileUrl == null || profileUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 80,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              displayUsername,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          // Disable button while loading
                          onPressed:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : () {
                                  context.go('/');
                                },
                          child:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
