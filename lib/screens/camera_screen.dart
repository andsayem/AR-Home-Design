import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/draw_tool.dart';
import 'package:homedesign/models/sticker_item.dart';
import 'package:homedesign/screens/object_painter.dart';
import 'package:homedesign/utils/undo_manager.dart';
import 'package:homedesign/widgets/color_palette.dart';
import 'package:homedesign/widgets/context_action_bar.dart';
import 'package:homedesign/widgets/furniture_picker.dart';
import 'package:homedesign/widgets/sticker_layer.dart';
import 'package:homedesign/widgets/stroke_slider.dart';
import 'package:homedesign/widgets/tool_bar.dart';
import 'package:homedesign/widgets/help_overlay.dart';
import 'package:homedesign/models/project_model.dart';
import 'package:homedesign/screens/save_list_screen.dart';
import 'package:homedesign/utils/image_processor.dart';
import 'package:homedesign/utils/save_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  // ─── Camera ──────────────────────────────────────────────────────────────
  late CameraController _controller;
  bool _cameraReady = false;
  bool _isLocked = false;
  XFile? _capturedImage;

  // ─── Drawing ─────────────────────────────────────────────────────────────
  final List<DrawObject> _objects = [];
  final List<Offset> _tempPoints = [];
  final _undoMgr = UndoManager();
  final _uuid = const Uuid();

  // ─── Tool state ──────────────────────────────────────────────────────────
  DrawTool _selectedTool = DrawTool.freeLine;
  Color _selectedColor = const Color(0xFF4F8EF7);
  double _strokeWidth = 4;
  double _fillOpacity = 0.35;

  // ─── Selection ───────────────────────────────────────────────────────────
  DrawObject? _selectedObject;
  Offset? _boxStart;
  Offset? _boxEnd;
  bool _isMovingSelection = false;

  // ─── Stickers ────────────────────────────────────────────────────────────
  final List<StickerItem> _stickers = [];
  String? _selectedStickerId;
  double _stickerSize = 52;
  double _stickerRotation = 0;
  double _stickerOpacity = 1.0;

  // ─── Magic Eraser (AI) ───────────────────────────────────────────────────
  final List<List<Offset>> _maskPaths = []; // Multiple strokes for masking
  List<Offset> _currentMaskPath = [];
  bool _isProcessingAI = false;
  bool _showHelp = false;

  // ─── Persistence ─────────────────────────────────────────────────────────
  String? _currentProjectId;
  String _currentProjectName = 'Untitled Plan';

  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initCamera();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('first_run') ?? true;
    if (isFirst) {
      setState(() => _showHelp = true);
      await prefs.setBool('first_run', false);
    }
  }

  Future<void> _exportToImage() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/design_${DateTime.now().millisecondsSinceEpoch}.png').writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Design exported to: ${file.path}'),
            backgroundColor: const Color(0xFF4F8EF7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
    }
  }

  Future<void> _openGallery() async {
    final ProjectModel? loaded = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SaveListScreen()),
    );

    if (loaded != null && mounted) {
      setState(() {
        _currentProjectId = loaded.id;
        _currentProjectName = loaded.name;
        _objects.clear();
        _objects.addAll(loaded.objects);
        _stickers.clear();
        _stickers.addAll(loaded.stickers);
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _saveProject() async {
    final nameController = TextEditingController(text: _currentProjectName);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Save Design', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Project Name',
            labelStyle: TextStyle(color: Colors.white60),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF4F8EF7))),
          ),
        ],
      ),
    );

    if (shouldSave == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      final project = ProjectModel(
        id: _currentProjectId ?? const Uuid().v4(),
        name: name,
        imagePath: _capturedImage?.path,
        objects: List.from(_objects),
        stickers: List.from(_stickers),
        createdAt: DateTime.now(),
      );

      await SaveManager.saveProject(project);

      setState(() {
        _currentProjectId = project.id;
        _currentProjectName = project.name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$name" successfully!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_cameraReady) _controller.dispose();
    super.dispose();
  }

  // ─── Camera ──────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _toggleLock() async {
    HapticFeedback.mediumImpact();
    if (_isLocked) {
      setState(() {
        _capturedImage = null;
        _isLocked = false;
      });
      return;
    }
    try {
      final img = await _controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImage = img;
        _isLocked = true;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  // ─── Helper: is this a shape-drawing tool? ─────────────────────────────
  bool get _isDrawingTool {
    const drawTools = {
      DrawTool.freeLine,
      DrawTool.smoothLine,
      DrawTool.straightLine,
      DrawTool.rectangle,
      DrawTool.circle,
      DrawTool.triangle,
      DrawTool.magicEraser,
    };
    return drawTools.contains(_selectedTool);
  }

  // ─── Gesture handlers ────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails d) {
    if (_isProcessingAI) return;
    final pos = d.localPosition;

    // 1. Check for stickers first (always on top)
    for (final s in _stickers.reversed) {
      final rect = Rect.fromCenter(
          center: Offset(s.x, s.y), width: s.size, height: s.size);
      if (rect.contains(pos)) {
        _selectSticker(s.id);
        return;
      }
    }

    // 2. Fill tool: apply fill on tap
    if (_selectedTool == DrawTool.fillTool) {
      final hit = _hitTest(pos);
      if (hit != null) _fillObject(hit);
      return;
    }

    // 3. Eraser tool: erase on tap
    if (_selectedTool == DrawTool.eraser) {
      _eraseAt(pos);
      return;
    }

    // 4. Select tool / Drawing tools: tap selects/deselects objects
    final hit = _hitTest(pos);
    if (hit != null) {
      _selectObject(hit);
    } else {
      _deselectAll();
    }
  }

  void _onLongPressStart(LongPressStartDetails d) {
    HapticFeedback.heavyImpact();
    final hit = _hitTest(d.localPosition);
    if (hit != null) {
      _undoMgr.push(_objects, _stickers);
      _objects.remove(hit);
      if (_selectedObject == hit) _selectedObject = null;
      setState(() {});
    }
  }

  void _onPanStart(DragStartDetails d) {
    final pos = d.localPosition;

    // Box selection mode
    if (_selectedTool == DrawTool.boxSelect) {
      _boxStart = pos;
      _boxEnd = pos;
      setState(() {});
      return;
    }

    // Eraser: continuous erase on drag
    if (_selectedTool == DrawTool.eraser) {
      _tempPoints.clear();
      _tempPoints.add(pos);
      _eraseAt(pos);
      setState(() {});
      return;
    }

    // Fill tool: no drag behaviour
    if (_selectedTool == DrawTool.fillTool) return;

    // Drawing tools → ALWAYS start a new stroke, never move
    if (_isDrawingTool) {
      _deselectAll();
      if (_selectedTool == DrawTool.magicEraser) {
        _currentMaskPath = [pos];
      } else {
        _tempPoints.clear();
        _tempPoints.add(pos);
      }
      setState(() {});
      return;
    }

    // Non-drawing tools (select etc.): move if hitting a selected object
    final hit = _hitTest(pos);
    if (hit != null && hit.isSelected) {
      _isMovingSelection = true;
      return;
    }

    _tempPoints.clear();
    _tempPoints.add(pos);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final pos = d.localPosition;
    final delta = d.delta;

    if (_isMovingSelection) {
      _moveSelection(delta);
      return;
    }

    if (_selectedTool == DrawTool.boxSelect) {
      _boxEnd = pos;
      setState(() {});
      return;
    }

    if (_selectedTool == DrawTool.eraser) {
      _eraseAt(pos);
      return;
    }

    if (_selectedTool == DrawTool.fillTool) return;

    if (_selectedTool == DrawTool.magicEraser) {
      _currentMaskPath.add(pos);
      setState(() {});
      return;
    }

    // For free/smooth draw: thin points to avoid jagged strokes –
    // only add if we moved at least 2px from last point.
    if (_tempPoints.isNotEmpty &&
        (_selectedTool == DrawTool.freeLine ||
            _selectedTool == DrawTool.smoothLine)) {
      if ((pos - _tempPoints.last).distance < 2.5) return;
    }

    _tempPoints.add(pos);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isMovingSelection) {
      _isMovingSelection = false;
      return;
    }

    if (_selectedTool == DrawTool.boxSelect) {
      _applyBoxSelect();
      return;
    }

    if (_selectedTool == DrawTool.eraser ||
        _selectedTool == DrawTool.fillTool) {
      _tempPoints.clear();
      setState(() {});
      return;
    }

    if (_selectedTool == DrawTool.magicEraser) {
      if (_currentMaskPath.length > 2) {
        _maskPaths.add(List.from(_currentMaskPath));
      }
      _currentMaskPath = [];
      setState(() {});
      return;
    }

    if (_tempPoints.isEmpty) return;

    _undoMgr.push(_objects, _stickers);
    final finalPoints = _buildPoints(_tempPoints, _selectedTool);
    if (finalPoints.isNotEmpty) {
      _objects.add(DrawObject(
        id: _uuid.v4(),
        points: finalPoints,
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        tool: _selectedTool,
        zIndex: _objects.length,
      ));
    }

    _tempPoints.clear();
    setState(() {});
  }

  // ─── Object operations ───────────────────────────────────────────────────

  DrawObject? _hitTest(Offset pos) {
    for (final obj in _objects.reversed) {
      if (obj.hitTest(pos)) return obj;
    }
    return null;
  }

  void _selectObject(DrawObject obj) {
    for (final o in _objects) {
      o.isSelected = false;
    }
    obj.isSelected = true;
    _selectedObject = obj;
    setState(() {});
  }

  void _deselectAll() {
    for (final o in _objects) {
      o.isSelected = false;
    }
    _selectedObject = null;
    _selectedStickerId = null;
    setState(() {});
  }

  // ─── Sticker operations ──────────────────────────────────────────────────

  void _showFurniturePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FurniturePicker(
        onSelect: (emoji, label, category) {
          _addSticker(emoji, label, category);
        },
      ),
    );
  }

  void _addSticker(String emoji, String label, String category) {
    final screenCenter = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 3,
    );

    final id = _uuid.v4();
    final sticker = StickerItem(
      id: id,
      emoji: emoji,
      label: label,
      category: category,
      x: screenCenter.dx,
      y: screenCenter.dy,
      size: _stickerSize,
    );

    setState(() {
      _deselectAll();
      _stickers.add(sticker);
      _selectedStickerId = id;
    });
    HapticFeedback.lightImpact();
  }

  void _selectSticker(String id) {
    final idx = _stickers.indexWhere((s) => s.id == id);
    if (idx != -1) {
      setState(() {
        _deselectAll();
        _selectedStickerId = id;
        _stickerSize = _stickers[idx].size;
        _stickerRotation = _stickers[idx].rotation;
        _stickerOpacity = _stickers[idx].opacity;
      });
    }
  }

  void _deleteSticker(String id) {
    _undoMgr.push(_objects, _stickers);
    setState(() {
      _stickers.removeWhere((s) => s.id == id);
      if (_selectedStickerId == id) _selectedStickerId = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _moveSticker(String id, double dx, double dy) {
    final idx = _stickers.indexWhere((s) => s.id == id);
    if (idx != -1) {
      setState(() {
        _stickers[idx] = _stickers[idx].copyWith(
          x: _stickers[idx].x + dx,
          y: _stickers[idx].y + dy,
        );
      });
    }
  }

  void _deleteSelected() {
    HapticFeedback.mediumImpact();
    _undoMgr.push(_objects, _stickers);
    
    if (_selectedStickerId != null) {
      _stickers.removeWhere((s) => s.id == _selectedStickerId);
      _selectedStickerId = null;
    } else {
      _objects.removeWhere((o) => o.isSelected);
      _selectedObject = null;
    }
    setState(() {});
  }

  void _duplicateSelected() {
    HapticFeedback.lightImpact();
    _undoMgr.push(_objects, _stickers);

    if (_selectedStickerId != null) {
      final idx = _stickers.indexWhere((s) => s.id == _selectedStickerId);
      if (idx != -1) {
        final original = _stickers[idx];
        final clone = original.copyWith(
          id: _uuid.v4(),
          x: original.x + 20,
          y: original.y + 20,
        );
        _stickers.add(clone);
        _selectedStickerId = clone.id;
      }
    } else {
      final toClone = _objects.where((o) => o.isSelected).toList();
      for (final obj in toClone) {
        final clone = obj.copyWith(
          id: _uuid.v4(),
          points: obj.points.map((p) => p + const Offset(16, 16)).toList(),
          isSelected: false,
        );
        _objects.add(clone);
      }
    }
    setState(() {});
  }

  void _fillObject(DrawObject obj) {
    _undoMgr.push(_objects, _stickers);
    obj.fillColor = _selectedColor.withValues(alpha: _fillOpacity);
    obj.opacity = _fillOpacity;
    _selectObject(obj);
  }

  void _moveSelection(Offset delta) {
    for (final obj in _objects.where((o) => o.isSelected)) {
      obj.points = obj.points.map((p) => p + delta).toList();
      obj.position += delta;
    }
    setState(() {});
  }

  void _eraseAt(Offset pos) {
    DrawObject? closest;
    var minD = double.infinity;
    for (final obj in _objects) {
      final d = obj.distanceTo(pos);
      if (d < minD) {
        minD = d;
        closest = obj;
      }
    }
    if (closest != null && minD < 30) {
      _undoMgr.push(_objects, _stickers);
      _objects.remove(closest);
      if (_selectedObject == closest) _selectedObject = null;
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _applyBoxSelect() {
    if (_boxStart == null || _boxEnd == null) return;
    final rect = Rect.fromPoints(_boxStart!, _boxEnd!);
    for (final obj in _objects) {
      if (obj.points.any((p) => rect.contains(p))) {
        obj.isSelected = true;
        _selectedObject = obj;
      }
    }
    _boxStart = null;
    _boxEnd = null;
    setState(() {});
  }

  void _changeColor(Color color) {
    setState(() => _selectedColor = color);
    for (final obj in _objects.where((o) => o.isSelected)) {
      obj.color = color;
    }
    setState(() {});
  }

  void _doUndo() {
    final state = _undoMgr.undo(_objects, _stickers);
    if (state == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _objects.clear();
      _objects.addAll(state.objects);
      _stickers.clear();
      _stickers.addAll(state.stickers);
      _selectedObject = null;
      _selectedStickerId = null;
    });
  }

  void _doRedo() {
    final state = _undoMgr.redo(_objects, _stickers);
    if (state == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _objects.clear();
      _objects.addAll(state.objects);
      _stickers.clear();
      _stickers.addAll(state.stickers);
      _selectedObject = null;
      _selectedStickerId = null;
    });
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Canvas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Delete all drawings? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _undoMgr.push(_objects, _stickers);
              _objects.clear();
              _selectedObject = null;
              setState(() {});
            },
            child: const Text('Clear',
                style: TextStyle(
                    color: Color(0xFFFF5252), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Point building ────────────────────────────────────────────────────────

  List<Offset> _buildPoints(List<Offset> raw, DrawTool tool) {
    if (raw.isEmpty) return [];
    switch (tool) {
      case DrawTool.straightLine:
        return [raw.first, raw.last];
      case DrawTool.rectangle:
      case DrawTool.circle:
      case DrawTool.triangle:
        return [raw.first, raw.last];
      case DrawTool.freeLine:
      case DrawTool.smoothLine:
        return List.from(raw);
      default:
        return List.from(raw);
    }
  }

  // ─── AI Magic Eraser Logic ──────────────────────────────────────────────

  Future<void> _processMagicRemoval() async {
    if (_maskPaths.isEmpty) return;
    
    setState(() => _isProcessingAI = true);
    HapticFeedback.heavyImpact();

    // 1. Remove from Background Image (REAL Pixel Removal)
    if (_capturedImage != null) {
      final processedPath = await ImageProcessor.removeObjects(
        imagePath: _capturedImage!.path,
        maskPaths: _maskPaths,
        screenSize: MediaQuery.of(context).size,
      );

      if (processedPath != null) {
        _capturedImage = XFile(processedPath);
      }
    }

    // 2. Clear overlaid objects (drawings/stickers) that intersect the mask
    final removedStickers = <String>[];
    for (final s in _stickers) {
      final sPos = Offset(s.x, s.y);
      bool hit = false;
      for (final path in _maskPaths) {
        for (final p in path) {
          if ((p - sPos).distance < (s.size / 2 + 20)) {
            hit = true;
            break;
          }
        }
        if (hit) break;
      }
      if (hit) removedStickers.add(s.id);
    }

    final removedObjects = <DrawObject>[];
    for (final obj in _objects) {
      bool hit = false;
      for (final path in _maskPaths) {
        for (final p in path) {
          if (obj.bounds.inflate(15).contains(p)) {
            hit = true;
            break;
          }
        }
        if (hit) break;
      }
      if (hit) removedObjects.add(obj);
    }

    setState(() {
      _isProcessingAI = false;
      _stickers.removeWhere((s) => removedStickers.contains(s.id));
      _objects.removeWhere((o) => removedObjects.contains(o));
      _maskPaths.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('AI: Background object removed successfully!')),
            ],
          ),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _clearMask() {
    setState(() => _maskPaths.clear());
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Color(0xFF4F8EF7), strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                'Initializing Camera…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Canvas ──────────────────────────────────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                children: [
                  // Background: locked image or live camera
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _isLocked && _capturedImage != null
                          ? Image.file(
                              File(_capturedImage!.path),
                              key: const ValueKey('locked'),
                              fit: BoxFit.cover,
                            )
                          : CameraPreview(
                              _controller,
                              key: const ValueKey('live'),
                            ),
                    ),
                  ),
                  // Drawing layer
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: ObjectPainter(
                          objects: _objects,
                          livePoints: _tempPoints,
                          currentTool: _selectedTool,
                          liveColor: _selectedColor,
                          liveStrokeWidth: _strokeWidth,
                          boxStart: _boxStart,
                          boxEnd: _boxEnd,
                        ),
                      ),
                    ),
                  ),
                  // Sticker layer
                  Positioned.fill(
                    child: StickerLayer(
                      stickers: _stickers.map((s) {
                        s.isSelected = (s.id == _selectedStickerId);
                        return s;
                      }).toList(),
                      onSelect: _selectSticker,
                      onDeselect: _deselectAll,
                      onDelete: _deleteSticker,
                      onMove: _moveSticker,
                    ),
                  ),
                  // Magic Eraser Mask Layer
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MaskPainter(
                        paths: _maskPaths,
                        currentPath: _currentMaskPath,
                      ),
                    ),
                  ),
                  // GESTURE HANDLER (TOP)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: _onTapDown,
                      onLongPressStart: _onLongPressStart,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                    ),
                  ),
                    // AI Processing Overlay
                    if (_isProcessingAI)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFF6C63FF),
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 24),
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF4F8EF7), Color(0xFF6C63FF)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'AI IS REMOVING OBJECT...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),

            // Help Overlay
            if (_showHelp)
              Positioned.fill(
                child: HelpOverlay(
                  onDismiss: () => setState(() => _showHelp = false),
                ),
              ),

            // Magic Eraser Process Button
            if (_maskPaths.isNotEmpty && !_isProcessingAI)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _processMagicRemoval,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4F8EF7)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'REMOVE OBJECTS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _clearMask,
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Top bar ─────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // ── Right-side color palette FAB ─────────────────────────────
            Positioned(
              top: 80,
              right: 12,
              child: ColorPalette(
                selectedColor: _selectedColor,
                opacity: _fillOpacity,
                onColorChanged: _changeColor,
                onOpacityChanged: (v) => setState(() => _fillOpacity = v),
              ),
            ),

            // ── Bottom panel ─────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Lock / unlock Camera
            _TopButton(
              icon: _isLocked
                  ? Icons.lock_rounded
                  : Icons.camera_alt_rounded,
              label: _isLocked ? 'Unlock' : 'Capture',
              color: _isLocked
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF4F8EF7),
              onTap: _toggleLock,
            ),

            const SizedBox(width: 8),

            // Furniture Picker
            _TopButton(
              icon: Icons.chair_rounded,
              label: 'Furniture',
              color: const Color(0xFFFF9800),
              onTap: _showFurniturePicker,
            ),

            const SizedBox(width: 8),

            // Projects / Gallery
            _TopButton(
              icon: Icons.folder_copy_rounded,
              label: 'Projects',
              color: const Color(0xFF9C27B0),
              onTap: _openGallery,
            ),

            const SizedBox(width: 8),

            // Save Design
            _TopButton(
              icon: Icons.save_rounded,
              label: 'Save',
              color: const Color(0xFF4CAF50),
              onTap: _saveProject,
            ),

            const SizedBox(width: 8),

            // Export to Image
            _TopButton(
              icon: Icons.ios_share_rounded,
              label: 'Export',
              color: Colors.blueAccent,
              onTap: _exportToImage,
            ),

            const SizedBox(width: 8),

            // Active tool chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF4F8EF7).withValues(alpha: 0.5),
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_toolIcon(_selectedTool),
                      color: const Color(0xFF4F8EF7), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _toolLabel(_selectedTool),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Undo
            _TopButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              color: _undoMgr.canUndo ? Colors.white70 : Colors.white24,
              onTap: _undoMgr.canUndo ? _doUndo : null,
            ),
            const SizedBox(width: 6),

            // Redo
            _TopButton(
              icon: Icons.redo_rounded,
              label: 'Redo',
              color: _undoMgr.canRedo ? Colors.white70 : Colors.white24,
              onTap: _undoMgr.canRedo ? _doRedo : null,
            ),
            const SizedBox(width: 8),

            // Help
            _TopButton(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              color: const Color(0xFF4F8EF7),
              onTap: () => setState(() => _showHelp = true),
            ),
            const SizedBox(width: 6),

            // Clear all
            _TopButton(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear',
              color: _objects.isEmpty
                  ? Colors.white24
                  : const Color(0xFFFF5252),
              onTap: _objects.isEmpty ? null : _clearCanvas,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Panel ─────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    final hasSelection = _selectedObject != null ||
        _objects.any((o) => o.isSelected) ||
        _selectedStickerId != null;
    final hasMultiple =
        _objects.where((o) => o.isSelected).length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Context action bar (slides up when object selected)
        ContextActionBar(
          hasSelection: hasSelection,
          hasMultipleSelection: hasMultiple,
          onDelete: _deleteSelected,
          onDuplicate: _duplicateSelected,
          onFill: () {
            final selected = _objects.where((o) => o.isSelected).toList();
            if (selected.isNotEmpty) _fillObject(selected.first);
          },
          onDeselect: _deselectAll,
        ),

        // Contextual Sliders: Size and Rotation for sticker OR stroke for drawing
        if (_selectedStickerId != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStickerSizeSlider(),
              _buildRotationSlider(),
              _buildStickerOpacitySlider(),
            ],
          )
        else
          StrokeSlider(
            value: _strokeWidth,
            color: _selectedColor,
            onChanged: (v) {
              setState(() => _strokeWidth = v);
              for (final obj in _objects.where((o) => o.isSelected)) {
                obj.strokeWidth = v;
              }
            },
          ),

        // Tool selection bar
        ToolBar(
          selectedTool: _selectedTool,
          onToolSelected: (t) {
            setState(() {
              _selectedTool = t;
              _deselectAll();
            });
          },
        ),

        const SizedBox(height: 4),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  IconData _toolIcon(DrawTool tool) {
    switch (tool) {
      case DrawTool.freeLine:
        return Icons.brush_rounded;
      case DrawTool.smoothLine:
        return Icons.auto_fix_high_rounded;
      case DrawTool.straightLine:
        return Icons.show_chart_rounded;
      case DrawTool.rectangle:
      case DrawTool.square:
        return Icons.crop_square_rounded;
      case DrawTool.circle:
      case DrawTool.ellipse:
        return Icons.circle_outlined;
      case DrawTool.triangle:
      case DrawTool.polygon:
        return Icons.change_history_rounded;
      case DrawTool.boxSelect:
      case DrawTool.select:
      case DrawTool.multiSelect:
        return Icons.select_all_rounded;
      case DrawTool.fillTool:
      case DrawTool.colorPicker:
        return Icons.format_color_fill_rounded;
      case DrawTool.eraser:
        return Icons.auto_fix_off_rounded;
      case DrawTool.magicEraser:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  String _toolLabel(DrawTool tool) {
    switch (tool) {
      case DrawTool.freeLine:
        return 'Free Draw';
      case DrawTool.smoothLine:
        return 'Smooth';
      case DrawTool.straightLine:
        return 'Line';
      case DrawTool.rectangle:
        return 'Rectangle';
      case DrawTool.square:
        return 'Square';
      case DrawTool.circle:
        return 'Circle';
      case DrawTool.ellipse:
        return 'Ellipse';
      case DrawTool.triangle:
        return 'Triangle';
      case DrawTool.polygon:
        return 'Polygon';
      case DrawTool.boxSelect:
        return 'Box Select';
      case DrawTool.select:
        return 'Select';
      case DrawTool.multiSelect:
        return 'Multi Select';
      case DrawTool.fillTool:
        return 'Fill';
      case DrawTool.eraser:
        return 'Eraser';
      case DrawTool.magicEraser:
        return 'Magic Eraser';
      default:
        return tool.name;
    }
  }
  Widget _buildStickerSizeSlider() {
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
          const Icon(Icons.photo_size_select_large_rounded,
              color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: const Color(0xFF4F8EF7),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _stickerSize,
                min: 30,
                max: 200,
                onChanged: (v) {
                  setState(() => _stickerSize = v);
                  final idx = _stickers.indexWhere((s) => s.id == _selectedStickerId);
                  if (idx != -1) {
                    _stickers[idx].size = v;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_stickerSize.round()}px',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
  Widget _buildRotationSlider() {
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
          const Icon(Icons.rotate_right_rounded,
              color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: const Color(0xFFFF9800),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _stickerRotation,
                min: -math.pi,
                max: math.pi,
                onChanged: (v) {
                  setState(() => _stickerRotation = v);
                  final idx = _stickers.indexWhere((s) => s.id == _selectedStickerId);
                  if (idx != -1) {
                    _stickers[idx].rotation = v;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(_stickerRotation * 180 / math.pi).round()}°',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerOpacitySlider() {
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
          const Icon(Icons.opacity_rounded,
              color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _stickerOpacity,
                min: 0.1,
                max: 1.0,
                onChanged: (v) {
                  setState(() => _stickerOpacity = v);
                  final idx = _stickers.indexWhere((s) => s.id == _selectedStickerId);
                  if (idx != -1) {
                    _stickers[idx].opacity = v;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(_stickerOpacity * 100).round()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Top Button ──────────────────────────────────────────────────────

class _TopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _TopButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Mask Painter ------------------------------------------------------------

class MaskPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;

  MaskPainter({required this.paths, required this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isEmpty && currentPath.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFFFF5252).withValues(alpha: 0.45)
      ..strokeWidth = 32
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = const Color(0xFFFF5252).withValues(alpha: 0.2)
      ..strokeWidth = 44
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeCap = StrokeCap.round;

    void drawPath(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }

    for (final p in paths) {
      drawPath(p);
    }
    drawPath(currentPath);
  }

  @override
  bool shouldRepaint(MaskPainter oldDelegate) => true;
}
