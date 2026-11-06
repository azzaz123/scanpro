import 'package:isar_community/isar.dart';

part 'page.g.dart';

@collection
class DocumentPage {
  Id id = Isar.autoIncrement;

  @Index()                    // ← IMPORTANTE
  late int documentId;

  late String imagePath;
  late int order;
  DateTime? scannedAt;
}