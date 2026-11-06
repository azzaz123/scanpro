import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:scanpro/data/services/storage_service.dart';

import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../folder/folder_screen.dart';
import '../scanner/scanner_screen.dart';
import '../document_detail/document_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScanPro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: _DocSearchDelegate(ref),
            ),
          ),
          PopupMenuButton<SortOrder>(
  icon: const Icon(Icons.sort),
  tooltip: 'Ordenar: ${_sortLabel(ref.watch(sortOrderProvider))}',
  onSelected: (order) {
    ref.read(sortOrderProvider.notifier).state = order;
  },
  itemBuilder: (_) {
    final current = ref.watch(sortOrderProvider);
    return [
      _SortMenuItem(
        value: SortOrder.dateDesc,
        current: current,
        icon: Icons.arrow_downward,
        label: 'Más recientes primero',
        subtitle: 'Último documento arriba',
      ),
      _SortMenuItem(
        value: SortOrder.dateAsc,
        current: current,
        icon: Icons.arrow_upward,
        label: 'Más antiguos primero',
        subtitle: 'Primer documento arriba',
      ),
      const PopupMenuDivider(),
      _SortMenuItem(
        value: SortOrder.nameAsc,
        current: current,
        icon: Icons.sort_by_alpha,
        label: 'Nombre A-Z',
        subtitle: 'Alfabético ascendente',
      ),
      _SortMenuItem(
        value: SortOrder.nameDesc,
        current: current,
        icon: Icons.sort_by_alpha,
        label: 'Nombre Z-A',
        subtitle: 'Alfabético descendente',
      ),
      const PopupMenuDivider(),
      _SortMenuItem(
        value: SortOrder.favorites,
        current: current,
        icon: Icons.star,
        label: 'Favoritos primero',
        subtitle: 'Marcados con ⭐ arriba',
      ),
    ];
  },
),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined), text: 'Carpetas'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Documentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FoldersTab(onScan: _openScanner),
          _DocumentsTab(onScan: _openScanner),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showFabMenu();
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      ),
    );
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Escanear documento'),
              onTap: () {
                Navigator.pop(context);
                _openScanner();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Crear carpeta'),
              onTap: () {
                Navigator.pop(context);
                _createFolderDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    ).then((_) {
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(folderCountsProvider);
    });
  }

  Future<void> _createFolderDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la carpeta',
            hintText: 'Ej: Trabajo, Facturas, 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await ref.read(repoProvider).createFolder(name: result);
      ref.invalidate(foldersProvider);
      ref.invalidate(folderCountsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Carpeta "$result" creada ✅')),
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
}

// ═════════════════════════════════════════════════════════════
// PESTAÑA: CARPETAS
// ═════════════════════════════════════════════════════════════
class _FoldersTab extends ConsumerWidget {
  final VoidCallback onScan;
  const _FoldersTab({required this.onScan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final countsAsync = ref.watch(folderCountsProvider);
    final unfiledAsync = ref.watch(unfiledDocumentsProvider);

    return foldersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (folders) {
        final counts = countsAsync.valueOrNull ?? {};
        final unfiled = unfiledAsync.valueOrNull ?? [];

        if (folders.isEmpty && unfiled.isEmpty) {
          return _EmptyState(onScan: onScan);
        }

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            // Carpeta virtual "Sin carpeta"
            if (unfiled.isNotEmpty)
              _FolderTile(
                icon: Icons.inbox_outlined,
                color: Colors.grey,
                name: 'Sin carpeta',
                count: unfiled.length,
                onTap: () => _openFolder(context, ref, null),
              ),

            // Carpetas reales
            for (final folder in folders)
              _FolderTile(
                icon: _iconForName(folder.iconName),
                color: _colorFromHex(folder.colorHex),
                name: folder.name,
                count: counts[folder.id] ?? 0,
                onTap: () => _openFolder(context, ref, folder),
                onRename: () => _renameFolder(context, ref, folder),
                onDelete: () => _deleteFolder(context, ref, folder),
              ),
          ],
        );
      },
    );
  }

  IconData _iconForName(String? name) {
    switch (name) {
      case 'work':
        return Icons.work_outline;
      case 'home':
        return Icons.home_outlined;
      case 'star':
        return Icons.star_outline;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _colorFromHex(String? hex) {
    if (hex == null) return Colors.blue;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  void _openFolder(BuildContext context, WidgetRef ref, Folder? folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderScreen(folder: folder),
      ),
    ).then((_) {
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(folderCountsProvider);
    });
  }

  Future<void> _renameFolder(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar carpeta'),
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
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == folder.name) {
      return;
    }

    try {
      await ref.read(repoProvider).renameFolder(folder, newName);
      ref.invalidate(foldersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteFolder(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Eliminar "${folder.name}"?'),
        content: const Text(
          'La carpeta se eliminará pero los documentos NO se borrarán.\n'
          'Se moverán a "Sin carpeta".',
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
      await ref.read(repoProvider).deleteFolder(folder);
      ref.invalidate(foldersProvider);
      ref.invalidate(folderCountsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carpeta eliminada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _FolderTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _FolderTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.count,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$count documento(s)'),
        trailing: onRename != null
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename!();
                  if (value == 'delete') onDelete!();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// PESTAÑA: DOCUMENTOS
// ═════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════
// PESTAÑA: DOCUMENTOS (con selección múltiple)
// ═════════════════════════════════════════════════════════════
class _DocumentsTab extends ConsumerStatefulWidget {
  final VoidCallback onScan;
  const _DocumentsTab({required this.onScan});

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  void _enterSelectionMode(int docId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(docId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _selectAll(List<Document> docs) {
    setState(() {
      _selectedIds.addAll(docs.map((d) => d.id));
      _selectionMode = true;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected(List<Document> docs) async {
    final selectedDocs =
        docs.where((d) => _selectedIds.contains(d.id)).toList();

    if (selectedDocs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '¿Eliminar ${selectedDocs.length} documento(s)?',
        ),
        content: Text(
          selectedDocs.length == 1
              ? 'Se eliminará "${selectedDocs.first.name}".\n\nEsta acción no se puede deshacer.'
              : 'Se eliminarán ${selectedDocs.length} documentos '
                  'y todas sus páginas.\n\nEsta acción no se puede deshacer.',
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

      for (final doc in selectedDocs) {
        // Borrar imágenes del disco
        final pages = await repo.getPagesForDocument(doc.id);
        for (final page in pages) {
          await storage.deleteImage(page.imagePath);
        }
        // Borrar de Isar
        await repo.deleteDocument(doc);
      }

      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(folderCountsProvider);

      if (!mounted) return;
      _exitSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedDocs.length} documento(s) eliminado(s) ✅',
          ),
        ),
      );
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
    final docsAsync = ref.watch(filteredDocumentsProvider);
    final sortOrder = ref.watch(sortOrderProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (docs) {
        if (docs.isEmpty) {
          return _EmptyState(onScan: widget.onScan);
        }

        final sorted = applySort(docs, sortOrder);

        // Clamp: si algún doc seleccionado ya no existe, quitarlo
        _selectedIds.removeWhere(
          (id) => !sorted.any((d) => d.id == id),
        );
        if (_selectedIds.isEmpty && _selectionMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectionMode = false);
          });
        }

        return Stack(
          children: [
            Column(
              children: [
                // ── AppBar contextual (solo en modo selección) ──
                if (_selectionMode) _buildSelectionBar(sorted),

                // ── Lista ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(documentsProvider);
                      ref.invalidate(filteredDocumentsProvider);
                      ref.invalidate(unfiledDocumentsProvider);
                      ref.invalidate(folderCountsProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final doc = sorted[i];
                        final isSelected = _selectedIds.contains(doc.id);

                        return _SelectableDocumentCard(
                          doc: doc,
                          ref: ref,
                          selectionMode: _selectionMode,
                          isSelected: isSelected,
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(doc.id);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentDetailScreen(documentId: doc.id),
                                ),
                              ).then((_) {
                                ref.invalidate(documentsProvider);
                                ref.invalidate(filteredDocumentsProvider);
                                ref.invalidate(folderCountsProvider);
                              });
                            }
                          },
                          onLongPress: () {
                            if (!_selectionMode) {
                              _enterSelectionMode(doc.id);
                            } else {
                              _toggleSelection(doc.id);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // ── Botón flotante de "seleccionar todo" ──
            if (_selectionMode)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'select_all',
                  onPressed: () {
                    if (_selectedIds.length == sorted.length) {
                      _deselectAll();
                    } else {
                      _selectAll(sorted);
                    }
                  },
                  tooltip: _selectedIds.length == sorted.length
                      ? 'Deseleccionar todo'
                      : 'Seleccionar todo',
                  child: Icon(
                    _selectedIds.length == sorted.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionBar(List<Document> docs) {
    final allSelected = _selectedIds.length == docs.length;

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar selección',
              onPressed: _exitSelectionMode,
            ),
            Expanded(
              child: Text(
                '${_selectedIds.length} seleccionado(s)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: allSelected ? _deselectAll : () => _selectAll(docs),
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                size: 20,
              ),
              label: Text(allSelected ? 'Deseleccionar' : 'Todo'),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Eliminar seleccionados',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _deleteSelected(docs),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TARJETA DE DOCUMENTO SELECCIONABLE
// ═════════════════════════════════════════════════════════════
class _SelectableDocumentCard extends StatelessWidget {
  final Document doc;
  final WidgetRef ref;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SelectableDocumentCard({
    required this.doc,
    required this.ref,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: selectionMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
                    ),
                    _DocThumbnail(documentId: doc.id),
                  ],
                )
              : _DocThumbnail(documentId: doc.id),
          title: Text(
            doc.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${doc.pageCount} pág. • '
            '${DateFormat.yMMMd().add_Hm().format(doc.createdAt)}',
          ),
          trailing: selectionMode
              ? null
              : (doc.isFavorite
                  ? const Icon(Icons.star, color: Colors.amber)
                  : null),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FAVORITO
  // ─────────────────────────────────────────────────────────────
  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      await ref.read(repoProvider).toggleFavorite(doc);
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              doc.isFavorite
                  ? 'Quitado de favoritos'
                  : 'Añadido a favoritos',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR (con confirmación)
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar documento?'),
        content: Text(
          'Se eliminará "${doc.name}" y sus '
          '${doc.pageCount} página(s).\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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

      // 2. Borrar de Isar
      await repo.deleteDocument(doc);

      // 3. Refrescar
      ref.invalidate(documentsProvider);
      ref.invalidate(filteredDocumentsProvider);
      ref.invalidate(unfiledDocumentsProvider);
      ref.invalidate(folderCountsProvider);
      ref.invalidate(foldersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${doc.name}" eliminado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET (long press)
  // ─────────────────────────────────────────────────────────────
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle visual
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Mover a carpeta'),
              onTap: () {
                Navigator.pop(context);
                _moveToFolderDialog(context, ref, doc);
              },
            ),
            ListTile(
              leading: Icon(
                doc.isFavorite ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              title: Text(
                doc.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar documento',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
  Future<void> _moveToFolderDialog(
    BuildContext context, WidgetRef ref, Document doc) async {
  final folders = await ref.read(repoProvider).getAllFolders();

  if (!context.mounted) return;

  if (folders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea una carpeta primero (FAB → Crear carpeta)'),
      ),
    );
    return;
  }

  // Copia local del estado (para que el checkbox se actualice visualmente)
  final selectedIds = <int>{...doc.folderIds};

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        return AlertDialog(
          title: const Text('Mover a carpeta'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final folder in folders)
                  CheckboxListTile(
                    value: selectedIds.contains(folder.id),
                    title: Text(folder.name),
                    onChanged: (checked) async {
                      // 1. Actualizar UI inmediatamente
                      setState(() {
                        if (checked == true) {
                          selectedIds.add(folder.id);
                        } else {
                          selectedIds.remove(folder.id);
                        }
                      });

                      // 2. Persistir en BD
                      try {
                        if (checked == true) {
                          await ref.read(repoProvider).addDocumentToFolder(doc.id, folder.id);

                        } else {
                          await ref
                              .read(repoProvider)
                              .removeDocumentFromFolder(doc, folder.id);
                        }

                        // 3. Refrescar providers
                        ref.invalidate(foldersProvider);
                        ref.invalidate(folderCountsProvider);
                        ref.invalidate(documentsProvider);
                        ref.invalidate(filteredDocumentsProvider);
                        ref.invalidate(unfiledDocumentsProvider);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            if (selectedIds.isNotEmpty)
              TextButton(
                onPressed: () async {
                  // Quitar de TODAS las carpetas
                  for (final id in selectedIds.toList()) {
                    await ref
                        .read(repoProvider)
                        .removeDocumentFromFolder(doc, id);
                  }
                  setState(() => selectedIds.clear());

                  ref.invalidate(foldersProvider);
                  ref.invalidate(folderCountsProvider);
                  ref.invalidate(documentsProvider);
                  ref.invalidate(filteredDocumentsProvider);
                  ref.invalidate(unfiledDocumentsProvider);
                },
                child: const Text(
                  'Quitar de todas',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    ),
  );
}


class _DocThumbnail extends ConsumerWidget {
  final int documentId;
  const _DocThumbnail({required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FutureBuilder(
        future: ref.read(repoProvider).getPagesForDocument(documentId),
        builder: (context, snap) {
          if (!snap.hasData || (snap.data as List).isEmpty) {
            return const Icon(Icons.description_outlined, size: 32);
          }
          final pages = snap.data as List;
          final file = File(pages.first.imagePath);
          if (!file.existsSync()) {
            return const Icon(Icons.broken_image_outlined, size: 32);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 120,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Aún no tienes documentos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanea tu primer documento',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.add),
              label: const Text('Escanear ahora'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// SEARCH DELEGATE
// ═════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════
// SEARCH DELEGATE MEJORADO (carpetas + documentos)
// ═════════════════════════════════════════════════════════════
class _DocSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  _DocSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Buscar documentos o carpetas';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Limpiar',
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return _RecentHint();
    }

    final q = query.trim().toLowerCase();

    // Buscar en carpetas
    final foldersAsync = ref.watch(foldersProvider);
    final docsAsync = ref.watch(documentsProvider);

    return foldersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (folders) {
        final matchedFolders = folders
            .where((f) => f.name.toLowerCase().contains(q))
            .toList();

        return docsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (docs) {
            final matchedDocs = docs
                .where((d) => d.name.toLowerCase().contains(q))
                .toList();

            if (matchedFolders.isEmpty && matchedDocs.isEmpty) {
              return _NoResults(query: query);
            }

            // Necesitamos los nombres de carpetas para mostrarlos
            final folderMap = {for (final f in folders) f.id: f.name};

            return ListView(
              children: [
                // ── Carpetas ──
                if (matchedFolders.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.folder_outlined,
                    title: 'Carpetas',
                    count: matchedFolders.length,
                  ),
                  for (final folder in matchedFolders)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorFromHex(
                                folder.colorHex)
                            .withOpacity(0.15),
                        child: Icon(
                          Icons.folder,
                          color: _colorFromHex(folder.colorHex),
                        ),
                      ),
                      title: _HighlightedText(
                        text: folder.name,
                        query: query,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        close(context, null);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FolderScreen(folder: folder),
                          ),
                        );
                      },
                    ),
                ],

                // ── Documentos ──
                if (matchedDocs.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.description_outlined,
                    title: 'Documentos',
                    count: matchedDocs.length,
                  ),
                  for (final doc in matchedDocs)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: _HighlightedText(
                        text: doc.name,
                        query: query,
                      ),
                      subtitle: Text(
                        _folderPathFor(doc, folderMap),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: doc.isFavorite
                          ? const Icon(Icons.star,
                              color: Colors.amber, size: 20)
                          : null,
                      onTap: () {
                        close(context, null);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(
                              documentId: doc.id,
                            ),
                          ),
                        );
                      },
                    ),
                ],

                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  String _folderPathFor(
      Document doc, Map<int, String> folderMap) {
    if (doc.folderIds.isEmpty) return 'Sin carpeta';
    final names = doc.folderIds
        .map((id) => folderMap[id])
        .whereType<String>()
        .toList();
    if (names.isEmpty) return 'Sin carpeta';
    return '📁 ${names.join(' · ')}';
  }

  Color _colorFromHex(String? hex) {
    if (hex == null) return Colors.blue;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// ═════════════════════════════════════════════════════════════
// HELPERS DE UI
// ═════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final start = lower.indexOf(q);
    if (start == -1) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final before = text.substring(0, start);
    final match = text.substring(start, start + query.length);
    final after = text.substring(start + query.length);

    final boldStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: before),
          TextSpan(text: match, style: boldStyle),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin resultados para "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otro nombre de documento o carpeta',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Buscar en ScanPro',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe el nombre de un documento o carpeta',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
  
}
// ═════════════════════════════════════════════════════════════
// HELPER: LABEL DEL ORDEN ACTUAL (para el tooltip)
// ═════════════════════════════════════════════════════════════
String _sortLabel(SortOrder order) {
  switch (order) {
    case SortOrder.dateDesc:
      return 'Más recientes primero';
    case SortOrder.dateAsc:
      return 'Más antiguos primero';
    case SortOrder.nameAsc:
      return 'Nombre A-Z';
    case SortOrder.nameDesc:
      return 'Nombre Z-A';
    case SortOrder.favorites:
      return 'Favoritos primero';
  }
}

// ═════════════════════════════════════════════════════════════
// ITEM DE MENÚ CON CHECK E ICONO
// ═════════════════════════════════════════════════════════════
class _SortMenuItem extends PopupMenuItem<SortOrder> {
  final SortOrder current;
  final IconData icon;

  _SortMenuItem({
    required SortOrder value,
    required this.current,
    required this.icon,
    required String label,
    required String subtitle,
  }) : super(
          value: value,
          child: Row(
            children: [
              // Icono del tipo de orden
              Icon(
                icon,
                size: 20,
                color: value == current
                    ? Colors.blue
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),

              // Texto + subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: value == current
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: value == current ? Colors.blue : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Check si es el activo
              if (value == current)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20, color: Colors.blue),
                ),
            ],
          ),
        );
}