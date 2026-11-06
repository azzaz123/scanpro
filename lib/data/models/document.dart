import 'package:isar_community/isar.dart';

part 'document.g.dart';

@collection
class Document {
  Id id = Isar.autoIncrement;

  late String name;
  late DateTime createdAt;
  DateTime? updatedAt;
  String? ocrText;
  bool isFavorite = false;

  @Index()
  late int pageCount;

  // SIN @Index() — no es necesario
  late List<int> folderIds;

  Document() {
    folderIds = [];
  }
}