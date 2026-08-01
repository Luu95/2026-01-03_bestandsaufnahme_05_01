import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filtert Foto-Pfade auf existierende Dateien (async, kein existsSync).
Future<List<File>> filterExistingPhotoFiles(Iterable<dynamic> paths) async {
  final files = <File>[];
  for (final raw in paths) {
    final file = File(raw.toString());
    if (await file.exists()) {
      files.add(file);
    }
  }
  return files;
}

/// Kopiert eine per ImagePicker (Kamera/Galerie) gewählte Datei dauerhaft
/// in Application Documents – analog zu OCR-/QR-Kameras.
///
/// ImagePicker-Cache-Pfade können vom OS gelöscht werden; nur der neue Pfad
/// sollte in `photoPaths` persistiert werden.
Future<File> persistPickedImageToDocuments(
  String sourcePath, {
  String prefix = 'photo',
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final ext = p.extension(sourcePath);
  final safeExt = ext.isEmpty ? '.jpg' : ext;
  final fileName = '${prefix}_$timestamp$safeExt';
  final filePath = p.join(directory.path, fileName);
  return File(sourcePath).copy(filePath);
}
