import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import 'dart:ui' as ui;
import 'dart:io';
import '../../shared/widgets/bloom_button.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../../core/media/avatar_image_helper.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _instagramController;
  late TextEditingController _xController;
  late TextEditingController _snapchatController;

  bool _isLoading = false;
  bool _isInit = false;
  String _selectedGender = '';
  String? _localImagePath;
  String? _currentImageUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final profile = ref.watch(currentUserProfileProvider).value;
      if (profile != null) {
        _currentImageUrl = profile['profile_image_url'] as String?;
        _nameController = TextEditingController(text: profile['name'] ?? '');
        _usernameController = TextEditingController(
          text: profile['username'] ?? '',
        );
        _bioController = BioTextEditingController(
          maxLength: 250,
          text: profile['bio'] ?? '',
        );

        final socials = profile['social_links'] as Map<String, dynamic>?;
        _instagramController = TextEditingController(
          text: socials?['instagram'] ?? '',
        );
        _snapchatController = TextEditingController(
          text: socials?['snapchat'] ?? '',
        );
        // Using "tiktok" mapping from "x" for consistency if they are the same in DB,
        // but user specifically mentioned tiktok before.
        // Let's use 'tiktok' as the key since I saw it in the goal description.
        _xController = TextEditingController(
          text: socials?['x'] ?? socials?['tiktok'] ?? '',
        );

        final existingGender = profile['gender']?.toString();
        if (existingGender != null) {
          if (existingGender == 'male' || existingGender == 'female') {
            _selectedGender = existingGender;
          } else {
            _selectedGender = 'prefer not to say';
          }
        } else {
          _selectedGender = 'prefer not to say';
        }
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _xController.dispose();
    _snapchatController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    await showAvatarSourceSheet(
      context,
      onChosen: (source) async {
        final path = await pickAndCropSquareAvatar(source);
        if (!mounted) return;
        if (path != null) {
          setState(() {
            _localImagePath = path;
          });
        }
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final profile = ref.read(currentUserProfileProvider).value;
      final existingGender = profile?['gender']?.toString();

      final updates = {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'social_links': {
          'instagram': _instagramController.text.trim(),
          'x': _xController.text.trim(),
          'snapchat': _snapchatController.text.trim(),
        },
      };

      final newUsername = updates['username'] as String;
      if (profile?['username'] != newUsername) {
        try {
          await ref
              .read(authControllerProvider.notifier)
              .validateUsername(newUsername);
        } on FirebaseFunctionsException catch (e) {
          if (mounted) {
            String errorMessage = 'Error verifying username.';
            if (e.code == 'already-exists') {
              errorMessage = 'Username already in use.';
            } else if (e.code == 'invalid-argument') {
              errorMessage = 'Invalid username format.';
            } else {
              errorMessage = 'Error: ${e.message}';
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMessage)));
          }
          if (mounted) setState(() => _isLoading = false);
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error validating username: $e')),
            );
          }
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (existingGender != 'male' && existingGender != 'female') {
        if (_selectedGender == 'male' || _selectedGender == 'female') {
          if (!mounted) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2128),
              title: const Text(
                'Confirm Gender',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Are you sure you want to lock in this gender? You will not be able to change this again.',
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
                    'Lock in',
                    style: TextStyle(color: Color(0xFF0086D8)),
                  ),
                ),
              ],
            ),
          );
          if (confirm != true) {
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
        updates['gender'] = _selectedGender;
      }

      File? imageFile;
      if (_localImagePath != null) {
        imageFile = File(_localImagePath!);
      }

      await ref
          .read(authControllerProvider.notifier)
          .updateUserProfile(updates, imageFile: imageFile);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final existingGender = profile?['gender']?.toString();
    final bool isGenderLocked =
        existingGender == 'male' || existingGender == 'female';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
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
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildProfilePictureSection(false),
                        const SizedBox(height: 30),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                label: 'Name',
                                controller: _nameController,
                                hint: 'Enter your name',
                              ),
                              _buildTextField(
                                label: 'Username',
                                controller: _usernameController,
                                hint: 'Enter your username',
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Username cannot be empty';
                                  }
                                  if (val.contains(' ')) {
                                    return 'Username cannot contain spaces';
                                  }
                                  return null;
                                },
                              ),
                              _buildTextField(
                                label: 'Bio',
                                controller: _bioController,
                                hint: 'Enter your bio',
                                maxLines: 3,
                                maxLength: 250,
                                borderRadius:
                                    16, // Optional: slightly smaller for bio, but user said Name, Username, Gender, Socials. Let's make it 16 or 50. I'll pass 16 to keep styling okay, or I can pass 50. Wait, 16 is fine.
                              ),
                              _buildGenderSection(isGenderLocked),
                              const Text(
                                'Social Links',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildTextField(
                                label: 'Instagram',
                                controller: _instagramController,
                                hint: 'username',
                                prefixText: 'ig/ @',
                              ),
                              _buildTextField(
                                label: 'X (Twitter)',
                                controller: _xController,
                                hint: 'username',
                                prefixText: 'x/ @',
                              ),
                              _buildTextField(
                                label: 'Snapchat',
                                controller: _snapchatController,
                                hint: 'username',
                                prefixText: 'sc/ @',
                              ),
                              _buildPreferencesSection(),
                              const SizedBox(height: 40),
                              _buildSaveButton(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
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

  Widget _buildGenderSection(bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Gender',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.lock, size: 14, color: Colors.white24),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender.isEmpty ? null : _selectedGender,
              hint: const Text(
                'Select Gender',
                style: TextStyle(color: Colors.white24, fontSize: 14),
              ),
              dropdownColor: const Color(0xFF1E2128),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              isExpanded: true,
              onChanged: isLocked
                  ? null
                  : (val) => setState(() => _selectedGender = val ?? ''),
              items: ['male', 'female', 'prefer not to say'].map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(
                    g == 'prefer not to say'
                        ? 'Prefer not to say'
                        : g[0].toUpperCase() + g.substring(1),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProfilePictureSection(bool isLocked) {
    return Center(
      child: Stack(
        children: [
          buildAvatarImage(
            source: _localImagePath ?? _currentImageUrl,
            radius: 60,
          ),
          if (!isLocked)
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildEditIconButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: const Text(
              'Interests & Preferences',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Manage the events you see',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => context.push('/profile/preferences'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    double borderRadius = 15,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          validator: validator,
          buildCounter: maxLength != null
              ? (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) {
                  if (maxLength == null) return null;
                  final isOver = currentLength > maxLength;
                  return Text(
                    '$currentLength / $maxLength',
                    style: TextStyle(
                      color: isOver ? Colors.red : Colors.white54,
                      fontSize: 12,
                    ),
                  );
                }
              : null,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            counterText: maxLength == null ? "" : null,
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 14,
            ),
            prefixIcon: prefixText != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Text(
                      prefixText,
                      style: const TextStyle(
                        color: Color(0xFFC151FD), // Match brand
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.15),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: const BorderSide(
                color: Color(0xFFC151FD),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSaveButton() {
    return BloomButton(
      text: 'Save Changes',
      isLoading: _isLoading,
      onPressed: _save,
    );
  }

  Widget _buildEditIconButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFF0086D8), // Using the blue from ProfileScreen
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class BioTextEditingController extends TextEditingController {
  final int maxLength;

  BioTextEditingController({required this.maxLength, super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.length <= maxLength) {
      return TextSpan(style: style, text: text);
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, maxLength)),
        TextSpan(
          text: text.substring(maxLength),
          style:
              style?.copyWith(color: Colors.red) ??
              const TextStyle(color: Colors.red),
        ),
      ],
    );
  }
}
