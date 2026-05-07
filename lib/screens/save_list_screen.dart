import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/draw_tool.dart';
import 'package:homedesign/screens/object_painter.dart';

class SaveListScreen extends StatefulWidget {
  const SaveListScreen({super.key});

  @override
  State<SaveListScreen> createState() => _SaveListScreenState();
}

class _SaveListScreenState extends State<SaveListScreen> {
  List<Map<String, dynamic>> savedDrawings = [];

  @override
  void initState() {
    super.initState();
    loadSavedDrawings();
  }

  Future<void> loadSavedDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('drawing_')).toList();
    savedDrawings = [];
    for (var key in keys) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        savedDrawings.add(data);
      }
    }
    setState(() {});
  }

  Future<void> deleteDrawing(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    loadSavedDrawings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Drawings'),
        backgroundColor: Colors.blue,
      ),
      body: savedDrawings.isEmpty
          ? const Center(child: Text('No saved drawings'))
          : ListView.builder(
              itemCount: savedDrawings.length,
              itemBuilder: (context, index) {
                final drawing = savedDrawings[index];
                final objects = (drawing['objects'] as List<dynamic>?)
                    ?.map((obj) => DrawObject.fromJson(obj as Map<String, dynamic>))
                    .toList() ?? [];
                final timestamp = drawing['timestamp'] as String? ?? 'Unknown';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: SizedBox(
                      width: 60,
                      height: 60,
                      child: CustomPaint(
                        painter: _ThumbnailPainter(objects),
                      ),
                    ),
                    title: Text('Drawing ${index + 1}'),
                    subtitle: Text('Saved: $timestamp'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteDrawing('drawing_$index'),
                    ),
                    onTap: () {
                      // Load the drawing back to camera screen
                      Navigator.pop(context, objects);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final List<DrawObject> objects;

  _ThumbnailPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 400; // Assume canvas width 400
    canvas.scale(scale);

    for (var obj in objects) {
      final paint = Paint()
        ..color = obj.color
        ..strokeWidth = obj.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = _buildPath(obj.points, obj.tool);
      canvas.drawPath(path, paint);
    }
  }

  Path _buildPath(List<Offset> points, DrawTool tool) {
    final path = Path();
    if (points.isEmpty) return path;

    if (tool == DrawTool.straightLine && points.length >= 2) {
      path.moveTo(points.first.dx, points.first.dy);
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    if (tool == DrawTool.rectangle && points.length >= 2) {
      path.addRect(Rect.fromPoints(points.first, points.last));
      return path;
    }

    if (tool == DrawTool.circle && points.length >= 2) {
      final center = points.first;
      final radius = (points.last - points.first).distance;
      path.addOval(Rect.fromCircle(center: center, radius: radius));
      return path;
    }

    if (tool == DrawTool.triangle && points.length >= 2) {
      final a = points.first;
      final b = points.last;
      final c = Offset((a.dx + b.dx) / 2, a.dy - (b.dy - a.dy).abs());
      path.moveTo(a.dx, a.dy);
      path.lineTo(b.dx, b.dy);
      path.lineTo(c.dx, c.dy);
      path.close();
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}