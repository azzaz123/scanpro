import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/document.dart';
import '../../data/models/page.dart';
import '../../data/services/export_service.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/scanner_service.dart';
import '../../data/services/storage_service.dart';
import '../home/home_providers.dart';

// ─────────────────────────────────────────────────────────────
// FUNCIONES TOP-LEVEL (isolate)
// ─────────────────────────────────────────────────────────────

/// Rota la imagen. angle = 90 (derecha) o -90 (izquierda).
List<int> _rotateImageSync(Map<String, dynamic> args) {
  final bytes = args['bytes'] as List<int>;
  final angle = args['angle'] as int;

  var decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) {
    throw Exception('No se pudo decodificar la imagen');
  }

  if (decoded.width > 1600 || decoded.height > 1600) {
    final maxSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final scale = 1600 / maxSide;
    decoded = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final rotated = img.copyRotate(decoded!, angle: angle);
  return img.encodeJpg(rotated, quality: 85);
}

// ─────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final int documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  late Future<(Document?, List<DocumentPage>)> _future;
  int _currentPage = 0;
  bool _busy = false;

  /// Texto del overlay de carga. null = sin overlay.
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ─────────────────────────────────────────────────────────────
  // CARGA
  // ─────────────────────────────────────────────────────────────
  Future<(Document?, List<DocumentPage>)> _load() async {
    final repo = ref.read(repoProvider);
    final docs = await repo.getAllDocuments();
    final doc = docs.firstWhere(
      (d) => d.id == widget.documentId,
      orElse: () => throw Exception('Documento no encontrado'),
    );
    final pages = await repo.getPagesForDocument(doc.id);
    return (doc, pages);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _setLoading(String? msg) {
    if (!mounted) return;
    setState(() => _loadingMessage = msg);
  }

  String _sanitize(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
  }

  // ─────────────────────────────────────────────────────────────
  // COMPARTIR PDF
  // ─────────────────────────────────────────────────────────────
  Future<void> _share(Document doc, List<DocumentPage> pages) async {
    if (pages.isEmpty) return;
    _setLoading('Generando PDF...');
    try {
      final pdf = await PdfService().generatePdf(
        imagePaths: pages.map((p) => p.imagePath).toList(),
        documentName: doc.name,
      );
      await Share.shareXFiles([XFile(pdf.path)], subject: doc.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    } finally {
      _setLoading(null);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COMPARTIR IMÁGENES (JPG/PNG)
  // ─────────────────────────────────────────────────────────────
  Future<void> _shareImages(
    Document doc,
    List<DocumentPage> pages,
    ExportFormat format,
  ) async {
    if (pages.isEmpty) return;
    _setLoading('Generando ${format == ExportFormat.png ? 'PNG' : 'JPG'}...');
    try {
      await ExportService().shareImages(
        imagePaths: pages.map((p) => p.imagePath).toList(),
        documentName: _sanitize(doc.name),
        format: format,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    } finally {
      _setLoading(null);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR PDF RÁPIDO (a carpeta de la app)
  // ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf(Document doc, List<DocumentPage> pages) async {
    if (pages.isEmpty) return;
    _setLoading('Exportando PDF...');
    try {
      final pdf = await PdfService().generatePdf(
        imagePaths: pages.map((p) => p.imagePath).toList(),
        documentName: doc.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF guardado en: ${pdf.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF: $e')),
        );
      }
    } finally {
      _setLoading(null);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR (diálogo de formato + destino)
  // ─────────────────────────────────────────────────────────────
 Future<void> _exportDialog(Document doc, List<DocumentPage> pages) async {
  if (pages.isEmpty) return;

  // 1. Elegir formato
  final format = await showDialog<ExportFormat>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('¿Cómo guardar el documento?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('PDF'),
            subtitle: const Text('Todas las páginas en un solo archivo'),
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Imágenes JPG'),
            subtitle: Text(
              '${pages.length} archivo(s), buena calidad, menos peso',
            ),
            onTap: () => Navigator.pop(context, ExportFormat.jpg),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Imágenes PNG'),
            subtitle: Text(
              '${pages.length} archivo(s), máxima calidad, más peso',
            ),
            onTap: () => Navigator.pop(context, ExportFormat.png),
          ),
        ],
      ),
    ),
  );

  if (format == null) return;

  // 2. Elegir destino
  final askWhere = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('¿Dónde guardar?'),
      content: const Text(
        'Carpeta de la app: rápido, sin más diálogos.\n\n'
        'Elegir destino: se abrirá el selector de Android '
        '(1 diálogo por archivo).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Carpeta de la app'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Elegir destino'),
        ),
      ],
    ),
  );

  if (askWhere == null) return;

  // ⬇️ Guardar messenger ANTES de los awaits (fix context across async)
  final messenger = ScaffoldMessenger.of(context);

  // 3. Exportar
  _setLoading('Exportando...');
  try {
    final exportService = ExportService();

    if (format == ExportFormat.pdf) {
      // ── PDF ──
      final pdf = await PdfService().generatePdf(
        imagePaths: pages.map((p) => p.imagePath).toList(),
        documentName: doc.name,
      );

      final savedPath = await exportService.savePdfFile(
        pdfPath: pdf.path,
        documentName: _sanitize(doc.name),
        askUserWhere: askWhere, // ✅ CORREGIDO (antes: askUserWhere)
      );

      if (!mounted) return;
      _setLoading(null);
      if (savedPath == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Guardado cancelado')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('PDF guardado: $savedPath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else {
      // ── IMÁGENES ──
      final savedPaths = await exportService.saveImages(
        imagePaths: pages.map((p) => p.imagePath).toList(),
        documentName: _sanitize(doc.name),
        format: format,
        askUserWhere: askWhere, // ✅ CORREGIDO (antes: askUserWhere)
      );

      if (!mounted) return;
      _setLoading(null);
      if (savedPaths.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se guardó ningún archivo')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${savedPaths.length} imagen(es) guardada(s)\n'
              'Última: ${savedPaths.last}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  } catch (e, st) {
    debugPrint('❌ ERROR EN EXPORTAR: $e');
    debugPrint('STACK: $st');
    if (!mounted) return;
    _setLoading(null);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Error al exportar: $e'),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

  // ─────────────────────────────────────────────────────────────
  // OCR
  // ─────────────────────────────────────────────────────────────
  Future<void> _ocr(Document doc, List<DocumentPage> pages) async {
    if (pages.isEmpty) return;
    _setLoading('Extrayendo texto (OCR)...');
    final messenger = ScaffoldMessenger.of(context);

    try {
      final text = await OcrService().extractTextFromMultiple(
        pages.map((p) => p.imagePath).toList(),
      );
      await ref.read(repoProvider).updateOcrText(doc, text);

      if (!mounted) return;
      _setLoading(null);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Texto extraído (OCR)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _setLoading(null);
        messenger.showSnackBar(SnackBar(content: Text('Error OCR: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ROTAR página
  // ─────────────────────────────────────────────────────────────
  Future<void> _rotatePage(DocumentPage page, {required int angle}) async {
    if (_busy) return;
    setState(() => _busy = true);
    _setLoading(
      angle > 0 ? 'Rotando a la derecha...' : 'Rotando a la izquierda...',
    );

    final started = DateTime.now();
    try {
      final file = File(page.imagePath);
      if (!await file.exists()) {
        throw Exception('Archivo no encontrado: ${page.imagePath}');
      }

      final bytes = await file.readAsBytes();

      final rotatedBytes = await compute(
        _rotateImageSync,
        {'bytes': bytes, 'angle': angle},
      );

      final dir = file.parent;
      final ext = file.path.split('.').last;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/${stamp}_rot.$ext';
      await File(newPath).writeAsBytes(rotatedBytes);

      await ref.read(repoProvider).updatePageImage(page, newPath);

      try {
        await file.delete();
      } catch (_) {}

      final ms = DateTime.now().difference(started).inMilliseconds;
      debugPrint('✅ Rotación (${angle}°) completada en ${ms}ms → $newPath');

      if (!mounted) return;
      _reload();
      _setLoading(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Página rotada en ${ms}ms ✅')),
      );
    } catch (e, st) {
      debugPrint('❌ Error al rotar: $e');
      debugPrint('$st');
      if (!mounted) return;
      _setLoading(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rotar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RECORTAR página
  // ─────────────────────────────────────────────────────────────
  Future<void> _cropPage(DocumentPage page) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: page.imagePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar página',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
        ],
      );

      if (cropped != null && cropped.path != page.imagePath) {
        final oldFile = File(page.imagePath);
        final dir = oldFile.parent;
        final ext = oldFile.path.split('.').last;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final newPath = '${dir.path}/${stamp}_crop.$ext';

        final bytes = await File(cropped.path).readAsBytes();
        await File(newPath).writeAsBytes(bytes);
        await ref.read(repoProvider).updatePageImage(page, newPath);

        try {
          await oldFile.delete();
        } catch (_) {}

        if (!mounted) return;
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recortar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // AÑADIR página
  // ─────────────────────────────────────────────────────────────
  Future<void> _addPage(Document doc) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final scanner = ScannerService();
      final newImages = await scanner.scanWithMLKit();
      if (newImages == null || newImages.isEmpty) return;

      _setLoading('Guardando nuevas páginas...');
      final storage = StorageService();
      final repo = ref.read(repoProvider);
      final existingPages = await repo.getPagesForDocument(doc.id);

      for (int i = 0; i < newImages.length; i++) {
        final permanentPath = await storage.savePermanentImage(newImages[i]);
        await repo.addPageToDocument(
          doc,
          permanentPath,
          existingPages.length + i,
        );
      }

      if (!mounted) return;
      _reload();
      _setLoading(null);
      ref.invalidate(documentsProvider);
    } catch (e) {
      if (mounted) {
        _setLoading(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al añadir página: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR página
  // ─────────────────────────────────────────────────────────────
  Future<void> _deletePage(Document doc, DocumentPage page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar esta página?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final storage = StorageService();
      await storage.deleteImage(page.imagePath);
      await ref.read(repoProvider).deletePage(page);

      if (!mounted) return;
      setState(() {
        _currentPage = 0;
        _future = _load();
      });
      ref.invalidate(documentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar página: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR documento
  // ─────────────────────────────────────────────────────────────
  Future<void> _deleteDocument(
    Document doc,
    List<DocumentPage> pages,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar documento?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      _setLoading('Eliminando documento...');
      final storage = StorageService();
      for (final p in pages) {
        await storage.deleteImage(p.imagePath);
      }
      await ref.read(repoProvider).deleteDocument(doc);
      ref.invalidate(documentsProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _setLoading(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RENOMBRAR
  // ─────────────────────────────────────────────────────────────
  Future<void> _rename(Document doc) async {
    final controller = TextEditingController(text: doc.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar documento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != doc.name) {
      try {
        await ref.read(repoProvider).renameDocument(doc, newName);
        if (!mounted) return;
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al renombrar: $e')),
          );
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Document?, List<DocumentPage>)>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final (doc, pages) = snapshot.data!;
        if (doc == null) {
          return const Scaffold(
            body: Center(child: Text('No encontrado')),
          );
        }

        if (pages.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(doc.name)),
            body: const Center(child: Text('Sin páginas')),
          );
        }

        if (_currentPage >= pages.length) {
          _currentPage = pages.length - 1;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(doc.name),
            actions: [
              IconButton(
                icon: Icon(doc.isFavorite ? Icons.star : Icons.star_border),
                tooltip: 'Favorito',
                onPressed: () async {
                  try {
                    await ref.read(repoProvider).toggleFavorite(doc);
                    if (!mounted) return;
                    _reload();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _rename(doc);
                      break;
                    case 'export':
                      _exportDialog(doc, pages);
                      break;
                    case 'pdf':
                      _exportPdf(doc, pages);
                      break;
                    case 'share':
                      _share(doc, pages);
                      break;
                    case 'shareJpg':
                      _shareImages(doc, pages, ExportFormat.jpg);
                      break;
                    case 'sharePng':
                      _shareImages(doc, pages, ExportFormat.png);
                      break;
                    case 'ocr':
                      _ocr(doc, pages);
                      break;
                    case 'deletePage':
                      _deletePage(doc, pages[_currentPage]);
                      break;
                    case 'delete':
                      _deleteDocument(doc, pages);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Renombrar'),
                  ),
                  
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Exportar (PDF/Imagen)'),
                  ),
                
                  const PopupMenuItem(
                    value: 'share',
                    child: Text('Compartir PDF'),
                  ),
                  const PopupMenuItem(
                    value: 'shareJpg',
                    child: Text('Compartir JPG'),
                  ),
                  const PopupMenuItem(
                    value: 'sharePng',
                    child: Text('Compartir PNG'),
                  ),
                  const PopupMenuItem(
                    value: 'ocr',
                    child: Text('Extraer texto (OCR)'),
                  ),
                  const PopupMenuItem(
                    value: 'deletePage',
                    child: Text('Eliminar página actual'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Eliminar documento',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // 🖼️ Visor con zoom
                  Expanded(
                    child: PhotoViewGallery.builder(
                      itemCount: pages.length,
                      pageController:
                          PageController(initialPage: _currentPage),
                      onPageChanged: (i) =>
                          setState(() => _currentPage = i),
                      builder: (context, index) =>
                          PhotoViewGalleryPageOptions(
                        key: ValueKey(pages[index].imagePath),
                        imageProvider:
                            FileImage(File(pages[index].imagePath)),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        heroAttributes: PhotoViewHeroAttributes(
                          tag: 'page_$index',
                        ),
                      ),
                      loadingBuilder: (context, event) =>
                          const Center(child: CircularProgressIndicator()),
                      backgroundDecoration:
                          const BoxDecoration(color: Colors.black),
                    ),
                  ),

                  // 📊 Barra inferior
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text(
                            '${_currentPage + 1} / ${pages.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: _currentPage < pages.length - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.rotate_left),
                            tooltip: 'Rotar a la izquierda',
                            onPressed: _busy
                                ? null
                                : () => _rotatePage(
                                      pages[_currentPage],
                                      angle: -90,
                                    ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.rotate_right),
                            tooltip: 'Rotar a la derecha',
                            onPressed: _busy
                                ? null
                                : () => _rotatePage(
                                      pages[_currentPage],
                                      angle: 90,
                                    ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.crop),
                            tooltip: 'Recortar',
                            onPressed: _busy
                                ? null
                                : () => _cropPage(pages[_currentPage]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Añadir página',
                            onPressed:
                                _busy ? null : () => _addPage(doc),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 🟢 OVERLAY DE CARGA
              if (_loadingMessage != null)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 20),
                                Text(
                                  _loadingMessage!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Por favor, espera...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}