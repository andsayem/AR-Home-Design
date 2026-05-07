import 'package:flutter/material.dart';

class StrokeSlider extends StatelessWidget {
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const StrokeSlider({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.line_weight_rounded,
              color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: color,
                inactiveTrackColor: Colors.white12,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 16,
                divisions: 15,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Live preview dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: value.clamp(4, 20),
            height: value.clamp(4, 20),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              value.round().toString(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
