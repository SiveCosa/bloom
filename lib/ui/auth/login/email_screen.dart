import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_button.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _emailController = TextEditingController();

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
    final domainsAsync = ref.read(allowedEmailDomainsProvider);
    domainsAsync.when(
      data: (domains) {
        setState(() {
          _errorMessage = null;
        });
      },
      loading: () => setState(() {
        _errorMessage = null;
      }),
      error: (err, st) => setState(() {
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
          const GradientTopBar(
            showDarkOverlay: true,
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
                  const SizedBox(height: 30),
                  RoundedTextField(
                    controller: _emailController,
                    hintText: 'student email',
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [LowerCaseTextFormatter()],
                    errorMessage: _errorMessage,
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
                  BloomButton(
                    text: 'Continue',
                    isLoading: isLoading,
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        setState(() {
                          _errorMessage =
                              "Please fill field with your student email";
                        });
                        return;
                      }
                      if (!domainsAsync.hasValue) {
                        return;
                      }
                      final domains = domainsAsync.requireValue;
                      if (!isEmailAllowedForInstitution(
                        email,
                        domains,
                      )) {
                        setState(() {
                          _errorMessage =
                              "Please use your Student Email";
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
                          if (e.code == 'not-found' ||
                              e.code == 'user-not-found') {
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
