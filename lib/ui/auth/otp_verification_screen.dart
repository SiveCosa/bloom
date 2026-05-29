import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../domain/auth/auth_providers.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/gradient_top_bar.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyOtp(String otp) async {
    final email = ref.read(signUpFormProvider).email;
    if (email.isEmpty) {
      if (mounted) context.go('/auth/email_entry');
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final isNewUser = await ref
          .read(emailOtpControllerProvider.notifier)
          .verifyOtpAndSignIn(email, otp);
      
      if (!mounted) return;
      ref.read(otpTimerProvider.notifier).stop();
      
      if (isNewUser) {
        context.go('/auth/signup/details'); // Or wherever onboarding starts
      } else {
        context.go('/home'); // Or main shell
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
        });
        _pinController.clear();
        _focusNode.requestFocus();
      }
    }
  }

  void _resendCode() async {
    final email = ref.read(signUpFormProvider).email;
    if (email.isEmpty) return;

    try {
      await ref.read(emailOtpControllerProvider.notifier).sendOtp(email, AuthOtpFlow.login);
      if (mounted) {
        ref.read(otpTimerProvider.notifier).start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend code: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(signUpFormProvider).email;
    final timerState = ref.watch(otpTimerProvider);
    final isSubmitting = ref.watch(emailOtpControllerProvider) is AsyncLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.coreGradientColors[3], width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.redAccent, width: 2),
    );

    return Scaffold(
      body: Stack(
        children: [
          const GradientTopBar(showDarkOverlay: true),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        ref.read(otpTimerProvider.notifier).stop();
                        context.pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      children: [
                        const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                        TextSpan(
                          text: email,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Pinput(
                    length: 6,
                    controller: _pinController,
                    focusNode: _focusNode,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    errorPinTheme: errorPinTheme,
                    forceErrorState: _errorMessage != null,
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                    onCompleted: _verifyOtp,
                    readOnly: isSubmitting,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (isSubmitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 20.0),
                      child: CircularProgressIndicator(),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive code? ",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: timerState.canResend && !isSubmitting ? _resendCode : null,
                        child: Text(
                          timerState.canResend
                              ? 'Resend Code'
                              : 'Resend in ${timerState.formattedTime}',
                          style: TextStyle(
                            color: timerState.canResend && !isSubmitting
                                ? AppTheme.coreGradientColors[3]
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
