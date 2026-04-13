import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  bool get _isOtpFilled => _controllers.every((c) => c.text.isNotEmpty);
  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(otpTimerProvider);
    final authState = ref.watch(authControllerProvider);
    final email = ref.watch(signUpFormProvider).email;
    final isLoading = authState is AsyncLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.back,
        onBack: () => context.go('/auth/login'),
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
                    '6-digit code',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'To confirm your student email, please enter the OTP sent to $email',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 55,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          onChanged: (val) => _onChanged(val, index),
                          decoration: InputDecoration(
                            counterText: "",
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFC151FD),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: timerState.canResend
                          ? () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .requestOtp(email, AuthOtpFlow.login);
                              ref.read(otpTimerProvider.notifier).start();
                            }
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.coreGradientColors[3],
                        disabledForegroundColor: AppTheme.coreGradientColors[3]
                            .withOpacity(0.5),
                      ),
                      child: Text(
                        '${timerState.formattedTime} Re-send code',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isOtpFilled && !isLoading)
                          ? () async {
                              try {
                                final isNewUser = await ref
                                    .read(authControllerProvider.notifier)
                                    .verifyOtp(email, _otpCode);
                                if (context.mounted) {
                                  if (isNewUser) {
                                    context.go('/auth/signup/details');
                                  } else {
                                    context.go('/auth/login/confirm');
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            }
                          : null,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
