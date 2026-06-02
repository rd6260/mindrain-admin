
import 'package:flutter/material.dart';

class PaidBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final Color bgActive;
  final Color bgInactive;
  final VoidCallback onTap;

  const PaidBadge({
    super.key,
    required this.label,
    required this.active,
    required this.color,
    required this.bgActive,
    this.bgInactive = const Color(0xFFF0F0EE),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? bgActive : bgInactive,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : color,
        ),
      ),
    ),
  );
}
