import 'dart:math';
import 'package:flutter/material.dart';
import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/draw_tool.dart';

class ObjectPainter extends CustomPainter {
  final List<DrawObject> objects;
  final List<Offset> livePoints;
  final DrawTool currentTool;
  final Color liveColor;
  final double liveStrokeWidth;
  final Offset? boxStart;
  final Offset? boxEnd;

  ObjectPainter({
    required this.objects,
    required this.livePoints,
    required this.currentTool,
    required this.liveColor,
    required this.liveStrokeWidth,
    this.boxStart,
    this.boxEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in objects) {
      _drawObject(canvas, obj);
      _drawDimensions(canvas, obj);
    }

    if (livePoints.isNotEmpty &&
        currentTool != DrawTool.eraser &&
        currentTool != DrawTool.fillTool &&
        currentTool != DrawTool.boxSelect) {
      _drawLivePreview(canvas);
    }

    if (boxStart != null && boxEnd != null) {
      _drawBoxSelection(canvas, boxStart!, boxEnd!);
    }
  }

  void _drawObject(Canvas canvas, DrawObject obj) {
    if (obj.points.isEmpty) return;

    final path = _buildPath(obj.points, obj.tool);

    // Fill for closed shapes
    if (obj.fillColor != null &&
        (obj.tool == DrawTool.rectangle ||
            obj.tool == DrawTool.circle ||
            obj.tool == DrawTool.triangle)) {
      final fillPaint = Paint()
        ..color = obj.fillColor!.withValues(alpha: obj.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Selection glow halo
    if (obj.isSelected) {
      final glowPaint = Paint()
        ..color = const Color(0xFF4F8EF7).withValues(alpha: 0.28)
        ..strokeWidth = obj.strokeWidth + 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);
    }

    // Main stroke
    final strokePaint = Paint()
      ..color = obj.isSelected ? const Color(0xFF4F8EF7) : obj.color
      ..strokeWidth = obj.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Brighter border on selection
    if (obj.isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFF82B1FF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, borderPaint);

      _drawSelectionHandles(canvas, obj.bounds);
    }
  }

  void _drawDimensions(Canvas canvas, DrawObject obj) {
    if (obj.points.length < 2) return;

    // Scale: 100px = 1.0m (Simulated)
    const double scale = 0.01;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    void drawLabel(String text, Offset pos, double angle) {
      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);

      // Label background (Glass effect)
      final bgRect = Rect.fromLTWH(
        -textPainter.width / 2 - 6,
        -textPainter.height / 2 - 2,
        textPainter.width + 12,
        textPainter.height + 4,
      );
      final bgPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), bgPaint);

      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    if (obj.tool == DrawTool.straightLine ||
        obj.tool == DrawTool.freeLine ||
        obj.tool == DrawTool.smoothLine) {
      final p1 = obj.points.first;
      final p2 = obj.points.last;
      final dist = (p2 - p1).distance;
      if (dist < 20) return;

      final center = (p1 + p2) / 2;
      final angle = (p2 - p1).direction;
      final distMeters = (dist * scale).toStringAsFixed(2);
      drawLabel('${distMeters}m', center, angle);
    } else if (obj.tool == DrawTool.rectangle || obj.tool == DrawTool.square) {
      final rect = Rect.fromPoints(obj.points.first, obj.points.last);
      final w = (rect.width * scale).toStringAsFixed(2);
      final h = (rect.height * scale).toStringAsFixed(2);

      drawLabel('${w}m', Offset(rect.center.dx, rect.top - 12), 0);
      drawLabel('${h}m', Offset(rect.right + 12, rect.center.dy), pi / 2);
    }
  }

  void _drawSelectionHandles(Canvas canvas, Rect bounds) {
    final handleFill = Paint()
      ..color = const Color(0xFF4F8EF7)
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
      Offset(bounds.center.dx, bounds.top),
      Offset(bounds.center.dx, bounds.bottom),
      Offset(bounds.left, bounds.center.dy),
      Offset(bounds.right, bounds.center.dy),
    ];

    for (final c in corners) {
      canvas.drawCircle(c, 5, handleFill);
      canvas.drawCircle(c, 5, handleBorder);
    }
  }

  void _drawLivePreview(Canvas canvas) {
    final path = _buildPath(livePoints, currentTool);

    final paint = Paint()
      ..color = liveColor.withValues(alpha: 0.85)
      ..strokeWidth = liveStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    if (livePoints.isNotEmpty) {
      final dotPaint = Paint()
        ..color = liveColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(livePoints.first, 4, dotPaint);

      // Draw live dimensions
      if (livePoints.length >= 2) {
        final p1 = livePoints.first;
        final p2 = livePoints.last;
        final dist = (p2 - p1).distance;
        if (dist > 20) {
          final center = (p1 + p2) / 2;
          final angle = (p2 - p1).direction;
          final distMeters = (dist * 0.01).toStringAsFixed(2);
          
          final textPainter = TextPainter(
            text: TextSpan(
              text: '${distMeters}m',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(angle);
          textPainter.paint(canvas, Offset(-textPainter.width / 2, -15));
          canvas.restore();
        }
      }
    }
  }

  void _drawBoxSelection(Canvas canvas, Offset start, Offset end) {
    final rect = Rect.fromPoints(start, end);
    final fill = Paint()
      ..color = const Color(0xFF4F8EF7).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final border = Paint()
      ..color = const Color(0xFF4F8EF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashedRect(canvas, rect, border);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 4.0;

    void dashedLine(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total == 0) return;
      final dir = (to - from) / total;
      var travelled = 0.0;
      var draw = true;
      var cur = from;
      while (travelled < total) {
        final step = draw ? dashLen : gapLen;
        final next = min(step, total - travelled);
        final nxt = cur + dir * next;
        if (draw) canvas.drawLine(cur, nxt, paint);
        cur = nxt;
        travelled += next;
        draw = !draw;
      }
    }

    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);
  }

  Path _buildPath(List<Offset> points, DrawTool tool) {
    final path = Path();
    if (points.isEmpty) return path;

    switch (tool) {
      case DrawTool.straightLine:
        if (points.length >= 2) {
          path.moveTo(points.first.dx, points.first.dy);
          path.lineTo(points.last.dx, points.last.dy);
        }

      case DrawTool.rectangle:
      case DrawTool.square:
        if (points.length >= 2) {
          path.addRect(Rect.fromPoints(points.first, points.last));
        }

      case DrawTool.circle:
      case DrawTool.ellipse:
        if (points.length >= 2) {
          final center = points.first;
          final radius = (points.last - points.first).distance;
          path.addOval(Rect.fromCircle(center: center, radius: radius));
        }

      case DrawTool.triangle:
      case DrawTool.polygon:
        if (points.length >= 2) {
          final a = points.first;
          final b = points.last;
          final c = Offset((a.dx + b.dx) / 2, a.dy - (b.dy - a.dy).abs());
          path.moveTo(a.dx, a.dy);
          path.lineTo(b.dx, b.dy);
          path.lineTo(c.dx, c.dy);
          path.close();
        }

      case DrawTool.smoothLine:
        path.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          if (i + 1 < points.length) {
            final mid = Offset(
              (points[i].dx + points[i + 1].dx) / 2,
              (points[i].dy + points[i + 1].dy) / 2,
            );
            path.quadraticBezierTo(
                points[i].dx, points[i].dy, mid.dx, mid.dy);
          } else {
            path.lineTo(points[i].dx, points[i].dy);
          }
        }

      default:
        path.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant ObjectPainter oldDelegate) => true;
}
