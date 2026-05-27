import 'package:flutter/material.dart';

class HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  const HeaderCell(this.text, {super.key, this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8A8A85),
        letterSpacing: 0.9,
      ),
    ),
  );
}

class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const StatChip({super.key, 
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}


class HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const HoverIconButton({super.key, 
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<HoverIconButton> createState() => HoverIconButtonState();
}

class HoverIconButtonState extends State<HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF0F0EE) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 18, color: const Color(0xFF8A8A85)),
        ),
      ),
    ),
  );
}

