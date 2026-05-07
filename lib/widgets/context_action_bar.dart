import 'package:flutter/material.dart';

class ContextActionBar extends StatelessWidget {
  final bool hasSelection;
  final bool hasMultipleSelection;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onFill;
  final VoidCallback onDeselect;

  const ContextActionBar({
    super.key,
    required this.hasSelection,
    required this.hasMultipleSelection,
    required this.onDelete,
    required this.onDuplicate,
    required this.onFill,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: hasSelection ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: hasSelection ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !hasSelection,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4F8EF7).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F8EF7).withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Deselect',
                  color: Colors.white60,
                  onTap: onDeselect,
                ),
                _Divider(),
                _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Clone',
                  color: const Color(0xFF4F8EF7),
                  onTap: onDuplicate,
                ),
                _Divider(),
                _ActionButton(
                  icon: Icons.format_color_fill_rounded,
                  label: 'Paint',
                  color: const Color(0xFF6C63FF),
                  onTap: onFill,
                ),
                _Divider(),
                _ActionButton(
                  icon: Icons.delete_sweep_rounded,
                  label: 'REMOVE',
                  color: const Color(0xFFFF5252),
                  onTap: onDelete,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isBold;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
