import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/draw_tool.dart';
import 'package:homedesign/screens/object_painter.dart';
import 'package:homedesign/screens/save_list_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  bool isLocked = false;
  XFile? image;
  DrawTool selectedTool = DrawTool.freeLine;
  Color selectedColor = Colors.red;
  double strokeWidth = 4;
  List<DrawObject> objects = [];
  List<Offset> tempPoints = [];
  DrawObject? selectedObject;
  Offset? boxStart;
  Offset? boxEnd;
  bool isMovingSelection = false;
  Offset? zoomPoint;
  ui.Image? zoomedImage;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void initCamera() async {
    controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    await controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void addAutoDrawing() {
    // Add some basic auto-drawn shapes
    objects.addAll([
      DrawObject(
        id: 'auto_rect_${DateTime.now().millisecondsSinceEpoch}',
        points: [const Offset(100, 100), const Offset(200, 200)],
        color: Colors.blue,
        strokeWidth: 3,
        tool: DrawTool.rectangle,
      ),
      DrawObject(
        id: 'auto_circle_${DateTime.now().millisecondsSinceEpoch + 1}',
        points: [const Offset(250, 150), const Offset(300, 200)],
        color: Colors.green,
        strokeWidth: 3,
        tool: DrawTool.circle,
      ),
      DrawObject(
        id: 'auto_line_${DateTime.now().millisecondsSinceEpoch + 2}',
        points: [const Offset(50, 300), const Offset(350, 300)],
        color: Colors.red,
        strokeWidth: 2,
        tool: DrawTool.straightLine,
      ),
    ]);
    setState(() {});
  }

  Future<void> saveDrawing() async {
    if (objects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No drawing to save')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toIso8601String();
    final drawingData = {
      'objects': objects.map((obj) => obj.toJson()).toList(),
      'timestamp': timestamp,
    };
    final key = 'drawing_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(key, jsonEncode(drawingData));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drawing saved!')));
  }

  Future<void> loadDrawing(List<DrawObject> loadedObjects) async {
    setState(() {
      objects = loadedObjects;
      selectedObject = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drawing loaded!')));
  }

  Future<void> toggleLock() async {
    if (isLocked) {
      setState(() {
        image = null;
        isLocked = false;
        objects.clear(); // Clear objects when unlocking
        zoomedImage = null;
      });
      return;
    }

    final img = await controller.takePicture();
    if (!mounted) return;
    setState(() {
      image = img;
      isLocked = true;
    });

    // Load image for zoom preview
    final file = File(img.path);
    final imageBytes = await file.readAsBytes();
    zoomedImage = await decodeImageFromList(imageBytes);
    setState(() {});

    // Auto-draw basic shapes after locking
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Small delay for UX
    addAutoDrawing();
  }

  void onTapDown(TapDownDetails details) {
    final local = details.localPosition;
    final hitObject = hitTestObject(local);

    if (selectedTool == DrawTool.fillTool) {
      if (hitObject != null) {
        fillObject(hitObject);
      }
      return;
    }

    if (hitObject != null) {
      selectObject(hitObject);
    } else {
      deselectAll();
    }
  }

  void onLongPressStart(LongPressStartDetails details) {
    final hitObject = hitTestObject(details.localPosition);
    if (hitObject != null) {
      objects.remove(hitObject);
      if (selectedObject == hitObject) {
        selectedObject = null;
      }
      setState(() {});
    }
  }

  void onPanStart(DragStartDetails details) {
    final point = details.localPosition;
    if (selectedTool == DrawTool.boxSelect) {
      boxStart = point;
      boxEnd = point;
      setState(() {});
      return;
    }

    final hitObject = hitTestObject(point);
    if (hitObject != null && hitObject.isSelected) {
      isMovingSelection = true;
      return;
    }

    // Enable zoom for precise drawing tools
    if ([DrawTool.straightLine, DrawTool.rectangle, DrawTool.circle, DrawTool.triangle].contains(selectedTool)) {
      zoomPoint = point;
    }

    tempPoints = [point];
    setState(() {});
  }

  void onPanUpdate(DragUpdateDetails details) {
    final point = details.localPosition;
    if (isMovingSelection) {
      moveSelection(details.delta);
      return;
    }

    if (selectedTool == DrawTool.boxSelect) {
      boxEnd = point;
      setState(() {});
      return;
    }

    // Update zoom point for precise tools
    if (zoomPoint != null) {
      zoomPoint = point;
    }

    tempPoints.add(point);
    setState(() {});
  }

  void onPanEnd(DragEndDetails details) {
    if (isMovingSelection) {
      isMovingSelection = false;
      return;
    }

    if (selectedTool == DrawTool.boxSelect) {
      selectBox();
      return;
    }

    if (selectedTool == DrawTool.eraser) {
      if (tempPoints.isNotEmpty) {
        eraseAt(tempPoints.last);
      }
      tempPoints.clear();
      setState(() {});
      return;
    }

    if (selectedTool == DrawTool.fillTool) {
      tempPoints.clear();
      setState(() {});
      return;
    }

    if (tempPoints.isEmpty) return;
    final created = createPointsForTool(tempPoints);
    if (created.isNotEmpty) {
      objects.add(
        DrawObject(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          points: created,
          color: selectedColor,
          strokeWidth: strokeWidth,
          tool: selectedTool,
          fillColor: null,
          opacity: 1.0,
        ),
      );
    }

    tempPoints.clear();
    zoomPoint = null; // Clear zoom point after drawing
    setState(() {});
  }

  void selectBox() {
    if (boxStart == null || boxEnd == null) return;
    final rect = Rect.fromPoints(boxStart!, boxEnd!);
    for (var obj in objects) {
      if (obj.points.any(rect.contains)) {
        obj.isSelected = true;
        selectedObject = obj;
      }
    }
    boxStart = null;
    boxEnd = null;
    setState(() {});
  }

  void moveSelection(Offset delta) {
    for (var obj in objects.where((o) => o.isSelected)) {
      obj.points = obj.points.map((p) => p + delta).toList();
      obj.position += delta;
    }
    setState(() {});
  }

  void deleteSelected() {
    objects.removeWhere((o) => o.isSelected);
    selectedObject = null;
    setState(() {});
  }

  void deselectAll() {
    for (var obj in objects) {
      obj.isSelected = false;
    }
    selectedObject = null;
    setState(() {});
  }

  void selectObject(DrawObject object) {
    deselectAll();
    object.isSelected = true;
    selectedObject = object;
    setState(() {});
  }

  void changeColor(Color color) {
    selectedColor = color;
    for (var obj in objects.where((o) => o.isSelected)) {
      obj.color = color;
    }
    setState(() {});
  }

  void fillObject(DrawObject object) {
    object.fillColor = Color.fromRGBO(
      selectedColor.red,
      selectedColor.green,
      selectedColor.blue,
      0.35,
    );
    object.opacity = 0.35;
    object.isSelected = true;
    selectedObject = object;
    setState(() {});
  }

  void eraseAt(Offset point) {
    DrawObject? closest;
    var minDistance = double.infinity;
    for (var obj in objects) {
      final distance = obj.distanceTo(point);
      if (distance < minDistance) {
        minDistance = distance;
        closest = obj;
      }
    }
    if (closest != null && minDistance < 30) {
      objects.remove(closest);
      if (selectedObject == closest) {
        selectedObject = null;
      }
      setState(() {});
    }
  }

  DrawObject? hitTestObject(Offset point) {
    for (var obj in objects.reversed) {
      if (obj.hitTest(point)) {
        return obj;
      }
    }
    return null;
  }

  List<Offset> createPointsForTool(List<Offset> points) {
    if (points.isEmpty) return [];
    final start = points.first;
    final end = points.last;

    switch (selectedTool) {
      case DrawTool.straightLine:
        return [start, end];
      case DrawTool.rectangle:
        return [
          start,
          Offset(end.dx, start.dy),
          end,
          Offset(start.dx, end.dy),
          start,
        ];
      case DrawTool.circle:
        final radius = (end - start).distance;
        final segments = <Offset>[];
        for (var i = 0; i <= 32; i++) {
          final angle = (i / 32) * 2 * pi;
          segments.add(
            Offset(
              start.dx + radius * cos(angle),
              start.dy + radius * sin(angle),
            ),
          );
        }
        return segments;
      case DrawTool.triangle:
        return [
          start,
          Offset((start.dx + end.dx) / 2, start.dy - (end.dy - start.dy).abs()),
          end,
          start,
        ];
      case DrawTool.freeLine:
      case DrawTool.smoothLine:
        return List.from(points);
      default:
        return List.from(points);
    }
  }

  Widget buildToolButton(DrawTool tool, IconData icon) {
    final active = selectedTool == tool;
    return GestureDetector(
      onTap: () => setState(() => selectedTool = tool),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active
              ? Colors.blue.shade700
              : const Color.fromRGBO(255, 255, 255, 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: active ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget buildColorCircle(Color color) {
    final active = selectedColor == color;
    return GestureDetector(
      onTap: () => changeColor(color),
      child: Container(
        width: active ? 36 : 32,
        height: active ? 36 : 32,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.white : Colors.black26,
            width: active ? 3 : 1.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapDown: onTapDown,
                onLongPressStart: onLongPressStart,
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isLocked && image != null
                          ? Image.file(File(image!.path), fit: BoxFit.cover)
                          : CameraPreview(controller),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ObjectPainter(
                          objects,
                          tempPoints,
                          selectedTool,
                          tempPoints.isNotEmpty ? tempPoints.first : null,
                        ),
                      ),
                    ),
                    if (boxStart != null && boxEnd != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BoxSelectionPainter(boxStart!, boxEnd!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'lockCamera',
                        backgroundColor: Colors.white70,
                        onPressed: toggleLock,
                        child: Icon(isLocked ? Icons.lock : Icons.camera_alt),
                      ),
                      const SizedBox(width: 8),
                      if (isLocked) ...[
                        FloatingActionButton.small(
                          heroTag: 'saveDrawing',
                          backgroundColor: Colors.white70,
                          onPressed: saveDrawing,
                          child: const Icon(Icons.save),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'loadDrawing',
                          backgroundColor: Colors.white70,
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SaveListScreen(),
                              ),
                            );
                            if (result != null && result is List<DrawObject>) {
                              loadDrawing(result);
                            }
                          },
                          child: const Icon(Icons.list),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_toolIcon(selectedTool), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          selectedTool.toString().split('.').last,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (zoomPoint != null && zoomedImage != null)
              Positioned(
                top: 80,
                right: 20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CustomPaint(
                      size: const Size(120, 120),
                      painter: ZoomPainter(
                        zoomedImage,
                        zoomPoint,
                        tempPoints,
                        selectedColor,
                        strokeWidth,
                        selectedTool,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 170,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        buildColorCircle(Colors.red),
                        buildColorCircle(Colors.blue),
                        buildColorCircle(Colors.green),
                        buildColorCircle(Colors.amber),
                        buildColorCircle(Colors.purple),
                        buildColorCircle(Colors.white),
                      ],
                    ),
                    if (selectedObject != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: deleteSelected,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.line_weight, color: Colors.white70),
                    Expanded(
                      child: Slider(
                        value: strokeWidth,
                        min: 1,
                        max: 12,
                        divisions: 11,
                        activeColor: selectedColor,
                        inactiveColor: Colors.white30,
                        onChanged: (value) {
                          setState(() {
                            strokeWidth = value;
                          });
                        },
                      ),
                    ),
                    Text(
                      strokeWidth.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    buildToolButton(DrawTool.freeLine, Icons.brush),
                    buildToolButton(DrawTool.smoothLine, Icons.auto_fix_high),
                    buildToolButton(DrawTool.straightLine, Icons.show_chart),
                    buildToolButton(DrawTool.rectangle, Icons.crop_square),
                    buildToolButton(DrawTool.circle, Icons.circle),
                    buildToolButton(DrawTool.triangle, Icons.change_history),
                    buildToolButton(DrawTool.boxSelect, Icons.select_all),
                    buildToolButton(DrawTool.fillTool, Icons.format_color_fill),
                    buildToolButton(DrawTool.eraser, Icons.cleaning_services),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _toolIcon(DrawTool tool) {
    switch (tool) {
      case DrawTool.freeLine:
        return Icons.brush;
      case DrawTool.smoothLine:
        return Icons.auto_fix_high;
      case DrawTool.straightLine:
        return Icons.show_chart;
      case DrawTool.rectangle:
        return Icons.crop_square;
      case DrawTool.circle:
        return Icons.circle;
      case DrawTool.triangle:
        return Icons.change_history;
      case DrawTool.boxSelect:
        return Icons.select_all;
      case DrawTool.fillTool:
        return Icons.format_color_fill;
      case DrawTool.eraser:
        return Icons.cleaning_services;
      case DrawTool.square:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.ellipse:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.polygon:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.select:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.multiSelect:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.move:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.resize:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.rotate:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.delete:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.colorPicker:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.strokeWidth:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.wall:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.door:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.window:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.furniturePlace:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.snapToGrid:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.autoWallDetect:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DrawTool.autoRoomScan:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}

class ZoomPainter extends CustomPainter {
  final ui.Image? image;
  final Offset? zoomPoint;
  final List<Offset> tempPoints;
  final Color color;
  final double strokeWidth;
  final DrawTool tool;

  ZoomPainter(this.image, this.zoomPoint, this.tempPoints, this.color, this.strokeWidth, this.tool);

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null || zoomPoint == null) return;

    // Draw the zoomed image
    final paint = Paint();
    final zoomFactor = 3.0;
    final zoomedWidth = size.width / zoomFactor;
    final zoomedHeight = size.height / zoomFactor;
    final srcRect = Rect.fromCenter(
      center: zoomPoint!,
      width: zoomedWidth,
      height: zoomedHeight,
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image!, srcRect, dstRect, paint);

    // Draw the current drawing
    if (tempPoints.isNotEmpty) {
      final transformedPoints = tempPoints.map((p) => (p - zoomPoint!) * zoomFactor + Offset(size.width / 2, size.height / 2)).toList();
      final path = Path();
      path.moveTo(transformedPoints.first.dx, transformedPoints.first.dy);
      for (int i = 1; i < transformedPoints.length; i++) {
        path.lineTo(transformedPoints[i].dx, transformedPoints[i].dy);
      }
      canvas.drawPath(path, Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BoxSelectionPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _BoxSelectionPainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(0, 0, 255, 0.25)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
