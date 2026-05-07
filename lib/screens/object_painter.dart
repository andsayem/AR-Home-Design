import 'package:flutter/material.dart';
import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/draw_tool.dart';

class ObjectPainter extends CustomPainter {
  final List<DrawObject> objects;
  final List<Offset> livePoints;
  final DrawTool currentTool;
  final Offset? startPoint;

  ObjectPainter(
    this.objects,
    this.livePoints,
    this.currentTool,
    this.startPoint,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in objects) {
      final path = _buildPath(obj.points, obj.tool);

      // ---------------- FILL ----------------
      if (_canFill(obj)) {
        final fill = Paint()
          ..color = (obj.fillColor ?? Colors.transparent).withOpacity(
            obj.opacity,
          )
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, fill);
      }

      // ---------------- STROKE ----------------
      final stroke = Paint()
        ..color = obj.isSelected ? Colors.blueAccent : obj.color
        ..strokeWidth = obj.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, stroke);

      // ---------------- SELECTION GLOW ----------------
      if (obj.isSelected) {
        final glow = Paint()
          ..color = Colors.blue.withOpacity(0.25)
          ..strokeWidth = obj.strokeWidth + 6
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, glow);
      }
    }

    // ---------------- LIVE DRAWING ----------------
    if (livePoints.length > 1) {
      final livePath = _buildPath(livePoints, currentTool);

      final livePaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(livePath, livePaint);
    }
  }

  // ================= PATH BUILDER =================

  Path _buildPath(List<Offset> points, DrawTool tool) {
    final path = Path();
    if (points.isEmpty) return path;

    final start = points.first;
    final end = points.last;

    switch (tool) {
      case DrawTool.straightLine:
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
        return path;

      case DrawTool.rectangle:
        path.addRect(Rect.fromPoints(start, end));
        return path;

      case DrawTool.circle:
        final radius = (end - start).distance;
        path.addOval(Rect.fromCircle(center: start, radius: radius));
        return path;

      case DrawTool.triangle:
        final a = start;
        final b = end;
        final c = Offset((a.dx + b.dx) / 2, a.dy - (b.dy - a.dy).abs());

        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close();

        return path;

      case DrawTool.smoothLine:
        _buildSmooth(path, points);
        return path;

      default:
        path.moveTo(start.dx, start.dy);
        for (var i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        return path;
    }
  }

  // ================= SMOOTH LINE FIX =================

  void _buildSmooth(Path path, List<Offset> points) {
    if (points.length < 2) return;

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    path.lineTo(points.last.dx, points.last.dy);
  }

  // ================= HELPERS =================

  bool _canFill(DrawObject obj) {
    return obj.fillColor != null &&
        (obj.tool == DrawTool.rectangle ||
            obj.tool == DrawTool.circle ||
            obj.tool == DrawTool.triangle);
  }

  @override
  bool shouldRepaint(covariant ObjectPainter oldDelegate) {
    return true;
  }
}
