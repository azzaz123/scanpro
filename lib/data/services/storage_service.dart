import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _uuid = Uuid();

  /// Copia la imagen SIN comprimir (la compresión la hace autoCropAndResize).
  Future<String> savePermanentImage(String tempPath) async {
    final file = File(tempPath);
    if (!await file.exists()) {
      throw Exception('Imagen temporal no existe: $tempPath');
    }

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/scans');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    // ⬇️ Copiar SIN comprimir (preserva calidad máxima)
    final newPath = '${folder.path}/${_uuid.v4()}.jpg';
    await file.copy(newPath);

    final size = await File(newPath).length();
    debugPrint(
      '💾 Imagen copiada: ${(size / 1024).toStringAsFixed(0)} KB → $newPath',
    );

    return newPath;
  }

  Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar $path: $e');
    }
  }

  Future<int> getStorageSize() async {
    final dir = await getApplicationDocumentsDirectory();
    final scans = Directory('${dir.path}/scans');
    if (!await scans.exists()) return 0;
    int total = 0;
    await for (final entity in scans.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}