import 'package:flutter/material.dart';

class ColorPalette extends StatefulWidget {
  final Color selectedColor;
  final double opacity;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;

  const ColorPalette({
    super.key,
    required this.selectedColor,
    required this.opacity,
    required this.onColorChanged,
    required this.onOpacityChanged,
  });

  @override
  State<ColorPalette> createState() => _ColorPaletteState();
}

class _ColorPaletteState extends State<ColorPalette>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  static const _colors = [
    Color(0xFFFF5252),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF80AB),
    Color(0xFF00BCD4),
    Color(0xFFFFFFFF),
    Color(0xFF212121),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animController.forward() : _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, right: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Color swatches
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((color) {
                    final isActive = widget.selectedColor == color;
                    return GestureDetector(
                      onTap: () => widget.onColorChanged(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: isActive ? 34 : 28,
                        height: isActive ? 34 : 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            width: isActive ? 3 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // Opacity slider
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.opacity,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 130,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: widget.selectedColor,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: widget.opacity,
                          min: 0.1,
                          max: 1.0,
                          onChanged: widget.onOpacityChanged,
                        ),
                      ),
                    ),
                    Text(
                      '${(widget.opacity * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // FAB toggle button
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.selectedColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.selectedColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: Icon(
              _expanded ? Icons.close : Icons.palette_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
