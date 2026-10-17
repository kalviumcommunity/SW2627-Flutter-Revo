import 'package:flutter/material.dart';
import '../constants/revo_colors.dart';
import '../constants/revo_spacing.dart';
import '../constants/revo_typography.dart';

/// Reusable Form Text Input Field.
/// Encapsulates consistent theme styling, validation error messaging,
/// and built-in password visibility toggling.
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.helperText,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  void _toggleObscure() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: RevoTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: RevoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: RevoTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: widget.prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: RevoColors.textTertiary,
                      size: 20,
                    ),
                    tooltip: _obscureText ? 'Show password' : 'Hide password',
                    onPressed: _toggleObscure,
                  )
                : widget.suffixIcon,
            filled: true,
            fillColor: widget.enabled
                ? RevoColors.surfaceContainerLowest
                : RevoColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: const OutlineInputBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
              borderSide: BorderSide(color: RevoColors.surfaceDim),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
              borderSide: BorderSide(color: RevoColors.surfaceDim),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
              borderSide: BorderSide(color: RevoColors.primary, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
              borderSide: BorderSide(color: RevoColors.errorCrimson, width: 1.5),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: RevoSpacing.borderRadiusButton,
              borderSide: BorderSide(color: RevoColors.errorCrimson, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}
