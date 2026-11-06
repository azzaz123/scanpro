import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

class ScannerService {
  Future<List<String>?> scanWithMLKit({int pageLimit = 20}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.full,
        pageLimit: pageLimit,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      debugPrint('🔍 ML Kit devolvió: ${result.images}');
      return result.images;
    } catch (e) {
      debugPrint('❌ Error ML Kit: $e');
      return null;
    } finally {
      scanner.close();
    }
  }

  Future<List<String>> pickFromGallery() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 95);
    debugPrint('🖼️ Galería: ${files.length} imágenes');
    return files.map((f) => f.path).toList();
  }
}