import 'package:flutter/material.dart';

/// A small tinted label, like the appointment status chip.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = HSLColor.fromColor(color).withLightness(0.28).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: text, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
