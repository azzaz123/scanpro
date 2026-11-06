import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/folder.dart';
import '../../data/services/image_enhancer_service.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/scanner_service.dart';
import '../../data/services/storage_service.dart';
import '../home/home_providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _scanner = ScannerService();
  final _storage = StorageService();
  final _pdf = PdfService();

  List<String> _images = [];
  bool _busy = false;
  bool _createPdf = true;
  bool _withOcr = true; // ⬅️ texto seleccionable
  String _busyMessage = 'Procesando...';
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = _defaultName();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultName() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Doc ${now.day}-${now.month}-${now.year} $hh:$mm';
  }

  Future<void> _scan() async {
  setState(() {
    _busy = true;
    _busyMessage = 'Abriendo escáner...';
  });
  try {
    final imgs = await _scanner.scanWithMLKit();

    debugPrint('🔍 ML Kit devolvió ${imgs?.length ?? 0} imágenes');
    debugPrint('📸 _images ANTES: ${_images.length}');

    if (imgs != null && imgs.isNotEmpty) {
      setState(() {
        // ✅ ACUMULA (no reemplaza) y filtra duplicados
        final combined = [..._images, ...imgs];
        final seen = <String>{};
        _images = combined.where((p) => seen.add(p)).toList();
      });

      debugPrint('📸 _images DESPUÉS: ${_images.length}');
      for (int i = 0; i < _images.length; i++) {
        debugPrint('   [$i]: ${_images[i]}');
      }
    }
  } catch (e) {
    _showError('Error al escanear: $e');
  } finally {
    setState(() => _busy = false);
  }
}

Future<void> _importGallery() async {
  setState(() {
    _busy = true;
    _busyMessage = 'Importando...';
  });
  try {
    final imgs = await _scanner.pickFromGallery();

    debugPrint('🖼️ Galería devolvió ${imgs.length} imágenes');

    if (imgs.isNotEmpty) {
      setState(() {
        final combined = [..._images, ...imgs];
        final seen = <String>{};
        _images = combined.where((p) => seen.add(p)).toList();
      });

      debugPrint('📸 _images DESPUÉS: ${_images.length}');
    }
  } catch (e) {
    _showError('Error al importar: $e');
  } finally {
    setState(() => _busy = false);
  }
}
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR
  // ─────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_images.isEmpty) return;

    final result = await _showSaveDialog();
    if (result == null) return;

    final name = result.$1;
    final folderIds = result.$2;

    setState(() {
      _busy = true;
      _busyMessage = 'Procesando imágenes...';
    });

    try {
      final permanentPaths = <String>[];
      final enhancer = ImageEnhancerService();

      // 1. Procesar imágenes (comprimir + auto-crop)
      for (int i = 0; i < _images.length; i++) {
        setState(() {
          _busyMessage =
              'Procesando imagen ${i + 1} / ${_images.length}...';
        });

        final compressedPath =
            await _storage.savePermanentImage(_images[i]);
        debugPrint('✂️ Auto-crop + resize A4...');
        await enhancer.autoCropAndResize(compressedPath);

        permanentPaths.add(compressedPath);
      }
      debugPrint('💾 Imágenes permanentes: $permanentPaths');

      // 2. Guardar en Isar
      setState(() => _busyMessage = 'Guardando documento...');
      final repo = ref.read(repoProvider);
      final doc = await repo.createDocument(
        name: name,
        imagePaths: permanentPaths,
      );

      // 3. Asignar a carpetas
      for (final folderId in folderIds) {
  await repo.addDocumentToFolder(doc.id, folderId);   // ← doc.id, no doc
}

      // 4. Generar PDF
      if (_createPdf) {
        setState(() {
          _busyMessage = _withOcr
              ? 'Generando PDF con OCR...\n(esto puede tardar)'
              : 'Generando PDF...';
        });

        await _pdf.generatePdf(
          imagePaths: permanentPaths,
          documentName: doc.name,
          withOcrText: _withOcr,
        );
      }

      // 5. Refrescar providers
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(folderCountsProvider);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documento "$name" guardado ✅')),
      );
    } catch (e, st) {
      debugPrint('❌ ERROR en _save: $e');
      debugPrint('$st');
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGO DE GUARDAR
  // ─────────────────────────────────────────────────────────────
  Future<(String, List<int>)?> _showSaveDialog() async {
    final folders = await ref.read(repoProvider).getAllFolders();
    if (!mounted) return null;

    final localFolders = <Folder>[...folders];
    final selectedIds = <int>{};
    final nameCtrl = TextEditingController(text: _nameController.text);

    final result = await showDialog<(String, List<int>)>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: const Text('Guardar documento'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nombre ──
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del documento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── PDF ──
                    CheckboxListTile(
                      value: _createPdf,
                      onChanged: (v) => setStateDialog(
                          () => _createPdf = v ?? true),
                      title: const Text('Generar PDF automáticamente'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    // ── OCR (solo si PDF activado) ──
                    if (_createPdf)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: CheckboxListTile(
                          value: _withOcr,
                          onChanged: (v) => setStateDialog(
                              () => _withOcr = v ?? true),
                          title: const Text(
                            'Texto seleccionable (OCR)',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Permite buscar y copiar texto en el PDF. '
                            'Tarda ~2s por página.',
                            style: TextStyle(fontSize: 11),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ),

                    const Divider(),

                    // ── Carpetas ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Carpetas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final newName = await _createFolderInline();
                            if (newName != null) {
                              final newFolder = await ref
                                  .read(repoProvider)
                                  .createFolder(name: newName);
                              setStateDialog(() {
                                localFolders.add(newFolder);
                                selectedIds.add(newFolder.id);
                              });
                              ref.invalidate(foldersProvider);
                              ref.invalidate(folderCountsProvider);
                            }
                          },
                          icon: const Icon(Icons.create_new_folder,
                              size: 18),
                          label: const Text('Crear nueva'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (localFolders.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aún no tienes carpetas. '
                          'Se guardará en "Sin carpeta".',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      for (final folder in localFolders)
                        CheckboxListTile(
                          value: selectedIds.contains(folder.id),
                          onChanged: (checked) {
                            setStateDialog(() {
                              if (checked == true) {
                                selectedIds.add(folder.id);
                              } else {
                                selectedIds.remove(folder.id);
                              }
                            });
                          },
                          title: Text(folder.name),
                          secondary: const Icon(
                            Icons.folder_outlined,
                            size: 22,
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),

                    if (selectedIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠️ Sin carpeta seleccionada: '
                          'irá a "Sin carpeta".',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Pon un nombre al documento'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    (name, selectedIds.toList()),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Future<String?> _createFolderInline() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Trabajo, Facturas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext, name);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner'),
        actions: [
          if (_images.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : _save,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_images.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            size: 100),
                        const SizedBox(height: 16),
                        const Text('No hay páginas escaneadas'),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _scan,
                          icon: const Icon(Icons.document_scanner),
                          label: const Text('Escanear'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _images.length,
                    itemBuilder: (context, i) => Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(_images[i]),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text('Página ${i + 1}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _images.removeAt(i)),
                        ),
                      ),
                    ),
                  ),
                ),

              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _scan,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Añadir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _importGallery,
                          icon: const Icon(
                              Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _busyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}