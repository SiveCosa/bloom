import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

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
    final signupDataAsync = ref.watch(institutionSignupDataProvider);

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
              child: signupDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load interests.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                data: (signupData) {
                  final interests = signupData.interests;
                  final query = _searchController.text.toLowerCase().trim();
                  final filtered = query.isEmpty
                      ? interests
                      : interests
                          .where(
                            (i) => i.toLowerCase().contains(query),
                          )
                          .toList();

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
                              TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.white54,
                                  ),
                                  hintText: 'Search an interest',
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(_kRadius),
                                    borderSide: BorderSide(
                                      color: _kBorderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(_kRadius),
                                    borderSide: BorderSide(
                                      color: _kBorderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(_kRadius),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFC151FD),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 12.0,
                                children: filtered.map((interest) {
                                  final isActive =
                                      formState.interests.contains(interest);
                                  return GestureDetector(
                                    onTap: () => ref
                                        .read(signUpFormProvider.notifier)
                                        .toggleInterest(interest),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.white.withValues(
                                                alpha: 0.10,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                        borderRadius:
                                            BorderRadius.circular(_kRadius),
                                        border: Border.all(
                                          color: isActive
                                              ? Colors.white54
                                              : _kBorderColor,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            interest,
                                            style: TextStyle(
                                              color: Colors.white,
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
                                              color: Colors.white,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
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
                          onPressed: () =>
                              context.go('/auth/signup/permissions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0086D8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_kRadius),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
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
