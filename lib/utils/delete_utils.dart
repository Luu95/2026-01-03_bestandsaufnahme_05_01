// lib/utils/delete_utils.dart
import 'package:flutter/material.dart';
import '../models/disziplin_schnittstelle.dart';
import '../database/database_service.dart';

/// Zeigt den Bestätigungsdialog für das Löschen eines Elements an.
Future<bool> showDeleteConfirmationDialog(BuildContext context, String itemType, String itemName) async {
  return await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon - dezent und professionell
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 28,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            // Titel
            Text(
              '$itemType löschen?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Inhalt
            Text(
              'Möchtest du "$itemName" wirklich löschen?',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Dezente Warnung
            Text(
              'Diese Aktion kann nicht rückgängig gemacht werden',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Abbrechen',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Löschen',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ) ?? false;
}

/// Aktualisiert eine Disziplin in SharedPreferences
/// Gibt true zurück, wenn das Update erfolgreich war.
Future<bool> updateDiscipline(
  BuildContext context,
  Disziplin oldDiscipline,
  Disziplin newDiscipline,
  String buildingId,
) async {
  try {
    final dbService = DatabaseService.instance;
    if (dbService == null) return false;

    // Disziplin in Drift speichern (Upsert)
    await dbService.upsertDiscipline(buildingId, newDiscipline);

    // Wenn Label geändert wurde: alte Disziplin entfernen + Anlagen aktualisieren
    if (oldDiscipline.label.toLowerCase() != newDiscipline.label.toLowerCase()) {
      try {
        await dbService.deleteDiscipline(buildingId, oldDiscipline.label);
      } catch (_) {
        // Ignorieren, falls es den alten Key nicht mehr gibt
      }
      await dbService.updateAnlagenDiscipline(
        buildingId,
        oldDiscipline.label,
        newDiscipline.label,
        newDiscipline,
      );
      debugPrint('Anlagen für Disziplin "${oldDiscipline.label}" auf "${newDiscipline.label}" aktualisiert.');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disziplin "${newDiscipline.label}" wurde aktualisiert'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return true;
  } catch (e) {
    debugPrint('Fehler beim Aktualisieren der Disziplin: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Aktualisieren der Disziplin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}
