import 'package:flutter/material.dart';
import 'package:homedesign/models/draw_tool.dart';

class ToolBar extends StatelessWidget {
  final DrawTool selectedTool;
  final ValueChanged<DrawTool> onToolSelected;

  const ToolBar({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
  });

  static const _tools = [
    (DrawTool.freeLine, Icons.brush_rounded, 'Free'),
    (DrawTool.smoothLine, Icons.auto_fix_high_rounded, 'Smooth'),
    (DrawTool.straightLine, Icons.show_chart_rounded, 'Line'),
    (DrawTool.select, Icons.near_me_rounded, 'Select'),
    (DrawTool.magicEraser, Icons.auto_awesome_rounded, 'Eraser+'),
    (DrawTool.boxSelect, Icons.select_all_rounded, 'Box'),
    (DrawTool.fillTool, Icons.format_color_fill_rounded, 'Fill'),
    (DrawTool.eraser, Icons.auto_fix_off_rounded, 'Erase'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final (tool, icon, label) = _tools[index];
          final isActive = selectedTool == tool;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 68 : 52,
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4F8EF7),
                        Color(0xFF6C63FF),
                      ],
                    )
                  : null,
              color: isActive
                  ? null
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4F8EF7)
                            .withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onToolSelected(tool),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color:
                        isActive ? Colors.white : Colors.white60,
                    size: isActive ? 22 : 20,
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isActive ? 9 : 8,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isActive
                          ? Colors.white
                          : Colors.white38,
                      letterSpacing: 0.3,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
