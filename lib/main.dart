import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/models/document.dart';
import 'data/models/folder.dart';
import 'data/models/page.dart';

late Isar isarInstance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  isarInstance = await Isar.open(
    [DocumentSchema, DocumentPageSchema, FolderSchema], // ← FolderSchema
    directory: dir.path,
  );

  runApp(
    ProviderScope(
      child: const ScanProApp(),
    ),
  );
}