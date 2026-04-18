import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  static const double _kRadius = 100;
  static const double _kFieldFontSize = 14;
  static const double _kStandardHeight = 48.0;

  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.50);

  static const TextStyle _kFieldTextStyle = TextStyle(
    fontSize: _kFieldFontSize,
    color: Colors.white,
  );

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final List<String> _days;
  late final List<String> _years;

  String _birthdayYear = 'YYYY';
  String _birthdayMonth = 'MMM';
  String _birthdayDay = 'DD';
  String? _genderValue;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _days = List.generate(
      31,
      (index) => (index + 1).toString().padLeft(2, '0'),
    );

    final currentYear = DateTime.now().year;
    final maxBirthYear = currentYear - 13;
    _years = List.generate(100, (index) => (maxBirthYear - index).toString());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _usernameController.text.isNotEmpty &&
      _nameController.text.isNotEmpty &&
      _birthdayYear != 'YYYY' &&
      _birthdayMonth != 'MMM' &&
      _birthdayDay != 'DD';

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white54,
        fontSize: _kFieldFontSize,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      // isDense false + vertical 0 + tight container height = true centering
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide(color: _kBorderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide(color: _kBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: Color(0xFFC151FD), width: 1.5),
      ),
    );
  }

  String? _yearValue() => _birthdayYear == 'YYYY' ? null : _birthdayYear;
  String? _monthValue() => _birthdayMonth == 'MMM' ? null : _birthdayMonth;
  String? _dayValue() => _birthdayDay == 'DD' ? null : _birthdayDay;

  Widget _buildDateDropdown({
    required String placeholder,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        height: _kStandardHeight, // MATCHES TEXT FIELD HEIGHT
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: _kBorderColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            hint: Text(
              placeholder,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: _kFieldFontSize,
              ),
            ),
            value: value,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 20,
            ),
            dropdownColor: const Color(0xFF1A1D24),
            style: _kFieldTextStyle,
            items: items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _genderRadioTile({
    required String label,
    required String value,
    required Color activeColor,
  }) {
    final selected = _genderValue == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _genderValue = selected ? null : value),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: _genderValue,
              toggleable: true,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _genderValue = v),
              activeColor: activeColor,
            ),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(signUpFormProvider).email;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AuthAppBar(
        leftAction: AuthAppBarAction.cancel,
        onCancel: () async {
          setState(() => _isSubmitting = true);
          try {
            await FirebaseAuth.instance.currentUser?.delete();
          } catch (_) {
            await FirebaseAuth.instance.signOut();
          }
          if (context.mounted) {
             ref.invalidate(authControllerProvider);
             ref.read(signUpFormProvider.notifier).clearForm();
             context.go('/auth/signup');
          }
        },
      ),
      body: Stack(
        children: [
          // Dynamic Blur Background
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
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
                            'Who are you?',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              text: 'Enter your account details,\n',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              children: [
                                TextSpan(
                                  text: email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Username Field
                          const Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: _kStandardHeight,
                            child: TextField(
                              controller: _usernameController,
                              style: _kFieldTextStyle,
                              maxLength: 30,
                              inputFormatters: [
                                LowerCaseTextFormatter(),
                                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9._]')),
                              ],
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _fieldDecoration('Username').copyWith(counterText: ''),
                              onChanged: (_) {
                                if (_errorMessage != null) setState(() => _errorMessage = null);
                              },
                            ),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 16.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Name Field
                          const Text(
                            'Name:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: _kStandardHeight,
                            child: TextField(
                              controller: _nameController,
                              style: _kFieldTextStyle,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _fieldDecoration('Your name'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Birthday Section
                          const Text(
                            'Birthday',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildDateDropdown(
                                placeholder: 'DD',
                                items: _days,
                                value: _dayValue(),
                                onChanged: (v) =>
                                    setState(() => _birthdayDay = v ?? 'DD'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '/',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                              _buildDateDropdown(
                                placeholder: 'MMM',
                                items: _months,
                                value: _monthValue(),
                                onChanged: (v) =>
                                    setState(() => _birthdayMonth = v ?? 'MMM'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '/',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                              _buildDateDropdown(
                                placeholder: 'YYYY',
                                items: _years,
                                value: _yearValue(),
                                onChanged: (v) =>
                                    setState(() => _birthdayYear = v ?? 'YYYY'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Gender Section
                          const Text(
                            'Gender (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _genderRadioTile(
                                label: 'Male',
                                value: 'Male',
                                activeColor: Colors.blue,
                              ),
                              _genderRadioTile(
                                label: 'Female',
                                value: 'Female',
                                activeColor: Colors.pink,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'If your gender is not provided you will be unable to access gender specific events unless invited.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),

                  // Primary Action Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52, // Slightly larger for the main action
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_isSubmitting
                            ? () async {
                                setState(() {
                                  _isSubmitting = true;
                                  _errorMessage = null;
                                });
                                try {
                                  await ref
                                      .read(authControllerProvider.notifier)
                                      .validateUsername(_usernameController.text);
                                      
                                  if (!context.mounted) return;
                                  ref
                                      .read(signUpFormProvider.notifier)
                                      .updateDetails(
                                        username: _usernameController.text,
                                        name: _nameController.text,
                                        birthday:
                                            '$_birthdayDay / $_birthdayMonth / $_birthdayYear',
                                        gender:
                                            _genderValue ?? 'Prefer not to say',
                                      );
                                  setState(() => _isSubmitting = false);
                                  context.go('/auth/signup/campus');
                                } on FirebaseFunctionsException catch (e) {
                                  if (!context.mounted) return;
                                  setState(() {
                                    _isSubmitting = false;
                                    if (e.code == 'already-exists') {
                                      _errorMessage = "This username is already taken";
                                    } else {
                                      _errorMessage = e.message ?? "Error validating username.";
                                    }
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() {
                                    _isSubmitting = false;
                                    _errorMessage = e.toString();
                                  });
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0086D8),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
