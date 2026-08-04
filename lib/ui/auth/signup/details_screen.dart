import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';
import '../widgets/auth_app_bar.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_button.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
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

  String _selectedCampus = '';
  bool _hasCampusError = false;

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
      _birthdayDay != 'DD' &&
      _selectedCampus.isNotEmpty;

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
        height: _kStandardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? activeColor : Colors.white54,
                size: 20,
              ),
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
    final signupDataAsync = ref.watch(institutionSignupDataProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AuthAppBar(leftAction: AuthAppBarAction.cancel),
      body: Stack(
        children: [
          const GradientTopBar(height: 120),
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
                                'About You',
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

                              const Text(
                                'Username',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              RoundedTextField(
                                controller: _usernameController,
                                hintText: 'Username',
                                inputFormatters: [
                                  LowerCaseTextFormatter(),
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-z0-9._]'),
                                  ),
                                ],
                                errorMessage: _errorMessage,
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              const Text(
                                'Name:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              RoundedTextField(
                                controller: _nameController,
                                hintText: 'Your name',
                                onChanged: (_) => setState(() {}),
                              ),

                              const SizedBox(height: 16),

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
                              const SizedBox(height: 24),
                              const Text(
                                'Campus Name',
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
                                    _hasCampusError = false;
                                  });
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Container(
                                          width: MediaQuery.of(context).size.width - 40,
                                          constraints: const BoxConstraints(maxHeight: 250),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A1D24),
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: _kBorderColor, width: 1),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ListView.separated(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            separatorBuilder: (_, _) => Divider(
                                              color: Colors.white.withValues(alpha: 0.05),
                                              height: 1,
                                            ),
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(index);
                                              return ListTile(
                                                title: Text(
                                                  option,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                onTap: () => onSelected(option),
                                                hoverColor: Colors.white10,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                fieldViewBuilder: (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return RoundedTextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    hintText: 'Enter College or University name',
                                    errorMessage: _hasCampusError
                                        ? 'Enter a valid Campus name'
                                        : null,
                                    onChanged: (val) {
                                      if (val != _selectedCampus) {
                                        setState(() => _selectedCampus = '');
                                      }
                                      setState(() {});
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
                        isLoading: _isSubmitting,
                        onPressed: _isFormValid && !_isSubmitting
                            ? () async {
                                if (!campuses.contains(_selectedCampus)) {
                                  setState(() => _hasCampusError = true);
                                  return;
                                }

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
                                        gender: _genderValue ?? 'Prefer not to say',
                                      );
                                  ref
                                      .read(signUpFormProvider.notifier)
                                      .updateCampus(_selectedCampus);

                                  setState(() => _isSubmitting = false);
                                  context.go('/auth/signup/avatar');
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
