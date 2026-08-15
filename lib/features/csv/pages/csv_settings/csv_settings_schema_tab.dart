// Tab „Eingabefelder“: Schema je Gewerk / Revisionsobjekt bearbeiten.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/schema_editor_dialog.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_schema_helpers.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_widgets.dart';

/// Schema-Auswahl und Editor für CSV-Eingabefelder.
class CsvSettingsSchemaTab extends StatelessWidget {
  final List<Disziplin> disciplines;
  final List<Template> templates;
  final String labelGewerk;
  final String schemaItemLevelLabel;
  final bool showSelection;
  final int? editingDisciplineIndex;
  final String? editingRevisionsobjekt;
  final Set<int> expandedIndices;
  final ValueChanged<Set<int>> onExpandedChanged;
  final void Function(int disciplineIndex, String revisionsobjekt) onEdit;
  final VoidCallback onBackToSelection;
  final ValueChanged<List<Map<String, dynamic>>> onSchemaChanged;

  const CsvSettingsSchemaTab({
    super.key,
    required this.disciplines,
    required this.templates,
    required this.labelGewerk,
    required this.schemaItemLevelLabel,
    required this.showSelection,
    required this.editingDisciplineIndex,
    required this.editingRevisionsobjekt,
    required this.expandedIndices,
    required this.onExpandedChanged,
    required this.onEdit,
    required this.onBackToSelection,
    required this.onSchemaChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSelection &&
        editingDisciplineIndex != null &&
        editingRevisionsobjekt != null) {
      final d = disciplines[editingDisciplineIndex!];
      final ro = editingRevisionsobjekt!;
      return Column(
        children: [
          _BackHeader(
            title: '${d.label} → $schemaItemLevelLabel: $ro',
            onBack: onBackToSelection,
          ),
          Expanded(
            child: SchemaEditorWidget(
              existingSchema: CsvSettingsSchemaHelpers.schemaForRevisionsobjekt(
                d,
                ro,
                templates,
              ),
              onSchemaChanged: onSchemaChanged,
            ),
          ),
        ],
      );
    }

    return _SelectionView(
      disciplines: disciplines,
      templates: templates,
      labelGewerk: labelGewerk,
      schemaItemLevelLabel: schemaItemLevelLabel,
      expandedIndices: expandedIndices,
      onExpandedChanged: onExpandedChanged,
      onEdit: onEdit,
    );
  }
}

class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _BackHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SelectionView extends StatelessWidget {
  final List<Disziplin> disciplines;
  final List<Template> templates;
  final String labelGewerk;
  final String schemaItemLevelLabel;
  final Set<int> expandedIndices;
  final ValueChanged<Set<int>> onExpandedChanged;
  final void Function(int disciplineIndex, String revisionsobjekt) onEdit;

  const _SelectionView({
    required this.disciplines,
    required this.templates,
    required this.labelGewerk,
    required this.schemaItemLevelLabel,
    required this.expandedIndices,
    required this.onExpandedChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final emptyHint =
        'Importieren Sie im Tab „CSV-Import“ Gewerkevorlagen, '
        'damit $labelGewerk und $schemaItemLevelLabel hier erscheinen.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$labelGewerk (Ebene 1)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Nach Import der Gewerkevorlagen: $labelGewerk aufklappen, '
            'darunter $schemaItemLevelLabel (Ebene 2) wählen, um die Attribute zu bearbeiten.',
            style: TextStyle(
              fontSize: 13,
              color: csvSettingsMutedTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          if (disciplines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  emptyHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: csvSettingsMutedTextColor(context),
                  ),
                ),
              ),
            )
          else
            ...List.generate(disciplines.length, (index) {
              final d = disciplines[index];
              final roList =
                  CsvSettingsSchemaHelpers.revisionsobjekteForDiscipline(
                d,
                templates,
              );
              final isExpanded = expandedIndices.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      key: ValueKey('schema_disc_$index'),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        final next = Set<int>.from(expandedIndices);
                        if (expanded) {
                          next.add(index);
                        } else {
                          next.remove(index);
                        }
                        onExpandedChanged(next);
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: d.uiBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(d.icon, color: d.uiColor, size: 22),
                      ),
                      title: Text(
                        d.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        roList.isEmpty
                            ? 'Keine $schemaItemLevelLabel (Ebene 2)'
                            : '${roList.length} $schemaItemLevelLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: csvSettingsMutedTextColor(context),
                        ),
                      ),
                      children: [
                        if (roList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              'Für dieses $labelGewerk sind in den Gewerkevorlagen '
                              'keine $schemaItemLevelLabel-Einträge hinterlegt.',
                              style: TextStyle(
                                fontSize: 13,
                                color: csvSettingsMutedTextColor(context),
                              ),
                            ),
                          )
                        else
                          for (final ro in roList)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: const Icon(
                                Icons.account_tree_outlined,
                                color: AppPalette.primary,
                              ),
                              title: Text(ro),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => onEdit(index, ro),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
