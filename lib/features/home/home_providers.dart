import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../data/repositories/document_repository.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────
// REPOSITORIO
// ─────────────────────────────────────────────────────────────
final repoProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(isarInstance);
});

// ─────────────────────────────────────────────────────────────
// DOCUMENTOS
// ─────────────────────────────────────────────────────────────
final documentsProvider = FutureProvider<List<Document>>((ref) async {
  return ref.watch(repoProvider).getAllDocuments();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredDocumentsProvider =
    FutureProvider<List<Document>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final repo = ref.watch(repoProvider);
  if (query.isEmpty) return repo.getAllDocuments();
  return repo.searchDocuments(query);
});

// ─────────────────────────────────────────────────────────────
// CARPETAS
// ─────────────────────────────────────────────────────────────
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  return ref.watch(repoProvider).getAllFolders();
});

final folderCountsProvider = FutureProvider<Map<int, int>>((ref) async {
  return ref.watch(repoProvider).countDocumentsByFolder();
});

final unfiledDocumentsProvider =
    FutureProvider<List<Document>>((ref) async {
  return ref.watch(repoProvider).getUnfiledDocuments();
});

// ─────────────────────────────────────────────────────────────
// ORDEN
// ─────────────────────────────────────────────────────────────
enum SortOrder { dateDesc, dateAsc, nameAsc, nameDesc, favorites }

final sortOrderProvider =
    StateProvider<SortOrder>((ref) => SortOrder.dateDesc);

/// Aplica el orden actual a una lista de documentos.
List<Document> applySort(List<Document> docs, SortOrder order) {
  final list = [...docs];
  switch (order) {
    case SortOrder.dateDesc:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SortOrder.dateAsc:
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
    case SortOrder.nameAsc:
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      break;
    case SortOrder.nameDesc:
      list.sort((a, b) =>
          b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      break;
    case SortOrder.favorites:
      list.sort((a, b) {
        if (a.isFavorite == b.isFavorite) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return a.isFavorite ? -1 : 1;
      });
      break;
  }
  return list;
}