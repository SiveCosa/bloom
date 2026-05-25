import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/categories/category_providers.dart';
import '../../shared/widgets/custom_text_fields.dart';
import 'dart:ui' as ui;

class PreferencesEditorScreen extends ConsumerStatefulWidget {
  const PreferencesEditorScreen({super.key});

  @override
  ConsumerState<PreferencesEditorScreen> createState() =>
      _PreferencesEditorScreenState();
}

class _PreferencesEditorScreenState
    extends ConsumerState<PreferencesEditorScreen> {
  final List<String> _selectedInterests = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final profile = ref.watch(currentUserProfileProvider).value;
      final interests = profile?['interests'] as List<dynamic>?;
      if (interests != null) {
        _selectedInterests.addAll(interests.map((e) => e.toString()));
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).updateUserProfile({
        'interests': _selectedInterests,
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving interests: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const double _kRadius = 100;
  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

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
                  child: categoriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (categories) {
                      final query = _searchController.text.toLowerCase().trim();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'What are your interests?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Select common interests to help us recommend the best events for you.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 24),
                            RoundedTextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              hintText: 'Search an interest',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ...categories.map((category) {
                              final filteredTags = query.isEmpty
                                  ? category.tags
                                  : category.tags.where((i) => i.toLowerCase().contains(query)).toList();
                                  
                              if (filteredTags.isEmpty) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      category.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 12.0,
                                    children: filteredTags.map((interest) {
                                      final isActive = _selectedInterests.contains(interest);
                                      return GestureDetector(
                                        onTap: () => _toggleInterest(interest),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(_kRadius),
                                            border: Border.all(
                                              color: isActive ? Colors.white : _kBorderColor,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                interest,
                                                style: TextStyle(
                                                  color: isActive ? Colors.black : Colors.white,
                                                  fontWeight: isActive
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              if (isActive) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }),
                            const SizedBox(height: 48),
                            _buildSaveButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
                    },
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          const Text(
            'Interests',
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _save,

        child: const Text(
          'Save Interests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
