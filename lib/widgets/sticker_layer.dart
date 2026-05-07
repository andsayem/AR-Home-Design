import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homedesign/models/sticker_item.dart';

class StickerLayer extends StatefulWidget {
  final List<StickerItem> stickers;
  final void Function(String id) onDelete;
  final void Function(String id, double dx, double dy) onMove;
  final void Function(String id) onSelect;
  final void Function() onDeselect;

  const StickerLayer({
    super.key,
    required this.stickers,
    required this.onDelete,
    required this.onMove,
    required this.onSelect,
    required this.onDeselect,
  });

  @override
  State<StickerLayer> createState() => _StickerLayerState();
}

class _StickerLayerState extends State<StickerLayer> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.stickers.map((s) => _buildSticker(s)).toList(),
    );
  }

  Widget _buildSticker(StickerItem s) {
    return Positioned(
      left: s.x - s.size / 2,
      top: s.y - s.size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (s.isSelected) {
            widget.onDeselect();
          } else {
            widget.onSelect(s.id);
          }
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onDelete(s.id);
        },
        onPanUpdate: (d) {
          widget.onMove(s.id, d.delta.dx, d.delta.dy);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: s.size,
          height: s.size,
          decoration: s.isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF4F8EF7),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F8EF7).withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                )
              : null,
          child: Transform.rotate(
            angle: s.rotation,
            child: Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: s.opacity.clamp(0.1, 1.0),
                    child: Text(
                      s.emoji,
                      style: TextStyle(
                        fontSize: s.size * 0.62,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (s.isSelected)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F8EF7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
