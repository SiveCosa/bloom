import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/categories/category_providers.dart';
import '../widgets/auth_app_bar.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_button.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const double _kRadius = 100;
  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(signUpFormProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        rightAction: AuthAppBarAction.skip,
        onBack: () => context.go('/auth/signup/avatar'),
        onSkip: () => context.go('/auth/signup/permissions'),
      ),
      body: Stack(
        children: [
          const GradientTopBar(
            showDarkOverlay: true,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load interests.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                data: (categories) {
                  final query = _searchController.text.toLowerCase().trim();

                  return Column(
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
                                'What are your interests?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Select your interest from the list below. This will be used to curate events to your liking and interests.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              RoundedTextField(
                                controller: _searchController,
                                hintText: 'Search an interest',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.white54,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
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
                                        final isActive = formState.interests.contains(interest);
                                        return GestureDetector(
                                          onTap: () => ref
                                              .read(signUpFormProvider.notifier)
                                              .toggleInterest(interest),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.white
                                                  : Colors.white.withValues(alpha: 0.05),
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
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      BloomButton(
                        text: 'Continue',
                        onPressed: () =>
                            context.go('/auth/signup/permissions'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
