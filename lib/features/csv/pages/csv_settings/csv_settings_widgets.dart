// Wiederkehrende UI-Bausteine der CSV-Einstellungen.
// Mapping- und Schema-Tabs der [CsvSettingsPage] nutzen diese Widgets.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';

/// Gedämpfte Textfarbe für Hinweise in den CSV-Settings.
Color csvSettingsMutedTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

/// Vertikaler Verbinder zwischen Hierarchie-Karten.
class CsvSettingsConnector extends StatelessWidget {
  const CsvSettingsConnector({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Container(
        height: 20,
        width: 2,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// Info-Karte mit Icon und Hinweistext.
class CsvSettingsInfoCard extends StatelessWidget {
  final String text;
  final Color color;

  const CsvSettingsInfoCard(
    this.text, {
    super.key,
    this.color = AppPalette.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: csvSettingsMutedTextColor(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abschnittsüberschrift mit optionalem Trailing-Widget.
class CsvSettingsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const CsvSettingsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: csvSettingsMutedTextColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Karte mit Import- + Vorlage-Download-Button (Gewerke / Anlagen-CSV).
class CsvSettingsActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool imported;
  final VoidCallback onImport;
  final VoidCallback onDownloadTemplate;

  const CsvSettingsActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.imported,
    required this.onImport,
    required this.onDownloadTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: imported
              ? AppPalette.successBorder
              : color.withValues(alpha: 0.3),
          width: imported ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: imported
            ? AppPalette.success.withValues(alpha: 0.04)
            : color.withValues(alpha: 0.03),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: imported ? AppPalette.success : color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (imported) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle,
                          size: 15, color: AppPalette.success),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Importieren'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onDownloadTemplate,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Vorlage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kompakter Header-Button (z. B. Import-Status) in den CSV-Settings.
class CsvSettingsHeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool imported;

  const CsvSettingsHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.imported = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: imported
              ? AppPalette.successBorder
              : color.withValues(alpha: 0.5),
          width: imported ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          if (imported) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, size: 16, color: AppPalette.success),
          ],
        ],
      ),
    );
  }
}
