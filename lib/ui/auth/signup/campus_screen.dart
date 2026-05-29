import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_button.dart';

class CampusScreen extends ConsumerStatefulWidget {
  const CampusScreen({super.key});

  @override
  ConsumerState<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends ConsumerState<CampusScreen> {
  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.50);

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
          const GradientTopBar(showDarkOverlay: true),
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
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: ListView.separated(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                separatorBuilder: (_, _) =>
                                                    Divider(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.05,
                                                          ),
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
                                      return RoundedTextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        hintText:
                                            'Enter College or University name',
                                        errorMessage: _hasError
                                            ? 'Enter a valid Campus name'
                                            : null,
                                        onChanged: (val) {
                                          if (val != _selectedCampus) {
                                            setState(
                                              () => _selectedCampus = '',
                                            );
                                          }
                                        },
                                      );
                                    },
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                      BloomButton(
                        text: 'Continue',
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
