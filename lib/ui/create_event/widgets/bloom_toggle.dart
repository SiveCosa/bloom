import 'package:flutter/material.dart';

class BloomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BloomToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 21,
        decoration: BoxDecoration(
          color: value 
              ? Colors.white 
              : const Color(0xFF25282D).withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(12),
          border: value 
              ? null 
              : Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: value ? Colors.black : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
