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
  static const double _kStandardHeight = 48.0;

  static final Color _kBorderColor = Colors.white.withOpacity(0.50);

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
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: signupDataAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC151FD)),
                ),
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
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Center(
                                child: Image.asset(
                                  'assets/bloom_logo.png',
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Student from...',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your Campus name, like:\nEduvos Bedfordview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 40),
                              const Text(
                                'Campus name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue tev) {
                                  if (tev.text.isEmpty) return campuses;
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
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Container(
                                              width:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width -
                                                  40,
                                              constraints: const BoxConstraints(
                                                maxHeight: 250,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A1D24),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: _kBorderColor,
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: ListView.separated(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                separatorBuilder: (_, __) =>
                                                    Divider(
                                                      color: Colors.white
                                                          .withOpacity(0.05),
                                                      height: 1,
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final option = options
                                                      .elementAt(index);
                                                  return ListTile(
                                                    title: Text(
                                                      option,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    onTap: () =>
                                                        onSelected(option),
                                                    hoverColor: Colors.white10,
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                fieldViewBuilder:
                                    (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      return SizedBox(
                                        height: _kStandardHeight,
                                        child: TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          onChanged: (val) {
                                            if (val != _selectedCampus) {
                                              setState(
                                                () => _selectedCampus = '',
                                              );
                                            }
                                          },
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Enter College or University name',
                                            hintStyle: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 14,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                            isDense: true,
                                            errorText: _hasError
                                                ? 'Enter a valid Campus name'
                                                : null,
                                            // FIXED: Vertical padding 14 centers text in 48dp height
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 14,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _kRadius,
                                                  ),
                                              borderSide: BorderSide(
                                                color: _kBorderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _kRadius,
                                                  ),
                                              borderSide: BorderSide(
                                                color: _kBorderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _kRadius,
                                                  ),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFC151FD),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
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
                              disabledBackgroundColor: Colors.white10,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
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
