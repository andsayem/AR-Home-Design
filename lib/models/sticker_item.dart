import 'package:uuid/uuid.dart';

class StickerItem {
  final String id;
  String emoji;
  String label;
  String category;
  double x;
  double y;
  double size;
  double rotation; // in radians
  double opacity;
  bool isSelected;

  StickerItem({
    required this.id,
    required this.emoji,
    required this.label,
    required this.category,
    required this.x,
    required this.y,
    this.size = 52,
    this.rotation = 0,
    this.opacity = 1.0,
    this.isSelected = false,
  });

  StickerItem copyWith({
    String? id,
    String? emoji,
    String? label,
    String? category,
    double? x,
    double? y,
    double? size,
    double? rotation,
    double? opacity,
    bool? isSelected,
  }) {
    return StickerItem(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      label: label ?? this.label,
      category: category ?? this.category,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'label': label,
        'category': category,
        'x': x,
        'y': y,
        'size': size,
        'rotation': rotation,
        'opacity': opacity,
      };

  factory StickerItem.fromJson(Map<String, dynamic> json) {
    return StickerItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      emoji: json['emoji'] as String,
      label: json['label'] as String,
      category: json['category'] as String? ?? 'misc',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      size: (json['size'] as num? ?? 52).toDouble(),
      rotation: (json['rotation'] as num? ?? 0).toDouble(),
      opacity: (json['opacity'] as num? ?? 1.0).toDouble(),
    );
  }
}
