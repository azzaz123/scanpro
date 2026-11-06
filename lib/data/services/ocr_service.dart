import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// Extrae todo el texto plano (para copiar / mostrar)
  Future<String> extractText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  Future<String> extractTextFromMultiple(List<String> paths) async {
    final buffer = StringBuffer();
    for (final p in paths) {
      buffer.writeln(await extractText(p));
      buffer.writeln('\n---\n');
    }
    return buffer.toString();
  }

  /// ⬇️ NUEVO: extrae texto con posiciones (para PDF profesional)
  Future<OcrPageData?> extractPageWithPositions(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);

      final imageSize = await _getImageSize(imagePath);
      if (imageSize == null) return null;

      final blocks = <OcrTextBlock>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          // Agrupamos palabras de la misma línea en un solo bloque
          // (más eficiente que palabra por palabra)
          final rect = line.boundingBox;
          if (rect == null) continue;

          blocks.add(OcrTextBlock(
            text: line.text,
            x: rect.left / imageSize.$1,
            y: rect.top / imageSize.$2,
            width: rect.width / imageSize.$1,
            height: rect.height / imageSize.$2,
          ));
        }
      }

      return OcrPageData(
        fullText: result.text,
        blocks: blocks,
        imageWidth: imageSize.$1,
        imageHeight: imageSize.$2,
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<(double, double)?> _getImageSize(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return (
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class OcrPageData {
  final String fullText;
  final List<OcrTextBlock> blocks;
  final double imageWidth;
  final double imageHeight;

  OcrPageData({
    required this.fullText,
    required this.blocks,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class OcrTextBlock {
  final String text;
  final double x;      // 0-1 (relativo al ancho de la imagen)
  final double y;      // 0-1 (relativo al alto de la imagen)
  final double width;  // 0-1
  final double height; // 0-1

  OcrTextBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}