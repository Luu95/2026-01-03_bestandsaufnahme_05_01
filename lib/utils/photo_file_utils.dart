import 'dart:io';

/// Filtert Foto-Pfade auf existierende Dateien (async, kein existsSync).
Future<List<File>> filterExistingPhotoFiles(Iterable<dynamic> paths) async {
  final files = <File>[];
  for (final p in paths) {
    final file = File(p.toString());
    if (await file.exists()) {
      files.add(file);
    }
  }
  return files;
}
