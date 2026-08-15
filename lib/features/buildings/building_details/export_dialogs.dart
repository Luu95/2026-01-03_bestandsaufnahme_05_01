/// Dialoge für CSV-/ZIP-Export (Export-Typ und Speicherort).
///
/// Ausgelagert aus der Gebäude-Seite, damit diese schlanker bleibt.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/csv/services/csv_service.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';

/// Fragt: nur CSV oder ZIP mit Fotos?
Future<String?> showExportTypeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export-Typ wählen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.table_chart, color: AppPalette.primary),
            title: const Text('Nur CSV exportieren'),
            subtitle: const Text('Exportiert nur die CSV-Datei ohne Fotos'),
            onTap: () => Navigator.of(context).pop('csv'),
          ),
          ListTile(
            leading: const Icon(Icons.archive, color: AppPalette.primary),
            title: const Text('ZIP mit Fotos exportieren'),
            subtitle: const Text('Exportiert CSV + Fotos in ZIP-Archiv'),
            onTap: () => Navigator.of(context).pop('zip'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}

/// Fragt: Teilen oder auf Gerät speichern?
Future<ExportDestination?> showExportDestinationDialog(BuildContext context) {
  return showDialog<ExportDestination>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Speicherort wählen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share, color: AppPalette.primary),
            title: const Text('Teilen'),
            subtitle: const Text('Per E-Mail, Messenger etc. versenden'),
            onTap: () => Navigator.of(context).pop(ExportDestination.share),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt, color: AppPalette.primary),
            title: const Text('Auf Gerät speichern'),
            subtitle: const Text('In Dateien oder Downloads ablegen'),
            onTap: () =>
                Navigator.of(context).pop(ExportDestination.saveToDevice),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}
