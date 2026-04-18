import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _emailController = TextEditingController();
  bool _isValidEmail = false;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text;
    final domainsAsync = ref.read(allowedEmailDomainsProvider);
    domainsAsync.when(
      data: (domains) {
        setState(() {
          _isValidEmail = isEmailAllowedForInstitution(email, domains);
          _errorMessage = null;
        });
      },
      loading: () => setState(() {
        _isValidEmail = false;
        _errorMessage = null;
      }),
      error: (err, st) => setState(() {
        _isValidEmail = false;
        _errorMessage = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(allowedEmailDomainsProvider, (prev, next) {
      _validateEmail();
    });
    final authState = ref.watch(authControllerProvider);
    final domainsAsync = ref.watch(allowedEmailDomainsProvider);
    final isLoading = authState is AsyncLoading || _isSubmitting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                    'Login to Bloom',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Enter your registered student email. We will send you a confirmation code there.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [LowerCaseTextFormatter()],
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        hintText: 'student email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.50),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.50),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(
                            color: Color(0xFFC151FD),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3.0, left: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  if (domainsAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                      child: Text(
                        'Could not load email rules. Check your connection.',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/auth/signup'),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: "Create one",
                              style: TextStyle(
                                color: AppTheme.coreGradientColors[3],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                setState(() {
                                  _errorMessage = "Please fill field with your student email";
                                });
                                return;
                              }
                              if (!domainsAsync.hasValue) {
                                return;
                              }
                              final domains = domainsAsync.requireValue;
                              if (!isEmailAllowedForInstitution(email, domains)) {
                                setState(() {
                                  _errorMessage = "Please use your Student Email";
                                });
                                return;
                              }
                              setState(() {
                                _errorMessage = null;
                                _isSubmitting = true;
                              });
                              try {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .requestOtp(email, AuthOtpFlow.login);
                                if (!context.mounted) return;
                                ref
                                    .read(signUpFormProvider.notifier)
                                    .updateEmail(email);
                                ref.read(otpTimerProvider.notifier).start();
                                setState(() => _isSubmitting = false);
                                context.go('/auth/login/otp');
                              } on FirebaseFunctionsException catch (e) {
                                if (!context.mounted) return;
                                setState(() {
                                  _isSubmitting = false;
                                  if (e.code == 'not-found' || e.code == 'user-not-found') {
                                    _errorMessage = "Email does not exist";
                                  } else if (e.code == 'failed-precondition' &&
                                      e.message != null &&
                                      e.message!.isNotEmpty) {
                                    _errorMessage = e.message;
                                  } else {
                                    _errorMessage = e.message ?? e.toString();
                                  }
                                });
                              } catch (e) {
                                if (context.mounted) {
                                  setState(() {
                                    _isSubmitting = false;
                                    _errorMessage = e.toString();
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
