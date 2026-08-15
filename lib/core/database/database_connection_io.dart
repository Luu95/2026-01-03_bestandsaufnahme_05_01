/// Drift-Datenbankverbindung für native Plattformen (IO).
/// Speichert die SQLite-Datei unter Application Documents.
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Erzeugt eine [LazyDatabase] mit [NativeDatabase] auf dem Dateisystem.
LazyDatabase createConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bestandsaufnahme.db'));
    return NativeDatabase(file);
  });
}
