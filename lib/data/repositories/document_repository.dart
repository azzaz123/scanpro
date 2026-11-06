import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/document.dart';
import '../models/page.dart';
import '../models/folder.dart';

class DocumentRepository {
  final Isar isar;
  DocumentRepository(this.isar);

  // ─────────────────────────────────────────────────────────────
  // CREAR documento con páginas
  // ─────────────────────────────────────────────────────────────
  Future<Document> createDocument({
  required String name,
  required List<String> imagePaths,
}) async {
  debugPrint('📄 createDocument: ${imagePaths.length} imágenes');

  final doc = Document()
    ..name = name
    ..createdAt = DateTime.now()
    ..pageCount = imagePaths.length;

  // Transacción 1: solo el doc
  await isar.writeTxn(() async {
    await isar.documents.put(doc);
    debugPrint('📄 Doc guardado: id=${doc.id}, pageCount=${doc.pageCount}');
  });

  // Transacción 2: solo las páginas
  await isar.writeTxn(() async {
    final pages = <DocumentPage>[];
    for (int i = 0; i < imagePaths.length; i++) {
      pages.add(DocumentPage()
        ..documentId = doc.id
        ..imagePath = imagePaths[i]
        ..order = i
        ..scannedAt = DateTime.now());
    }
    await isar.documentPages.putAll(pages);
    debugPrint('📄 Guardadas ${pages.length} páginas en Isar');
  });

  return doc;
}
  // ─────────────────────────────────────────────────────────────
  // LISTAR todos los documentos
  // ─────────────────────────────────────────────────────────────
  Future<List<Document>> getAllDocuments() {
    return isar.documents.where().sortByCreatedAtDesc().findAll();
  }

  // ─────────────────────────────────────────────────────────────
  // BUSCAR por nombre
  // ─────────────────────────────────────────────────────────────
  Future<List<Document>> searchDocuments(String query) {
    return isar.documents
        .filter()
        .nameContains(query, caseSensitive: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ─────────────────────────────────────────────────────────────
  // OBTENER páginas de un documento
  // ─────────────────────────────────────────────────────────────
 Future<List<DocumentPage>> getPagesForDocument(int docId) async {
  final pages = await isar.documentPages
      .filter()
      .documentIdEqualTo(docId)
      .findAll();
  
  // Ordenar en memoria (más fiable que sortByOrder)
  pages.sort((a, b) => a.order.compareTo(b.order));
  
  return pages;
}

  // ─────────────────────────────────────────────────────────────
  // AÑADIR una página a un documento existente
  // ─────────────────────────────────────────────────────────────
  Future<void> addPageToDocument(
    Document doc,
    String imagePath,
    int order,
  ) async {
    await isar.writeTxn(() async {
      final page = DocumentPage()
        ..documentId = doc.id
        ..imagePath = imagePath
        ..order = order
        ..scannedAt = DateTime.now();
      await isar.documentPages.put(page);

      doc.pageCount = doc.pageCount + 1;
      doc.updatedAt = DateTime.now();
      await isar.documents.put(doc);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // REEMPLAZAR la imagen de una página (rotar/recortar)
  // ─────────────────────────────────────────────────────────────
  Future<void> updatePageImage(DocumentPage page, String newPath) async {
    await isar.writeTxn(() async {
      page.imagePath = newPath;
      await isar.documentPages.put(page);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR una página individual
  // ─────────────────────────────────────────────────────────────
  Future<void> deletePage(DocumentPage page) async {
    await isar.writeTxn(() async {
      await isar.documentPages.delete(page.id);

      final doc = await isar.documents.get(page.documentId);
      if (doc != null) {
        doc.pageCount = doc.pageCount > 0 ? doc.pageCount - 1 : 0;
        doc.updatedAt = DateTime.now();
        await isar.documents.put(doc);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // FAVORITO
  // ─────────────────────────────────────────────────────────────
  Future<void> toggleFavorite(Document doc) async {
    await isar.writeTxn(() async {
      doc.isFavorite = !doc.isFavorite;
      await isar.documents.put(doc);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // OCR
  // ─────────────────────────────────────────────────────────────
  Future<void> updateOcrText(Document doc, String text) async {
    await isar.writeTxn(() async {
      doc.ocrText = text;
      doc.updatedAt = DateTime.now();
      await isar.documents.put(doc);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // RENOMBRAR
  // ─────────────────────────────────────────────────────────────
  Future<void> renameDocument(Document doc, String newName) async {
    await isar.writeTxn(() async {
      doc.name = newName;
      doc.updatedAt = DateTime.now();
      await isar.documents.put(doc);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR documento COMPLETO (y sus páginas)
  // ─────────────────────────────────────────────────────────────
 Future<void> deleteDocument(Document doc) async {
  await isar.writeTxn(() async {
    // 1. Buscar todas las páginas
    final pages = await isar.documentPages
        .filter()
        .documentIdEqualTo(doc.id)
        .findAll();

    // 2. Borrarlas
    if (pages.isNotEmpty) {
      await isar.documentPages.deleteAll(pages.map((p) => p.id).toList());
    }

    // 3. Borrar el documento
    await isar.documents.delete(doc.id);
  });
}
    // ═══════════════════════════════════════════════════════════
  // CARPETAS
  // ═══════════════════════════════════════════════════════════

  Future<Folder> createFolder({
    required String name,
    String? colorHex,
    String? iconName,
  }) async {
    // Verificar nombre único
    final existing =
        await isar.folders.filter().nameEqualTo(name).findFirst();
    if (existing != null) {
      throw Exception('Ya existe una carpeta con ese nombre');
    }

    final folder = Folder()
      ..name = name
      ..createdAt = DateTime.now()
      ..colorHex = colorHex ?? '#1E6FFF'
      ..iconName = iconName ?? 'folder';

    await isar.writeTxn(() async {
      await isar.folders.put(folder);
    });
    return folder;
  }

  Future<List<Folder>> getAllFolders() {
    return isar.folders.where().sortByName().findAll();
  }

  Stream<List<Folder>> watchFolders() {
    return isar.folders.where().sortByName().watch(fireImmediately: true);
  }

  Future<void> renameFolder(Folder folder, String newName) async {
    final existing =
        await isar.folders.filter().nameEqualTo(newName).findFirst();
    if (existing != null && existing.id != folder.id) {
      throw Exception('Ya existe otra carpeta con ese nombre');
    }
    await isar.writeTxn(() async {
      folder.name = newName;
      folder.updatedAt = DateTime.now();
      await isar.folders.put(folder);
    });
  }

  Future<void> updateFolderColor(Folder folder, String colorHex) async {
    await isar.writeTxn(() async {
      folder.colorHex = colorHex;
      folder.updatedAt = DateTime.now();
      await isar.folders.put(folder);
    });
  }

  /// Elimina la carpeta. Los documentos NO se borran,
  /// solo se les quita la referencia a esta carpeta.
  Future<void> deleteFolder(Folder folder) async {
    await isar.writeTxn(() async {
      final docs = await isar.documents
          .filter()
          .folderIdsElementEqualTo(folder.id)
          .findAll();

      for (final doc in docs) {
        doc.folderIds =
            doc.folderIds.where((id) => id != folder.id).toList();
        await isar.documents.put(doc);
      }

      await isar.folders.delete(folder.id);
    });
  }

  /// Añade un documento a una carpeta (sin duplicados).
  Future<void> addDocumentToFolder(int docId, int folderId) async {
  await isar.writeTxn(() async {
    final doc = await isar.documents.get(docId);
    if (doc == null) return;
    if (doc.folderIds.contains(folderId)) return;

    doc.folderIds = [...doc.folderIds, folderId];
    doc.updatedAt = DateTime.now();
    await isar.documents.put(doc);
  });
}

  /// Quita un documento de una carpeta.
  Future<void> removeDocumentFromFolder(Document doc, int folderId) async {
    await isar.writeTxn(() async {
      doc.folderIds =
          doc.folderIds.where((id) => id != folderId).toList();
      doc.updatedAt = DateTime.now();
      await isar.documents.put(doc);
    });
  }

  /// Documentos de una carpeta concreta.
  Future<List<Document>> getDocumentsInFolder(int folderId) {
    return isar.documents
        .filter()
        .folderIdsElementEqualTo(folderId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<Document>> watchDocumentsInFolder(int folderId) {
    return isar.documents
        .filter()
        .folderIdsElementEqualTo(folderId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// Documentos SIN carpeta (los que no están en ninguna).
  Future<List<Document>> getUnfiledDocuments() {
    return isar.documents
        .filter()
        .folderIdsIsEmpty()
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Contar documentos por carpeta (para mostrar badge).
  Future<Map<int, int>> countDocumentsByFolder() async {
    final docs = await isar.documents.where().findAll();
    final counts = <int, int>{};
    for (final doc in docs) {
      for (final folderId in doc.folderIds) {
        counts[folderId] = (counts[folderId] ?? 0) + 1;
      }
    }
    return counts;
  }
}