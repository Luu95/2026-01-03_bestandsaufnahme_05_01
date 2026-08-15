// Tab „CSV-Import“: Vorlagen/Anlagen-Import, Hierarchie, Attribute, Export-Spalten.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/shared/widgets/settings_card.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_draft_ops.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_form_controllers.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_ui.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_widgets.dart';

/// Mapping- und Import-Oberfläche der CSV-Einstellungen.
class CsvSettingsMappingTab extends StatelessWidget {
  final CsvSettings draft;
  final CsvSettingsFormControllers controllers;
  final int templateCount;
  final bool hasAnlagenCsvImported;
  final ValueChanged<CsvSettings> onDraftChanged;
  final VoidCallback onScheduleSave;
  final VoidCallback onImportTemplates;
  final VoidCallback onImportAnlagen;
  final VoidCallback onDownloadGewerkeTemplate;
  final VoidCallback onDownloadAnlagenTemplate;
  final VoidCallback onDeleteTemplates;
  final VoidCallback onDeleteAll;
  final void Function(String message) onShowError;
  final void Function(String message) onShowInfo;

  const CsvSettingsMappingTab({
    super.key,
    required this.draft,
    required this.controllers,
    required this.templateCount,
    required this.hasAnlagenCsvImported,
    required this.onDraftChanged,
    required this.onScheduleSave,
    required this.onImportTemplates,
    required this.onImportAnlagen,
    required this.onDownloadGewerkeTemplate,
    required this.onDownloadAnlagenTemplate,
    required this.onDeleteTemplates,
    required this.onDeleteAll,
    required this.onShowError,
    required this.onShowInfo,
  });

  List<String>? get _headers =>
      draft.importHeaderRow.isEmpty ? null : draft.importHeaderRow;

  void _update(CsvSettings next) {
    onDraftChanged(CsvSettingsDraftOps.withGroupingKeysFromHeaders(next));
    onScheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CsvSettingsInfoCard(
            'Laden Sie eine Vorlage herunter, befüllen Sie sie und importieren Sie die Datei. '
            'Attribute: Erste und letzte Spalte angeben (Dreiergruppen werden automatisch berechnet) '
            'oder aus ATT…-Headern erkennen.',
          ),
          const SizedBox(height: 12),
          CsvSettingsActionCard(
            title: 'Gewerkevorlagen',
            subtitle: templateCount > 0
                ? '$templateCount Vorlagen importiert'
                : 'Noch keine Vorlagen importiert',
            color: AppPalette.warning,
            icon: Icons.category_outlined,
            imported: templateCount > 0,
            onImport: onImportTemplates,
            onDownloadTemplate: onDownloadGewerkeTemplate,
          ),
          const SizedBox(height: 8),
          CsvSettingsActionCard(
            title: 'Anlagen-CSV',
            subtitle: hasAnlagenCsvImported
                ? 'CSV-Format wurde eingelesen'
                : 'Noch keine Anlagen importiert',
            color: AppPalette.success,
            icon: Icons.list_alt_outlined,
            imported: hasAnlagenCsvImported,
            onImport: onImportAnlagen,
            onDownloadTemplate: onDownloadAnlagenTemplate,
          ),
          const SizedBox(height: 20),
          CsvSettingsSectionHeader(
            title: 'Hierarchie-Ebenen',
            subtitle: CsvSettingsDraftOps.hierarchySubtitle(draft),
          ),
          const SizedBox(height: 12),
          _HierarchyCard(
            levelNum: 1,
            label: draft.labelGewerk,
            color: AppPalette.primaryDark,
            config: draft.level1,
            draft: draft,
            headers: _headers,
            onChanged: (c) => _update(draft.copyWith(level1: c)),
          ),
          const CsvSettingsConnector(),
          _HierarchyCard(
            levelNum: 2,
            label: draft.labelAnlage,
            color: AppPalette.primary,
            config: draft.level2,
            draft: draft,
            headers: _headers,
            onChanged: (c) => _update(draft.copyWith(level2: c)),
          ),
          const CsvSettingsConnector(),
          _HierarchyCard(
            levelNum: 3,
            label: draft.labelBauteil,
            color: AppPalette.primaryLight,
            config: draft.level3,
            draft: draft,
            headers: _headers,
            isLeafLevel: true,
            onChanged: (c) => _update(draft.copyWith(level3: c)),
          ),
          const SizedBox(height: 16),
          _AttributeRangeSection(
            draft: draft,
            controllers: controllers,
            onApply: (first, last) {
              try {
                _update(
                  CsvSettingsDraftOps.applyManualAttributeRange(
                    draft,
                    firstColumn1Based: first,
                    lastColumn1Based: last,
                  ),
                );
                onShowInfo(
                  '${((last - first + 1) ~/ 3)} Attribute (Spalten $first–$last) übernommen',
                );
              } catch (e) {
                onShowError(e.toString());
              }
            },
            onTrySilent: (first, last) {
              try {
                _update(
                  CsvSettingsDraftOps.applyManualAttributeRange(
                    draft,
                    firstColumn1Based: first,
                    lastColumn1Based: last,
                  ),
                );
              } catch (_) {
                // Beim Tippen still ignorieren, bis der Bereich gültig ist.
              }
            },
            onClear: () => _update(
              CsvSettingsDraftOps.clearManualAttributeRange(draft),
            ),
            onShowError: onShowError,
          ),
          const SizedBox(height: 12),
          _ExportLabelSection(
            title: 'QR-Code-Nummer (Export)',
            icon: Icons.qr_code_2,
            subtitle: (draft.qrCodeNummerSpalteLabel?.trim().isNotEmpty ?? false)
                ? 'Spalte „${draft.qrCodeNummerSpalteLabel!.trim()}“ konfiguriert'
                : 'Keine Spalte – zum Konfigurieren aufklappen',
            hint:
                'Spalten-Label Ihrer CSV, in das beim Export die QR-Code-Nummer geschrieben wird. '
                'Leer lassen = Spalte nicht verwenden.',
            fields: [
              (
                'QR-Code-Nummer Spalte',
                controllers.qrCode,
                (v) => _update(
                      draft.copyWith(
                        qrCodeNummerSpalteLabel: v.isEmpty ? null : v,
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ExportLabelSection(
            title: 'Fotonummern-Spalten (Export)',
            icon: Icons.photo_library,
            subtitle: () {
              final n = [
                draft.foto1SpalteLabel,
                draft.foto2SpalteLabel,
                draft.foto3SpalteLabel,
                draft.foto4SpalteLabel,
              ].where((l) => (l?.trim().isNotEmpty ?? false)).length;
              return n == 0
                  ? 'Keine Spalten – zum Konfigurieren aufklappen'
                  : '$n Spalte${n == 1 ? '' : 'n'} konfiguriert';
            }(),
            hint:
                'Spalten-Labels Ihrer CSV, in die beim Export die Fotonummern (1–4) geschrieben werden. '
                'Beim Import können diese Spalten leer sein. Leer lassen = Spalte nicht verwenden.',
            fields: [
              (
                'Fotonummer 1',
                controllers.foto1,
                (v) => _update(
                      draft.copyWith(foto1SpalteLabel: v.isEmpty ? null : v),
                    ),
              ),
              (
                'Fotonummer 2',
                controllers.foto2,
                (v) => _update(
                      draft.copyWith(foto2SpalteLabel: v.isEmpty ? null : v),
                    ),
              ),
              (
                'Fotonummer 3',
                controllers.foto3,
                (v) => _update(
                      draft.copyWith(foto3SpalteLabel: v.isEmpty ? null : v),
                    ),
              ),
              (
                'Fotonummer 4',
                controllers.foto4,
                (v) => _update(
                      draft.copyWith(foto4SpalteLabel: v.isEmpty ? null : v),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Begriffe der Ebenen anpassen'),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              TextField(
                controller: controllers.labelGewerk,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 1',
                  helperText: 'Standard: Gewerk',
                ),
                onChanged: (val) => _update(draft.copyWith(labelGewerk: val)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers.labelAnlage,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 2',
                  helperText: 'Standard: Anlage',
                ),
                onChanged: (val) => _update(draft.copyWith(labelAnlage: val)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers.labelBauteil,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 3',
                  helperText: 'Standard: Bauteil',
                ),
                onChanged: (val) => _update(draft.copyWith(labelBauteil: val)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Anlagenliste – angezeigte Eingabefelder'),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              TextField(
                controller: controllers.listTitleFieldIndex,
                keyboardType: TextInputType.number,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: 'Titel = Eingabefeld Nr.',
                  helperText:
                      'Nummer des Eingabefelds im Anlagendialog (1 = erstes Feld). '
                      'Leer → „Unbekannte Anlage“.',
                ),
                onChanged: (val) {
                  final n = int.tryParse(val.trim()) ?? 1;
                  _update(
                    draft.copyWith(listTitleInputFieldIndex: n < 1 ? 1 : n),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers.listSubtitleFieldIndex,
                keyboardType: TextInputType.number,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: 'Untertitel = Eingabefeld Nr.',
                  helperText: 'Zweite Zeile in der Liste. 0 = kein Untertitel.',
                ),
                onChanged: (val) {
                  final n = int.tryParse(val.trim()) ?? 0;
                  _update(
                    draft.copyWith(
                      listSubtitleInputFieldIndex: n < 0 ? 0 : n,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          CsvSettingsColumnConflictBanner(
            conflicts: CsvSettingsDraftOps.columnConflictMessages(draft),
          ),
          const SizedBox(height: 24),
          CsvSettingsDangerCard(
            title: 'Alle Vorlagen löschen',
            description:
                'Löscht alle importierten Gewerkevorlagen für dieses Projekt. '
                'Gewerke und Anlagen im Gebäude bleiben erhalten.',
            buttonText: 'Vorlagen löschen',
            onPressed: onDeleteTemplates,
          ),
          const SizedBox(height: 16),
          CsvSettingsDangerCard(
            title: 'Alle Daten löschen',
            description:
                'Löscht alle Gewerke, Anlagen und Grundrisse (Ebenen) für dieses Gebäude. Diese Aktion kann nicht rückgängig gemacht werden.',
            buttonText: 'Alle löschen',
            onPressed: onDeleteAll,
          ),
        ],
      ),
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  final int levelNum;
  final String label;
  final Color color;
  final HierarchyLevelConfig config;
  final CsvSettings draft;
  final List<String>? headers;
  final ValueChanged<HierarchyLevelConfig> onChanged;
  final bool isLeafLevel;

  const _HierarchyCard({
    required this.levelNum,
    required this.label,
    required this.color,
    required this.config,
    required this.draft,
    required this.headers,
    required this.onChanged,
    this.isLeafLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    final canDisable =
        CsvSettingsDraftOps.countEnabledLevels(draft) > 1 || !config.enabled;

    return SettingsCard(
      color: color,
      borderColor: color.withValues(alpha: 0.35),
      icon: isLeafLevel ? Icons.device_hub : Icons.folder_open,
      iconColor: color,
      title: 'Ebene $levelNum: $label${isLeafLevel ? ' (Blatt)' : ''}',
      description: isLeafLevel
          ? 'Pro CSV-Zeile wird ein Datensatz auf dieser Ebene angelegt.'
          : levelNum == 1
              ? 'Gruppierknoten und Gewerk/Disziplin in der App (wenn aktiv).'
              : 'Gruppierknoten – gleiche Werte werden zusammengefasst.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CsvSettingsToggleRow(
            icon: Icons.power_settings_new,
            label: 'Ebene aktiv',
            isActive: config.enabled,
            onToggle: (val) {
              if (!val && !canDisable) return;
              var updated = config.copyWith(enabled: val);
              if (val) {
                updated = updated.copyWith(
                  nameColumn: CsvSettingsDraftOps.pickFreeMappingColumn(
                    draft,
                    updated.nameColumn,
                    excludeLevelNum: levelNum,
                  ),
                );
              }
              onChanged(updated);
            },
          ),
          if (config.enabled) ...[
            const SizedBox(height: 12),
            CsvSettingsColumnSelector(
              label: 'Name-Spalte',
              value: config.nameColumn,
              csvHeaders: headers,
              onChanged: (v) {
                var updated = config.copyWith(nameColumn: v);
                if (updated.useIdColumn &&
                    updated.idColumn != null &&
                    updated.idColumn == v) {
                  updated = updated.copyWith(
                    idColumn: CsvSettingsDraftOps.nextFreeIndex([
                      ...CsvSettingsDraftOps.mappingColumnIndices(
                        draft,
                        excludeLevelNum: levelNum,
                      ),
                      v,
                    ]),
                  );
                }
                onChanged(updated);
              },
            ),
            const SizedBox(height: 12),
            CsvSettingsToggleRow(
              icon: Icons.tag,
              label: 'ID-Spalte verwenden?',
              isActive: config.useIdColumn,
              onToggle: (val) {
                onChanged(
                  config.copyWith(
                    useIdColumn: val,
                    idColumn: val
                        ? CsvSettingsDraftOps.nextFreeIndex([
                            ...CsvSettingsDraftOps.mappingColumnIndices(
                              draft,
                              excludeLevelNum: levelNum,
                            ),
                            config.nameColumn,
                          ])
                        : null,
                    clearIdColumn: !val,
                  ),
                );
              },
              child: config.useIdColumn
                  ? CsvSettingsColumnSelector(
                      label: 'ID-Spalte (lfd Nr.)',
                      value: config.idColumn ??
                          CsvSettingsDraftOps.nextFreeIndex([
                            ...CsvSettingsDraftOps.mappingColumnIndices(
                              draft,
                              excludeLevelNum: levelNum,
                            ),
                            config.nameColumn,
                          ]),
                      csvHeaders: headers,
                      onChanged: (v) => onChanged(
                        config.copyWith(useIdColumn: true, idColumn: v),
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttributeRangeSection extends StatelessWidget {
  final CsvSettings draft;
  final CsvSettingsFormControllers controllers;
  final void Function(int first, int last) onApply;
  final void Function(int first, int last) onTrySilent;
  final VoidCallback onClear;
  final void Function(String message) onShowError;

  const _AttributeRangeSection({
    required this.draft,
    required this.controllers,
    required this.onApply,
    required this.onTrySilent,
    required this.onClear,
    required this.onShowError,
  });

  void _parseAndRun(void Function(int, int) run, {required bool silent}) {
    final start = int.tryParse(controllers.attrRangeStart.text.trim());
    final end = int.tryParse(controllers.attrRangeEnd.text.trim());
    if (start == null || end == null || start < 1 || end < start) {
      if (!silent) {
        onShowError('Bitte Erste und Letzte Spalte angeben (Erste ≤ Letzte).');
      }
      return;
    }
    final columnCount = end - start + 1;
    if (columnCount % 3 != 0) {
      if (!silent) {
        onShowError(
          'Anzahl Spalten ($columnCount) muss durch 3 teilbar sein.',
        );
      }
      return;
    }
    run(start, end);
  }

  @override
  Widget build(BuildContext context) {
    const color = AppPalette.primary;
    final manual = draft.hasManualAttributeRange;
    final subtitle = manual
        ? '${draft.attributeCount} Attribute (Spalte ${draft.attributeStartColumn! + 1}–${draft.attributeStartColumn! + draft.attributeCount! * 3})'
        : 'Erste und letzte Spalte eingeben – zum Konfigurieren aufklappen';

    return Container(
      decoration: csvSettingsSurfaceCardDecoration(
        context,
        borderColor: AppPalette.borderMuted,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: manual,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_column, color: color, size: 24),
          ),
          title: const Text(
            'Attribut-Spalten (3er-Gruppen)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: csvSettingsMutedTextColor(context),
            ),
          ),
          children: [
            Text(
              'Nur erste und letzte Spalte angeben. '
              'Im Hintergrund entstehen automatisch Dreiergruppen (Name, Typ, Wert/Art). '
              'Ohne Angabe: automatische Erkennung aus ATT…-Headern.',
              style: TextStyle(
                fontSize: 12,
                color: csvSettingsMutedTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: controllers.attrRangeStart,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Erste Spalte',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) =>
                        _parseAndRun(onTrySilent, silent: true),
                    onSubmitted: (_) => _parseAndRun(onApply, silent: false),
                  ),
                ),
                const Text('…'),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: controllers.attrRangeEnd,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Letzte Spalte',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) =>
                        _parseAndRun(onTrySilent, silent: true),
                    onSubmitted: (_) => _parseAndRun(onApply, silent: false),
                  ),
                ),
                FilledButton(
                  onPressed: () => _parseAndRun(onApply, silent: false),
                  child: const Text('Übernehmen'),
                ),
                if (manual)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Zurücksetzen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportLabelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final String hint;
  final List<(String label, TextEditingController ctrl, ValueChanged<String> onChanged)>
      fields;

  const _ExportLabelSection({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.hint,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppPalette.primary;
    return Container(
      decoration: csvSettingsSurfaceCardDecoration(
        context,
        borderColor: AppPalette.borderMuted,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: csvSettingsMutedTextColor(context),
            ),
          ),
          children: [
            Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: csvSettingsMutedTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              TextField(
                controller: fields[i].$2,
                decoration: csvSettingsInputDecoration(
                  context,
                  labelText: fields[i].$1,
                  hintText: 'z.B. Foto1 oder Spaltenname aus Ihrer CSV',
                ),
                onChanged: fields[i].$3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
