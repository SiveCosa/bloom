import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class CampusScreen extends ConsumerStatefulWidget {
  const CampusScreen({super.key});

  @override
  ConsumerState<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends ConsumerState<CampusScreen> {
  static const double _kRadius = 100;
  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.25);

  bool _hasError = false;
  String _selectedCampus = '';

  @override
  Widget build(BuildContext context) {
    final signupDataAsync = ref.watch(institutionSignupDataProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        onBack: () => context.go('/auth/signup/details'),
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
                    'Could not load campuses.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                data: (signupData) {
                  final campuses = signupData.campuses;
                  if (campuses.isEmpty) {
                    return const Center(
                      child: Text(
                        'No campuses are configured for your institution yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

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
                                'Student from...',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your Campus name, like:\nEduvos Bedfordview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Campus name',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue tev) {
                                  if (tev.text.isEmpty) {
                                    return campuses;
                                  }
                                  final q = tev.text.toLowerCase();
                                  return campuses.where(
                                    (o) => o.toLowerCase().contains(q),
                                  );
                                },
                                onSelected: (String selection) {
                                  setState(() {
                                    _selectedCampus = selection;
                                    _hasError = false;
                                  });
                                },
                                fieldViewBuilder: (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (_) {
                                      if (controller.text != _selectedCampus) {
                                        setState(() => _selectedCampus = '');
                                      }
                                    },
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Enter College or University name',
                                      hintStyle:
                                          const TextStyle(color: Colors.white54),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.05),
                                      errorText: _hasError
                                          ? 'Enter a valid Campus name'
                                          : null,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
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
                                  );
                                },
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
                          onPressed: () {
                            if (!campuses.contains(_selectedCampus)) {
                              setState(() => _hasError = true);
                            } else {
                              ref
                                  .read(signUpFormProvider.notifier)
                                  .updateCampus(_selectedCampus);
                              context.go('/auth/signup/avatar');
                            }
                          },
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
