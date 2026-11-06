import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;

// ═════════════════════════════════════════════════════════════
// AUTO-CROP + RESIZE DE MÁXIMA CALIDAD (para zoom nítido)
// ═════════════════════════════════════════════════════════════
List<int> autoCropSync(List<int> bytes) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return bytes;

  final w = decoded.width;
  final h = decoded.height;

  int top = h, bottom = 0, left = w, right = 0;
  const minLum = 40;
  const maxLum = 240;

  // Analizar píxel a píxel (más preciso, pero un poco más lento)
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = decoded.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

      if (lum > minLum && lum < maxLum) {
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }

  img.Image result;

  if (top >= bottom || left >= right) {
    // No se detectó contenido → usar original
    result = decoded;
  } else {
    // Margen pequeño (1%) para no cortar nada
    final marginX = (right - left) * 0.01;
    final marginY = (bottom - top) * 0.01;

    final finalLeft = (left - marginX).clamp(0, w).toInt();
    final finalTop = (top - marginY).clamp(0, h).toInt();
    final finalRight = (right + marginX).clamp(0, w).toInt();
    final finalBottom = (bottom + marginY).clamp(0, h).toInt();

    final cropWidth = finalRight - finalLeft;
    final cropHeight = finalBottom - finalTop;

    final currentRatio = (cropWidth * cropHeight) / (w * h);
    if (currentRatio > 0.98) {
      // El contenido ya ocupa casi todo → no recortar
      result = decoded;
    } else {
      result = img.copyCrop(
        decoded,
        x: finalLeft,
        y: finalTop,
        width: cropWidth,
        height: cropHeight,
      );
    }
  }

  // ⬇️ CLAVE: Escalar a A4 300 DPI de ALTA resolución (3480×4920)
  // Esto es un ~20% más grande que A4 estándar para que el zoom sea nítido.
  // Si la hoja es pequeña, la agrandamos. Si ya es grande, mantenemos.
  final resized = _resizeToA4HighRes(result);

  // ⬇️ Calidad JPG 95 (máxima sin artefactos visibles)
  return img.encodeJpg(resized, quality: 95);
}

/// Escala a A4 manteniendo la proporción real de la hoja,
/// pero con lado mayor mínimo de 3500px.
img.Image _resizeToA4HighRes(img.Image src) {
  const minSide = 3500;   // lado mayor mínimo para zoom nítido
  const maxSide = 4500;   // no agrandar más de esto (peso controlado)

  // Calcular tamaño objetivo
  int targetWidth, targetHeight;
  final aspect = src.width / src.height;

  if (src.width > src.height) {
    // Horizontal
    targetWidth = src.width.clamp(minSide, maxSide);
    targetHeight = (targetWidth / aspect).round();
  } else {
    // Vertical (mayoría de documentos)
    targetHeight = src.height.clamp(minSide, maxSide);
    targetWidth = (targetHeight * aspect).round();
  }

  // Si ya es del tamaño adecuado, no tocar
  if (src.width >= targetWidth && src.height >= targetHeight) {
    return src;
  }

  return img.copyResize(
    src,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,   // ⬅️ máxima calidad
    maintainAspect: true,
  );
}

// ═════════════════════════════════════════════════════════════
// SERVICIO
// ═════════════════════════════════════════════════════════════
class ImageEnhancerService {
  Future<String> autoCropAndResize(String path) async {
    final file = File(path);
    if (!await file.exists()) return path;

    final bytes = await file.readAsBytes();
    final processed = await compute(autoCropSync, bytes);
    await file.writeAsBytes(processed);

    debugPrint(
      '📐 Imagen procesada: ${(processed.length / 1024 / 1024).toStringAsFixed(2)} MB',
    );
    return path;
  }
}