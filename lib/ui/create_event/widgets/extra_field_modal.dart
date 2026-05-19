import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/event/event_extra.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_modal_shell.dart';

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
    return BloomModalShell(
      title: 'Extra Field',
      height: MediaQuery.of(context).size.height,
      useSafeArea: true,
      leftActionText: 'Clear',
      onLeftActionPressed: () {
        if (widget.initialExtra != null) {
          widget.onDelete?.call();
        }
        Navigator.pop(context);
      },
      rightActionText: 'Save',
      onRightActionPressed: _handleSave,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          SquareTextField(
            controller: _displayController,
            focusNode: _displayFocus,
            maxLength: 50,
            hintText: _currentType.displayHint,
            prefixIcon: Icon(
              _currentType.icon,
              color: Colors.white.withValues(alpha: 0.6),
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
                        color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
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

          SquareTextField(
            controller: _linkController,
            focusNode: _linkFocus,
            hintText: 'https://',
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
            errorMessage: _errorText,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
