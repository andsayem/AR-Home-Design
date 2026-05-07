import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageProcessor {
  /// Performs a local 'Content-Aware' inpainting on the masked areas.
  static Future<String?> removeObjects({
    required String imagePath,
    required List<List<Offset>> maskPaths,
    required Size screenSize,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    final imgW = image.width;
    final imgH = image.height;
    
    // Scale factor between screen coordinates and image coordinates
    final scaleX = imgW / screenSize.width;
    final scaleY = imgH / screenSize.height;

    // 1. Create a binary mask of the removal areas
    final maskPoints = <Point<int>>{};
    const int brushSize = 32; // Half-width of the brush

    for (final path in maskPaths) {
      for (final offset in path) {
        final centerPX = (offset.dx * scaleX).toInt();
        final centerPY = (offset.dy * scaleY).toInt();
        
        // Fill a circle around each point for the brush stroke
        for (int y = -brushSize; y <= brushSize; y++) {
          for (int x = -brushSize; x <= brushSize; x++) {
            if (x*x + y*y <= brushSize*brushSize) {
              final px = centerPX + x;
              final py = centerPY + y;
              if (px >= 0 && px < imgW && py >= 0 && py < imgH) {
                maskPoints.add(Point(px, py));
              }
            }
          }
        }
      }
    }

    if (maskPoints.isEmpty) return imagePath;

    // 2. Perform 'Patch-Match' style inpainting
    // For each masked pixel, we find the nearest non-masked pixel in a spiral
    final resultImage = image.clone();
    
    for (final pt in maskPoints) {
      bool found = false;
      // Search in increasing squares around the point
      for (int r = 1; r < 50; r++) { 
        for (int sy = -r; sy <= r; sy++) {
          for (int sx = -r; sx <= r; sx++) {
            if (sx.abs() != r && sy.abs() != r) continue; // Only check the perimeter
            
            final targetX = pt.x + sx;
            final targetY = pt.y + sy;
            
            if (targetX >= 0 && targetX < imgW && targetY >= 0 && targetY < imgH) {
              if (!maskPoints.contains(Point(targetX, targetY))) {
                final color = image.getPixel(targetX, targetY);
                resultImage.setPixel(pt.x, pt.y, color);
                found = true;
                break;
              }
            }
          }
          if (found) break;
        }
        if (found) break;
      }
    }

    // 3. Save the result
    final tempDir = await getTemporaryDirectory();
    final fileName = 'inpainted_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = p.join(tempDir.path, fileName);
    
    await File(targetPath).writeAsBytes(img.encodeJpg(resultImage, quality: 90));
    return targetPath;
  }
}
