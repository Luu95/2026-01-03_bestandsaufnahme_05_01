// Gemeinsame Dekorationen / Danger-Zone / Spaltenwähler für CSV-Settings.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_widgets.dart';

/// Surface-Karte mit Rahmen (ExpansionTiles in den Settings).
BoxDecoration csvSettingsSurfaceCardDecoration(
  BuildContext context, {
  required Color borderColor,
}) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.25 : 0.03,
        ),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

InputDecoration csvSettingsInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Lösch-Hinweiskarte mit Button.
class CsvSettingsDangerCard extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const CsvSettingsDangerCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.errorSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppPalette.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppPalette.error),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(buttonText, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.error,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                side: const BorderSide(color: AppPalette.errorBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spalten-Konflikt-Warnung.
class CsvSettingsColumnConflictBanner extends StatelessWidget {
  final List<String> conflicts;

  const CsvSettingsColumnConflictBanner({super.key, required this.conflicts});

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.errorSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppPalette.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spalten-Konflikt:',
                  style: TextStyle(
                    color: AppPalette.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...conflicts.map(
                  (m) => Text(
                    m,
                    style: const TextStyle(
                      color: AppPalette.primaryDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spaltenwahl: Dropdown bei Header, sonst Zahlenfeld.
class CsvSettingsColumnSelector extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final List<String>? csvHeaders;

  const CsvSettingsColumnSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.csvHeaders,
  });

  @override
  Widget build(BuildContext context) {
    final headers = csvHeaders;
    if (headers != null && headers.isNotEmpty) {
      final safeValue =
          (value >= 0 && value < headers.length) ? value : 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: csvSettingsMutedTextColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            decoration: csvSettingsInputDecoration(context).copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: List.generate(headers.length, (index) {
              return DropdownMenuItem(
                value: index,
                child: Text(
                  '${index + 1}: ${headers[index]}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      );
    }

    return TextFormField(
      key: ValueKey('mapping_col_input_$label'),
      initialValue: (value + 1).toString(),
      keyboardType: TextInputType.number,
      decoration: csvSettingsInputDecoration(
        context,
        labelText: label,
        prefixIcon: const Icon(Icons.view_column, size: 18),
      ),
      onChanged: (text) {
        final userInput = int.tryParse(text.trim());
        if (userInput != null && userInput > 0) {
          onChanged(userInput - 1);
        }
      },
      onFieldSubmitted: (text) {
        final userInput = int.tryParse(text.trim());
        if (userInput != null && userInput > 0) {
          onChanged(userInput - 1);
        }
      },
    );
  }
}

/// Toggle-Zeile mit optionalem Child bei aktivem Switch.
class CsvSettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  final Widget? child;

  const CsvSettingsToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Switch.adaptive(value: isActive, onChanged: onToggle),
            ],
          ),
        ),
        if (isActive && child != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: child),
      ],
    );
  }
}
