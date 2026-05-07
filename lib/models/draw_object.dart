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
  int zIndex;

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
    this.zIndex = 0,
  }) : position = position ?? (points.isNotEmpty ? points.first : Offset.zero);

  DrawObject copyWith({
    String? id,
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    DrawTool? tool,
    bool? isSelected,
    Color? fillColor,
    double? opacity,
    Offset? position,
    int? zIndex,
  }) {
    return DrawObject(
      id: id ?? this.id,
      points: points ?? List.from(this.points),
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      isSelected: isSelected ?? this.isSelected,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
      position: position ?? this.position,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'tool': tool.name,
        'isSelected': false, // never persist selected state
        'fillColor': fillColor?.toARGB32(),
        'opacity': opacity,
        'positionDx': position.dx,
        'positionDy': position.dy,
        'zIndex': zIndex,
      };

  factory DrawObject.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>)
        .map((p) => Offset(
              (p['dx'] as num).toDouble(),
              (p['dy'] as num).toDouble(),
            ))
        .toList();
    final fc = json['fillColor'] as int?;
    return DrawObject(
      id: json['id'] as String,
      points: pts,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      tool: DrawTool.values.firstWhere(
        (t) => t.name == json['tool'],
        orElse: () => DrawTool.freeLine,
      ),
      fillColor: fc != null ? Color(fc) : null,
      opacity: (json['opacity'] as num? ?? 1.0).toDouble(),
      position: Offset(
        (json['positionDx'] as num? ?? 0).toDouble(),
        (json['positionDy'] as num? ?? 0).toDouble(),
      ),
      zIndex: (json['zIndex'] as int? ?? 0),
    );
  }

  // ── Geometry ───────────────────────────────────────────────────────────────

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);
    return Rect.fromLTRB(
      xs.reduce(min),
      ys.reduce(min),
      xs.reduce(max),
      ys.reduce(max),
    );
  }

  Rect get expandedBounds => bounds.inflate(16);

  bool hitTest(Offset point) {
    if (points.isEmpty) return false;
    if (tool == DrawTool.rectangle ||
        tool == DrawTool.circle ||
        tool == DrawTool.triangle) {
      if (expandedBounds.contains(point)) return true;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (_distanceToSegment(point, points[i], points[i + 1]) < 24) {
        return true;
      }
    }
    if (points.length == 1) return (point - points.first).distance < 24;
    return false;
  }

  double distanceTo(Offset point) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) return (point - points.first).distance;
    var minD = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegment(point, points[i], points[i + 1]);
      if (d < minD) minD = d;
    }
    return minD;
  }

  double _distanceToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0.0) return (p - v).distance;
    final t = ((p.dx - v.dx) * (w.dx - v.dx) +
            (p.dy - v.dy) * (w.dy - v.dy)) /
        l2;
    final tc = t.clamp(0.0, 1.0);
    final proj =
        Offset(v.dx + tc * (w.dx - v.dx), v.dy + tc * (w.dy - v.dy));
    return (p - proj).distance;
  }
}
