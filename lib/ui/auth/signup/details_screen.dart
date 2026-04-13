import 'package:flutter/material.dart';
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

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  static const double _kRadius = 100;
  static const double _kFieldFontSize = 14;
  static final Color _kBorderColor = Colors.white.withValues(alpha: 0.25);
  static const TextStyle _kFieldTextStyle = TextStyle(
    fontSize: _kFieldFontSize,
    color: Colors.white,
  );

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();

  static const List<String> _years = [
    '2005',
    '2004',
    '2003',
    '2002',
    '2001',
    '2000',
    '1999',
  ];

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

  String _birthdayYear = 'YYYY';
  String _birthdayMonth = 'MMM';
  String _birthdayDay = 'DD';
  String? _genderValue;

  @override
  void initState() {
    super.initState();
    _days = List.generate(
      31,
      (index) => (index + 1).toString().padLeft(2, '0'),
    );
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
      isDense: true,
      // Perfectly balances the text box with 10dp top/bottom padding
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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

  String? _yearValue() {
    if (_birthdayYear == 'YYYY') return null;
    return _years.contains(_birthdayYear) ? _birthdayYear : null;
  }

  String? _monthValue() {
    if (_birthdayMonth == 'MMM') return null;
    return _months.contains(_birthdayMonth) ? _birthdayMonth : null;
  }

  String? _dayValue() {
    if (_birthdayDay == 'DD') return null;
    return _days.contains(_birthdayDay) ? _birthdayDay : null;
  }

  Widget _buildDateDropdown({
    required String placeholder,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        // Dynamic height based on padding instead of fixed height
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
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
        onTap: () {
          setState(() {
            _genderValue = selected ? null : value;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: _genderValue,
                onChanged: (v) => setState(() => _genderValue = v),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return activeColor;
                  }
                  return Colors.white54;
                }),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? activeColor : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(signUpFormProvider).email;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AuthAppBar(leftAction: AuthAppBarAction.cancel),
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
              child: Column(
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
                            'Who are you?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 40),
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
                          const SizedBox(height: 32),
                          const Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            onChanged: (_) => setState(() {}),
                            style: _kFieldTextStyle,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: _fieldDecoration('Username'),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Name:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            style: _kFieldTextStyle,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: _fieldDecoration('Your name'),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Birthday',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildDateDropdown(
                                placeholder: 'YYYY',
                                items: _years,
                                value: _yearValue(),
                                onChanged: (v) => setState(() {
                                  _birthdayYear = v ?? 'YYYY';
                                }),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('/'),
                              ),
                              _buildDateDropdown(
                                placeholder: 'MMM',
                                items: _months,
                                value: _monthValue(),
                                onChanged: (v) => setState(() {
                                  _birthdayMonth = v ?? 'MMM';
                                }),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('/'),
                              ),
                              _buildDateDropdown(
                                placeholder: 'DD',
                                items: _days,
                                value: _dayValue(),
                                onChanged: (v) => setState(() {
                                  _birthdayDay = v ?? 'DD';
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Gender (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _genderRadioTile(
                                label: 'Male',
                                value: 'Male',
                                activeColor: Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              _genderRadioTile(
                                label: 'Female',
                                value: 'Female',
                                activeColor: Colors.pink,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'If your gender is not provided you will be unable to access gender specific events unless invited.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
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
                      onPressed: _isFormValid
                          ? () {
                              ref
                                  .read(signUpFormProvider.notifier)
                                  .updateDetails(
                                    username: _usernameController.text,
                                    name: _nameController.text,
                                    birthday:
                                        '$_birthdayYear / $_birthdayMonth / $_birthdayDay',
                                    gender:
                                        _genderValue != null &&
                                            _genderValue!.isNotEmpty
                                        ? _genderValue!
                                        : 'prefer not to say',
                                  );
                              context.go('/auth/signup/campus');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF0086D8,
                        ), // Restored the primary blue
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            20,
                          ), // 20dp border radius for a rounded rectangle
                        ),
                      ),
                      child: const Text('Continue'),
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
