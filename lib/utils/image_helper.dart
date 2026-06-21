import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Holds a picked image together with its pre-read bytes.
/// Using bytes (Uint8List) for display works on all platforms including web
/// and Flutter's test environment, unlike FileImage which requires dart:io.
class PickedImage {
  final XFile file;
  final Uint8List bytes;

  const PickedImage({required this.file, required this.bytes});

  /// Read bytes from an XFile — works on all platforms.
  static Future<PickedImage> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return PickedImage(file: file, bytes: bytes);
  }

  static Future<List<PickedImage>> fromXFiles(List<XFile> files) async {
    return Future.wait(files.map(fromXFile));
  }
}

/// Cross-platform image preview thumbnail.
/// Uses Image.memory (works everywhere) instead of FileImage (dart:io only).
class PickedImageThumbnail extends StatelessWidget {
  final PickedImage image;
  final double size;
  final VoidCallback? onRemove;

  const PickedImageThumbnail({
    super.key,
    required this.image,
    this.size = 80,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        margin: const EdgeInsets.only(right: 8),
        width: size, height: size,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            image.bytes,
            fit: BoxFit.cover,
            width: size, height: size,
          ),
        ),
      ),
      if (onRemove != null)
        Positioned(top: 2, right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Color(0xFFEF4444), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white)))),
    ]);
  }
}
