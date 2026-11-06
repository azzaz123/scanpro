import 'package:isar_community/isar.dart';

part 'folder.g.dart';

@collection
class Folder {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late DateTime createdAt;
  DateTime? updatedAt;

  // Color de la carpeta (hex string, ej: "#FF5722")
  String? colorHex;

  // Icono (nombre del Material Icon, ej: "work", "home")
  String? iconName;

  // Orden manual (para drag & drop futuro)
  int sortOrder = 0;
}