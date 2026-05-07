import 'package:flutter/material.dart';
import 'package:homedesign/models/draw_tool.dart';
import 'package:homedesign/models/paint_point.dart';

class PaintPainter extends CustomPainter {
  final List<PaintStroke> strokes;
  final List<Offset> currentPoints;
  final DrawTool tool;
  final Offset? startPoint;

  PaintPainter(this.strokes, this.currentPoints, this.tool, this.startPoint);

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      _draw(canvas, stroke.points, stroke.paint);
    }

    // live preview
    if (tool == DrawTool.straightLine &&
        startPoint != null &&
        currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startPoint!, currentPoints.last, paint);
    } else {
      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      _draw(canvas, currentPoints, paint);
    }
  }

  void _draw(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
