import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ocr_service.dart';

class PdfService {
  final OcrService _ocr = OcrService();

  Future<File> generatePdf({
    required List<String> imagePaths,
    required String documentName,
    bool withOcrText = true,
    bool addPageNumbers = false,
  }) async {
    // Fuente Unicode
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
    );

    for (int i = 0; i < imagePaths.length; i++) {
      final bytes = await File(imagePaths[i]).readAsBytes();
      final image = pw.MemoryImage(bytes);

      // Extraer texto con posiciones
      OcrPageData? ocrData;
      if (withOcrText) {
        try {
          ocrData = await _ocr.extractPageWithPositions(imagePaths[i]);
        } catch (e) {
          // Si falla el OCR, seguimos sin texto
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10),
          build: (ctx) {
            // Dimensiones del A4 sin márgenes
            final a4Width = PdfPageFormat.a4.width - 20;
            final a4Height = PdfPageFormat.a4.height - 20;

            // ⬇️ Cast a double (image.width puede ser int?)
            final imageWidth = image.width?.toDouble() ?? 1.0;
            final imageHeight = image.height?.toDouble() ?? 1.0;
            final aspect = imageWidth / imageHeight;
            final a4Aspect = a4Width / a4Height;

            // Calcular tamaño que ocupa la imagen (fit: contain)
            double imgWidth, imgHeight, imgOffsetX, imgOffsetY;
            if (aspect > a4Aspect) {
              imgWidth = a4Width;
              imgHeight = a4Width / aspect;
              imgOffsetX = 0;
              imgOffsetY = (a4Height - imgHeight) / 2;
            } else {
              imgHeight = a4Height;
              imgWidth = a4Height * aspect;
              imgOffsetX = (a4Width - imgWidth) / 2;
              imgOffsetY = 0;
            }

            return pw.Stack(
              children: [
                // ═══════════════════════════════════════════════
                // 1. IMAGEN DE FONDO
                // ═══════════════════════════════════════════════
                pw.Positioned(
                  left: imgOffsetX,
                  top: imgOffsetY,
                  child: pw.SizedBox(
                    width: imgWidth,
                    height: imgHeight,
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),

                // ═══════════════════════════════════════════════
                // 2. TEXTO OCR (invisible pero seleccionable)
                // ═══════════════════════════════════════════════
                if (ocrData != null)
                  ...ocrData.blocks.map((block) {
                    // Coordenadas relativas → PDF
                    final left = imgOffsetX + block.x * imgWidth;
                    final top = imgOffsetY + block.y * imgHeight;
                    final width = block.width * imgWidth;
                    final height = block.height * imgHeight;

                    // Tamaño de fuente proporcional
                    final fontSize =
                        (height * 0.85).clamp(2.0, 30.0).toDouble();

                    return pw.Positioned(
                      left: left,
                      top: top,
                      child: pw.SizedBox(
                        width: width,
                        height: height,
                        child: pw.Opacity(
                          opacity: 0.01, // casi invisible, seleccionable
                          child: pw.Text(
                            block.text,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: fontSize,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ),
                    );
                  }),   // ⬅️ sin .toList()

                // ═══════════════════════════════════════════════
                // 3. Número de página (opcional)
                // ═══════════════════════════════════════════════
                if (addPageNumbers)
                  pw.Positioned(
                    bottom: 4,
                    right: 8,
                    child: pw.Text(
                      '${i + 1} / ${imagePaths.length}',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Guardar
    final dir = await getApplicationDocumentsDirectory();
    final pdfsFolder = Directory('${dir.path}/pdfs');
    if (!await pdfsFolder.exists()) {
      await pdfsFolder.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sanitized = documentName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName =
        sanitized.isEmpty ? 'documento_$timestamp' : '${sanitized}_$timestamp';
    final file = File('${pdfsFolder.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}