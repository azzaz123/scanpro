import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────
// CONVERSORES (corren en isolate separado con compute)
// ─────────────────────────────────────────────────────────────

List<int> _toPngSync(List<int> bytes) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) throw Exception('No se pudo decodificar');
  return img.encodePng(decoded);
}

List<int> _toJpgSync(List<int> bytes) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) throw Exception('No se pudo decodificar');
  return img.encodeJpg(decoded, quality: 90);
}

enum ExportFormat { pdf, jpg, png }

// ─────────────────────────────────────────────────────────────
// SERVICIO
// ─────────────────────────────────────────────────────────────

class ExportService {
  // ─────────────────────────────────────────────────────────────
  // GUARDAR IMÁGENES (JPG o PNG)
  // ─────────────────────────────────────────────────────────────
  Future<List<String>> saveImages({
    required List<String> imagePaths,
    required String documentName,
    required ExportFormat format,
    required bool askUserWhere,
  }) async {
    if (format == ExportFormat.pdf) {
      throw ArgumentError('Usa savePdfFile() para PDF');
    }

    final savedPaths = <String>[];
    final isPng = format == ExportFormat.png;
    final ext = isPng ? 'png' : 'jpg';
    final converter = isPng ? _toPngSync : _toJpgSync;

    // ────────────────────────────────────────────────────────
    // CASO A: carpeta de la app (sin diálogos SAF)
    // ────────────────────────────────────────────────────────
    if (!askUserWhere) {
      final dir = await getApplicationDocumentsDirectory();
      final targetDir = '${dir.path}/images';
      final folder = Directory(targetDir);
      if (!await folder.exists()) await folder.create(recursive: true);

      for (int i = 0; i < imagePaths.length; i++) {
        try {
          final src = File(imagePaths[i]);
          if (!await src.exists()) {
            debugPrint('⚠️ No existe: ${imagePaths[i]}');
            continue;
          }

          debugPrint('🔄 Convirtiendo ${src.path}...');
          final bytes = await src.readAsBytes();
          final converted = await compute(converter, bytes);

          final suffix = imagePaths.length > 1 ? '_${i + 1}' : '';
          final dest = File('$targetDir/$documentName$suffix.$ext');
          await dest.writeAsBytes(converted);

          debugPrint('✅ Guardado en app: ${dest.path}');
          savedPaths.add(dest.path);
        } catch (e, st) {
          debugPrint('❌ ERROR con ${imagePaths[i]}: $e');
          debugPrint('STACK: $st');
        }
      }
      return savedPaths;
    }

    // ────────────────────────────────────────────────────────
    // CASO B: SAF con file_picker + bytes:
    // ────────────────────────────────────────────────────────
    for (int i = 0; i < imagePaths.length; i++) {
      try {
        final src = File(imagePaths[i]);
        if (!await src.exists()) {
          debugPrint('⚠️ No existe: ${imagePaths[i]}');
          continue;
        }

        debugPrint('🔄 Convirtiendo ${src.path}...');
        final bytes = await src.readAsBytes();
        final converted = await compute(converter, bytes);

        final suffix = imagePaths.length > 1 ? '_${i + 1}' : '';
        final fileName = '$documentName$suffix.$ext';

        debugPrint('🔍 Abriendo selector SAF para: $fileName');
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar $fileName',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [ext],
          // ⬇️ CLAVE: file_picker escribe el archivo por ti usando SAF
          bytes: Uint8List.fromList(converted),
        );
        debugPrint('🔍 Resultado SAF: $result');

        if (result == null) {
          debugPrint('⚠️ Usuario canceló');
          break;
        }

        debugPrint('✅ Guardado: $result');
        savedPaths.add(result);
      } catch (e, st) {
        debugPrint('❌ ERROR con ${imagePaths[i]}: $e');
        debugPrint('STACK: $st');
      }
    }

    debugPrint('📊 Total guardados: ${savedPaths.length}/${imagePaths.length}');
    return savedPaths;
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR PDF
  // ─────────────────────────────────────────────────────────────
  Future<String?> savePdfFile({
    required String pdfPath,
    required String documentName,
    required bool askUserWhere,
  }) async {
    try {
      final src = File(pdfPath);
      if (!await src.exists()) {
        throw Exception('PDF no existe: $pdfPath');
      }

      // ── Carpeta de la app ──
      if (!askUserWhere) {
        final appDir = await getApplicationDocumentsDirectory();
        final targetDir = '${appDir.path}/pdfs';
        final folder = Directory(targetDir);
        if (!await folder.exists()) await folder.create(recursive: true);

        final dest = File('$targetDir/$documentName.pdf');
        await src.copy(dest.path);
        debugPrint('✅ PDF en app: ${dest.path}');
        return dest.path;
      }

      // ── SAF con file_picker ──
      debugPrint('🔍 Abriendo selector SAF para PDF...');
      final pdfBytes = await src.readAsBytes();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar PDF',
        fileName: '$documentName.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(pdfBytes),
      );
      debugPrint('🔍 Resultado PDF SAF: $result');
      return result;
    } catch (e, st) {
      debugPrint('❌ Error guardando PDF: $e');
      debugPrint('STACK: $st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COMPARTIR IMÁGENES
  // ─────────────────────────────────────────────────────────────
  Future<void> shareImages({
    required List<String> imagePaths,
    required String documentName,
    required ExportFormat format,
  }) async {
    final files = await saveImages(
      imagePaths: imagePaths,
      documentName: documentName,
      format: format,
      askUserWhere: false,
    );
    if (files.isEmpty) return;
    await Share.shareXFiles(
      files.map((p) => XFile(p)).toList(),
      subject: documentName,
    );
  }
}