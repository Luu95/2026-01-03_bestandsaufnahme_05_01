/// Löscht Grundriss-PDFs im Dateisystem und entfernt den Listeneintrag.
/// Persistenz der FloorPlan-Metadaten übernimmt [DatabaseService], nicht dieser Service.

import 'dart:io';

import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';

/// Dateisystem-Hilfen für Etagen-/Grundriss-PDFs.
class FloorPlanService {
  /// Löscht die PDF-Datei (falls vorhanden) und entfernt den Eintrag aus [floorList].
  static Future<void> deleteFloor({
    required String floorId,
    required List<FloorPlan> floorList,
    required int indexInList,
  }) async {
    final floorPlan = floorList[indexInList];
    final filePath = floorPlan.pdfPath;

    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    floorList.removeAt(indexInList);
  }
}
