import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoundedTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorMessage;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final bool showCounter;

  final int? maxLength;
  final int? maxLines;

  const RoundedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.errorMessage,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.height = 48,
    this.borderRadius = 100, // Default to pill shape
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 0,
    ),
    this.showCounter = false,
    this.maxLength,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            maxLength: maxLength,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              contentPadding: contentPadding,
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              counterText: showCounter ? null : "",
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 3.0, left: 16.0),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class SquareTextField extends RoundedTextField {
  const SquareTextField({
    super.key,
    super.controller,
    super.focusNode,
    super.hintText,
    super.keyboardType,
    super.inputFormatters,
    super.errorMessage,
    super.obscureText,
    super.prefixIcon,
    super.suffixIcon,
    super.onChanged,
    super.onSubmitted,
    super.height,
    super.borderRadius = 15, // Square with 15 radius
    super.contentPadding,
    super.showCounter = false,
    super.maxLength,
    super.maxLines,
  });
}
