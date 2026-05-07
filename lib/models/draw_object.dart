import 'dart:math';

import 'package:flutter/material.dart';

import 'draw_tool.dart';

class DrawObject {
  final String id;
  List<Offset> points;
  Color color;
  double strokeWidth;
  DrawTool tool;
  bool isSelected;
  Color? fillColor;
  double opacity;
  Offset position;

  DrawObject({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    this.isSelected = false,
    this.fillColor,
    this.opacity = 1.0,
    Offset? position,
  }) : position = position ?? (points.isNotEmpty ? points.first : Offset.zero);

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);
    return Rect.fromLTRB(
      xs.reduce(min),
      ys.reduce(min),
      xs.reduce(max),
      ys.reduce(max),
    );
  }

  bool hitTest(Offset point) {
    if (points.isEmpty) return false;

    if (tool == DrawTool.rectangle ||
        tool == DrawTool.circle ||
        tool == DrawTool.triangle) {
      final path = Path()..addPolygon(points, true);
      if (path.contains(point)) {
        return true;
      }
    }

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (_distanceToSegment(point, a, b) < 24) {
        return true;
      }
    }

    return (point - points.first).distance < 24;
  }

  double distanceTo(Offset point) {
    if (points.isEmpty) return double.infinity;
    var minDistance = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final distance = _distanceToSegment(point, points[i], points[i + 1]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _distanceToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0.0) return (p - v).distance;
    final t =
        ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    if (t < 0) return (p - v).distance;
    if (t > 1) return (p - w).distance;
    final projection = Offset(
      v.dx + t * (w.dx - v.dx),
      v.dy + t * (w.dy - v.dy),
    );
    return (p - projection).distance;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': {'r': color.red, 'g': color.green, 'b': color.blue, 'a': color.alpha},
      'strokeWidth': strokeWidth,
      'tool': tool.toString().split('.').last,
      'isSelected': isSelected,
      'fillColor': fillColor != null ? {'r': fillColor!.red, 'g': fillColor!.green, 'b': fillColor!.blue, 'a': fillColor!.alpha} : null,
      'opacity': opacity,
      'position': {'dx': position.dx, 'dy': position.dy},
    };
  }

  factory DrawObject.fromJson(Map<String, dynamic> json) {
    return DrawObject(
      id: json['id'],
      points: (json['points'] as List<dynamic>).map((p) => Offset(p['dx'], p['dy'])).toList(),
      color: Color.fromARGB(
        json['color']['a'],
        json['color']['r'],
        json['color']['g'],
        json['color']['b'],
      ),
      strokeWidth: json['strokeWidth'],
      tool: DrawTool.values.firstWhere((e) => e.toString().split('.').last == json['tool']),
      isSelected: json['isSelected'] ?? false,
      fillColor: json['fillColor'] != null ? Color.fromARGB(
        json['fillColor']['a'],
        json['fillColor']['r'],
        json['fillColor']['g'],
        json['fillColor']['b'],
      ) : null,
      opacity: json['opacity'] ?? 1.0,
      position: Offset(json['position']['dx'], json['position']['dy']),
    );
  }
}
