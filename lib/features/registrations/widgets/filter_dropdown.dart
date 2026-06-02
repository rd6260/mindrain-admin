import 'package:flutter/material.dart';

class FilterDropdown extends StatelessWidget {
  final String value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F5),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFE4E4E0)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value.isEmpty ? '' : value,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1A1A1A),
          fontFamily: 'sans-serif',
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Color(0xFF8A8A85),
        ),
        isDense: true,
      ),
    ),
  );
}
