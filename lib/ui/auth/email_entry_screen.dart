import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/auth/auth_providers.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../shared/widgets/custom_text_fields.dart';
import '../shared/widgets/bloom_button.dart';

class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
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

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final _emailController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      await ref
          .read(emailOtpControllerProvider.notifier)
          .sendOtp(email, AuthOtpFlow.login);
      if (!mounted) return;
      
      // Update form state so OTP screen knows the email
      ref.read(signUpFormProvider.notifier).updateEmail(email);
      ref.read(otpTimerProvider.notifier).start();
      
      context.go('/auth/otp_verification');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(emailOtpControllerProvider);
    final isLoading = otpState is AsyncLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const GradientTopBar(showDarkOverlay: true),
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
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.spa, size: 65, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Welcome to Bloom',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Enter your email. We will send you a secure 6-digit confirmation code.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  RoundedTextField(
                    controller: _emailController,
                    hintText: 'your email address',
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [LowerCaseTextFormatter()],
                    errorMessage: _errorMessage,
                  ),
                  const Spacer(),
                  BloomButton(
                    text: 'Continue',
                    isLoading: isLoading,
                    onPressed: _submitEmail,
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
