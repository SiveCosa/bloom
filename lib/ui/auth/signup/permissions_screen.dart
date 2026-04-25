import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        onBack: () => context.go('/auth/signup/interests'),
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
                  Expanded(
                    child: SingleChildScrollView(
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
                            'We need your permission.',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'We require the following permissions for the app to function correctly. Please accept these permissions and find elaboration on our Privacy Policy',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildPermissionItem(
                            icon: Icons.location_on,
                            title: 'Location',
                            description:
                                'Used to determine events in your area',
                          ),
                          const SizedBox(height: 24),
                          _buildPermissionItem(
                            icon: Icons.favorite,
                            title: 'Interests',
                            description:
                                'Used to show and promote events you like',
                          ),
                          const SizedBox(height: 24),
                          _buildPermissionItem(
                            icon: Icons.contacts,
                            title: 'Contacts',
                            description:
                                'Used to connect you to pre-existing relationships',
                          ),
                          const SizedBox(height: 24),
                          _buildPermissionItem(
                            icon: Icons.camera_alt,
                            title: 'Camera & Gallery',
                            description:
                                'Required to allow you to add custom thumbnails to your events.',
                          ),
                          const SizedBox(height: 24),
                          _buildPermissionItem(
                            icon: Icons.notifications_active,
                            title: 'Notifications',
                            description:
                                'Required to share real time updates from Bloom.',
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              try {
                                final formData = ref.read(signUpFormProvider);
                                // This triggers your Firestore document creation!
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .createUserProfile(formData);

                                if (context.mounted) {
                                  // After database creation, route to the home shell
                                  context.go('/');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Profile creation failed: $e",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },

                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "By creating an account, I agree to Bloom ",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                        children: [
                          TextSpan(
                            text: "Terms of Service",
                            style: TextStyle(
                              color: AppTheme.coreGradientColors[3],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: " and "),
                          TextSpan(
                            text: "Privacy Policy",
                            style: TextStyle(
                              color: AppTheme.coreGradientColors[3],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: Colors.white),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
