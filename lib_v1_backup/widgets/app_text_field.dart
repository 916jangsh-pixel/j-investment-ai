import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: appInputDecoration(label, hint: hint),
    );
  }
}

InputDecoration appInputDecoration(
  String label, {
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFF161B22),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }
  return null;
}

String? numberValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }

  final normalized = value.trim().replaceAll(',', '');
  final parsed = double.tryParse(normalized);

  if (parsed == null || parsed <= 0) {
    return '0보다 큰 숫자를 입력해주세요.';
  }

  return null;
}

String? integerValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }

  final parsed = int.tryParse(value.trim());

  if (parsed == null || parsed <= 0) {
    return '1 이상의 정수를 입력해주세요.';
  }

  return null;
}
