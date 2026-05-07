import 'package:homedesign/models/draw_object.dart';
import 'package:homedesign/models/sticker_item.dart';

class ProjectModel {
  final String id;
  final String name;
  final String? imagePath;
  final List<DrawObject> objects;
  final List<StickerItem> stickers;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    this.imagePath,
    required this.objects,
    required this.stickers,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'objects': objects.map((e) => e.toJson()).toList(),
        'stickers': stickers.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String?,
      objects: (json['objects'] as List)
          .map((e) => DrawObject.fromJson(e as Map<String, dynamic>))
          .toList(),
      stickers: (json['stickers'] as List)
          .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
