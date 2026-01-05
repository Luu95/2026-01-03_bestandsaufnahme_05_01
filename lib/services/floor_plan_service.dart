// lib/services/floor_plan_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/floor_plan.dart';
import '../models/building.dart';

class FloorPlanService {
  static Future<void> deleteFloor({
    required String buildingId,
    required String floorId,
    required List<FloorPlan> floorList,
    required int indexInList,
  }) async {
    // Hier erfolgt die Logik, um den Grundriss zu löschen, z.B. aus dem Dateisystem
    final floorPlan = floorList[indexInList];
    final filePath = floorPlan.pdfPath;

    if (filePath != null) {
      // Lösche die Datei, falls sie existiert
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Entferne das Element aus der Liste
    floorList.removeAt(indexInList);

    // Hier kannst du auch Daten wie SharedPreferences oder eine Datenbank anpassen
    // Beispiel: Speichern der Änderungen in SharedPreferences oder einer Datenbank.
  }
}
