import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/sticker_item.dart';

class CanvasState {
  final List<DrawObject> objects;
  final List<StickerItem> stickers;

  CanvasState({required this.objects, required this.stickers});

  CanvasState copy() {
    return CanvasState(
      objects: objects.map((o) => o.copyWith()).toList(),
      stickers: stickers.map((s) => s.copyWith()).toList(),
    );
  }
}

class UndoManager {
  static const int _maxHistory = 30;

  final List<CanvasState> _undoStack = [];
  final List<CanvasState> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void push(List<DrawObject> objects, List<StickerItem> stickers) {
    _undoStack.add(CanvasState(
      objects: objects.map((o) => o.copyWith()).toList(),
      stickers: stickers.map((s) => s.copyWith()).toList(),
    ));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  CanvasState? undo(List<DrawObject> objects, List<StickerItem> stickers) {
    if (!canUndo) return null;
    _redoStack.add(CanvasState(
      objects: objects.map((o) => o.copyWith()).toList(),
      stickers: stickers.map((s) => s.copyWith()).toList(),
    ));
    return _undoStack.removeLast();
  }

  CanvasState? redo(List<DrawObject> objects, List<StickerItem> stickers) {
    if (!canRedo) return null;
    _undoStack.add(CanvasState(
      objects: objects.map((o) => o.copyWith()).toList(),
      stickers: stickers.map((s) => s.copyWith()).toList(),
    ));
    return _redoStack.removeLast();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
