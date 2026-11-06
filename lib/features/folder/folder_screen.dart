import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../document_detail/document_detail_screen.dart';
import '../home/home_providers.dart';

class FolderScreen extends ConsumerWidget {
  final Folder? folder; // null = "Sin carpeta"
  const FolderScreen({super.key, this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = folder?.name ?? 'Sin carpeta';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _FolderBody(folder: folder),
    );
  }
}

class _FolderBody extends ConsumerStatefulWidget {
  final Folder? folder;
  const _FolderBody({this.folder});

  @override
  ConsumerState<_FolderBody> createState() => _FolderBodyState();
}

class _FolderBodyState extends ConsumerState<_FolderBody> {
  late Future<List<Document>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Document>> _load() async {
    final repo = ref.read(repoProvider);
    if (widget.folder == null) {
      return repo.getUnfiledDocuments();
    }
    return repo.getDocumentsInFolder(widget.folder!.id);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR DOCUMENTO COMPLETO
  // ─────────────────────────────────────────────────────────────
  Future<void> _deleteDocument(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar documento?'),
        content: Text(
          'Se eliminará "${doc.name}" y sus ${doc.pageCount} página(s).\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final storage = StorageService();
      final repo = ref.read(repoProvider);

      // 1. Borrar imágenes del disco
      final pages = await repo.getPagesForDocument(doc.id);
      for (final page in pages) {
        await storage.deleteImage(page.imagePath);
      }

      // 2. Borrar documento y páginas de Isar
      await repo.deleteDocument(doc);

      // 3. Refrescar
      if (!mounted) return;
      _reload();
      ref.invalidate(foldersProvider);
      ref.invalidate(folderCountsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${doc.name}" eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // QUITAR DE ESTA CARPETA (sin borrar)
  // ─────────────────────────────────────────────────────────────
  Future<void> _removeFromFolder(Document doc) async {
    if (widget.folder == null) return;
    try {
      await ref
          .read(repoProvider)
          .removeDocumentFromFolder(doc, widget.folder!.id);

      if (!mounted) return;
      _reload();
      ref.invalidate(foldersProvider);
      ref.invalidate(folderCountsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(documentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${doc.name}" quitado de la carpeta'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Document>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 100,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Carpeta vacía',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mantén pulsado un documento en la home\npara moverlo aquí',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: _Thumb(documentId: doc.id),
                ),
                title: Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${doc.pageCount} pág. • '
                  '${DateFormat.yMMMd().add_Hm().format(doc.createdAt)}',
                ),
                // ⬇️ Menú con 2 opciones
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'remove':
                        _removeFromFolder(doc);
                        break;
                      case 'delete':
                        _deleteDocument(doc);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (widget.folder != null)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline,
                                color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text('Quitar de la carpeta'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar documento',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DocumentDetailScreen(documentId: doc.id),
                  ),
                ).then((_) => _reload()),
              ),
            );
          },
        );
      },
    );
  }
}

class _Thumb extends ConsumerWidget {
  final int documentId;
  const _Thumb({required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(repoProvider).getPagesForDocument(documentId),
      builder: (context, snap) {
        if (!snap.hasData || (snap.data as List).isEmpty) {
          return const Icon(Icons.description_outlined);
        }
        final pages = snap.data as List;
        final file = File(pages.first.imagePath);
        if (!file.existsSync()) {
          return const Icon(Icons.broken_image_outlined);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, fit: BoxFit.cover),
        );
      },
    );
  }
}