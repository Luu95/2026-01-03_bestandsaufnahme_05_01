/// UI-/Service-Helfer für Löschbestätigung und Disziplin-Updates.
/// Kapselt Dialog und Drift-Upsert inkl. Anlagen-Nachzug bei Umbenennung.
import 'package:flutter/material.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/shared/widgets/confirm_delete_dialog.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';

/// Thin-Wrapper: leitet auf [showConfirmDeleteDialog] weiter (Namensbestätigung).
Future<bool> showDeleteConfirmationDialog(
  BuildContext context,
  String itemType,
  String itemName, {
  bool isPermanent = false,
}) {
  return showConfirmDeleteDialog(
    context,
    itemType: itemType,
    itemName: itemName,
    isPermanent: isPermanent,
  );
}

/// Aktualisiert eine Disziplin in der Datenbank (Drift).
/// Gibt true zurück, wenn das Update erfolgreich war.
Future<bool> updateDiscipline(
  BuildContext context,
  DatabaseService dbService,
  Disziplin oldDiscipline,
  Disziplin newDiscipline,
  String buildingId,
) async {
  try {
    // Disziplin in Drift speichern (Upsert)
    await dbService.upsertDiscipline(buildingId, newDiscipline);

    // Wenn Label geändert wurde: alte Disziplin entfernen + Anlagen aktualisieren
    if (oldDiscipline.label.toLowerCase() != newDiscipline.label.toLowerCase()) {
      try {
        await dbService.deleteDiscipline(buildingId, oldDiscipline.label);
      } catch (e) {
        appLog('Alte Disziplin-Key beim Umbenennen nicht gefunden', error: e);
      }
      await dbService.updateAnlagenDiscipline(
        buildingId,
        oldDiscipline.label,
        newDiscipline.label,
        newDiscipline,
      );
      appLog('Anlagen für Disziplin "${oldDiscipline.label}" auf "${newDiscipline.label}" aktualisiert.');
    }

    return true;
  } catch (e) {
    appLog('Fehler beim Aktualisieren der Disziplin', error: e);
    return false;
  }
}
