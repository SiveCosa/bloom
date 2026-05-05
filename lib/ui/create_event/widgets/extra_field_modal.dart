import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/event/event_extra.dart';

class ExtraFieldModal extends StatefulWidget {
  final ExtraType initialType;
  final EventExtra? initialExtra;
  final Function(EventExtra) onSave;
  final VoidCallback? onDelete;

  const ExtraFieldModal({
    super.key,
    required this.initialType,
    this.initialExtra,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ExtraFieldModal> createState() => _ExtraFieldModalState();
}

class _ExtraFieldModalState extends State<ExtraFieldModal> {
  late ExtraType _currentType;
  late TextEditingController _displayController;
  late TextEditingController _linkController;
  FocusNode? _displayFocus;
  FocusNode? _linkFocus;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialExtra?.type ?? widget.initialType;
    _displayController = TextEditingController(text: widget.initialExtra?.displayText ?? '');
    _linkController = TextEditingController(text: widget.initialExtra?.url ?? '');
    _displayFocus = FocusNode()..addListener(_onFocusChange);
    _linkFocus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _displayController.dispose();
    _linkController.dispose();
    _displayFocus?.removeListener(_onFocusChange);
    _linkFocus?.removeListener(_onFocusChange);
    _displayFocus?.dispose();
    _linkFocus?.dispose();
    super.dispose();
  }

  void _handleSave() {
    final displayText = _displayController.text.trim();
    final linkText = _linkController.text.trim();

    if (_currentType.isLinkRequired && linkText.isEmpty) {
      setState(() {
        _errorText = 'Link is required for this type';
      });
      return;
    }

    widget.onSave(EventExtra(
      id: widget.initialExtra?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _currentType,
      displayText: displayText.isEmpty ? _currentType.displayHint : displayText,
      url: linkText.isEmpty ? null : linkText,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF191B1D),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        if (widget.initialExtra != null) {
                          widget.onDelete?.call();
                        }
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Extra Field',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleSave,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFF6C8EEF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Display Text Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_displayFocus?.hasFocus ?? false) ? Colors.white : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _displayController,
                  focusNode: _displayFocus,
                  maxLength: 100,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: Icon(_currentType.icon, color: Colors.white.withValues(alpha: 0.6)),
                    hintText: _currentType.displayHint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep it short and sweet here! Share more information in your event description.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 24),

              // Icon Selector Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ExtraType.values.map((type) {
                    final isSelected = _currentType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentType = type;
                            _errorText = null;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            type.icon,
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Link Label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _currentType.isLinkRequired ? 'Link (REQUIRED)' : 'Link (Optional)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Link Text Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorText != null 
                        ? Colors.redAccent 
                        : ((_linkFocus?.hasFocus ?? false) ? Colors.white : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _linkController,
                  focusNode: _linkFocus,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'https://',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
