// CSV-Einstellungen: Hierarchie-Mapping, Schema und Import-Aktionen.
// UI-Bausteine und Draft-Logik liegen unter `csv_settings/`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/features/csv/services/anlagen_csv_import_service.dart';
import 'package:bestandsaufnahme_01/features/csv/services/csv_service.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_draft_ops.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_form_controllers.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_mapping_tab.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_prefs_cleanup.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_schema_helpers.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings/csv_settings_schema_tab.dart';

/// Seite zum Konfigurieren von CSV-Import/Export pro Projekt.
class CsvSettingsPage extends ConsumerStatefulWidget {
  final String projectId;
  final String buildingId;

  const CsvSettingsPage({
    super.key,
    required this.projectId,
    required this.buildingId,
  });

  @override
  ConsumerState<CsvSettingsPage> createState() => _CsvSettingsPageState();
}

class _CsvSettingsPageState extends ConsumerState<CsvSettingsPage> {
  /// Einziger Settings-Draft (Single Source of Truth für den Mapping-Tab).
  CsvSettings _draft = CsvSettings.defaults();
  final _controllers = CsvSettingsFormControllers();

  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _autoSaveTimer;

  List<Disziplin> _disciplines = [];
  List<Template> _projectTemplates = [];
  bool _hasAnlagenCsvImported = false;

  bool _showDisciplineSelection = true;
  int? _editingDisciplineIndex;
  String? _editingRevisionsobjekt;
  final Set<int> _expandedSchemaDisciplineIndices = {};

  @override
  void initState() {
    super.initState();
    _controllers.init(_draft);
    _loadAllData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _leavePage() async {
    _autoSaveTimer?.cancel();
    if (mounted) await _saveAllSettings();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCsvSettings(),
      _loadDisciplines(),
      _loadProjectTemplates(),
    ]);
    await _loadImportStatus();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCsvSettings() async {
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      await notifier.load();
      final loaded = ref.read(csvSettingsProvider(widget.projectId));
      final draft = CsvSettingsDraftOps.normalizeAfterLoad(loaded);
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _controllers.syncFrom(draft);
      });
    } catch (e) {
      appLog('Fehler beim Laden der CSV-Einstellungen: $e');
    }
  }

  Future<void> _loadDisciplines() async {
    try {
      final loaded = await CsvSettingsSchemaHelpers.loadDisciplinesForSchemaEditor(
        dbService: ref.read(databaseServiceProvider),
        buildingId: widget.buildingId,
        projectId: widget.projectId,
      );
      if (mounted) setState(() => _disciplines = loaded);
    } catch (e) {
      appLog('Fehler beim Laden der Disziplinen: $e');
    }
  }

  Future<void> _loadProjectTemplates() async {
    try {
      final templates = await TemplateService.loadTemplatesFromDatabase(
        ref.read(databaseServiceProvider),
        widget.projectId,
      );
      if (mounted) setState(() => _projectTemplates = templates);
    } catch (e) {
      appLog('Fehler beim Laden der Vorlagen: $e');
    }
  }

  Future<void> _loadImportStatus() async {
    try {
      final hasAnlagen =
          await AnlagenCsvImportService.hasBuildingAnlagenCsvImport(
        ref.read(databaseServiceProvider),
        widget.buildingId,
      );
      if (mounted) setState(() => _hasAnlagenCsvImported = hasAnlagen);
    } catch (e) {
      appLog('Fehler beim Laden des Import-Status: $e');
    }
  }

  Future<void> _saveCsvSettings() async {
    if (!mounted) return;
    try {
      final toSave = CsvSettingsDraftOps.prepareForSave(_draft);
      await ref
          .read(csvSettingsProvider(widget.projectId).notifier)
          .save(toSave);
      _draft = toSave;
    } catch (e) {
      appLog('Fehler beim Speichern der CSV-Einstellungen: $e');
    }
  }

  Future<void> _saveDisciplines() async {
    if (!mounted) return;
    String? forceLabel;
    if (_editingDisciplineIndex != null &&
        _editingDisciplineIndex! >= 0 &&
        _editingDisciplineIndex! < _disciplines.length) {
      forceLabel = _disciplines[_editingDisciplineIndex!].label;
    }
    await CsvSettingsSchemaHelpers.savePersistedDisciplines(
      dbService: ref.read(databaseServiceProvider),
      buildingId: widget.buildingId,
      disciplines: _disciplines,
      forceMaterializeLabel: forceLabel,
    );
  }

  Future<void> _saveAllSettings() async {
    if (!mounted || _isSaving) return;
    _isSaving = true;
    setState(() {});
    try {
      await Future.wait([_saveCsvSettings(), _saveDisciplines()]);
    } catch (e) {
      appLog('Fehler beim automatischen Speichern: $e');
    } finally {
      if (mounted) {
        _isSaving = false;
        setState(() {});
      }
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _saveAllSettings();
    });
  }

  void _snack(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  Future<bool> _confirmDanger({
    required String title,
    required String body,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppPalette.error),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _withBlockingProgress(Future<void> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      rethrow;
    }
  }

  Future<void> _importTemplates() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: AppPalette.warning),
            SizedBox(width: 8),
            Text('Vorlagen importieren'),
          ],
        ),
        content: const Text(
          'Möchten Sie wirklich alle bestehenden Vorlagen für dieses Projekt ersetzen? '
          'Dies kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _withBlockingProgress(() async {
        await TemplateService.importTemplatesFromCsv(
          ref.read(databaseServiceProvider),
          widget.projectId,
          null,
          buildingId: widget.buildingId,
        );
      });
      if (!mounted) return;
      await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
      await _loadCsvSettings();
      await _loadProjectTemplates();
      await _loadDisciplines();
      await _loadImportStatus();
      _snack('Gewerkevorlagen importiert');
    } catch (e) {
      appLog('Vorlagen-Import fehlgeschlagen', error: e);
      _snack('Vorlagen-Import fehlgeschlagen: $e');
    }
  }

  Future<void> _importAnlagenCsv() async {
    try {
      late final AnlagenCsvPersistResult result;
      await _withBlockingProgress(() async {
        await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
        final csvSettings = ref.read(csvSettingsProvider(widget.projectId));
        result = await AnlagenCsvImportService.runFullImport(
          dbService: ref.read(databaseServiceProvider),
          projectId: widget.projectId,
          buildingId: widget.buildingId,
          csvSettings: csvSettings,
          saveSettings: (updated) => ref
              .read(csvSettingsProvider(widget.projectId).notifier)
              .save(updated),
        );
        if (!mounted) return;
        await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
        await _loadCsvSettings();
        await _loadDisciplines();
        await _loadImportStatus();
      });
      _snack(
        'Anlagen-CSV: ${result.savedCount} neu, ${result.skippedCount} übersprungen',
      );
    } catch (e) {
      _snack('Anlagen-Import fehlgeschlagen: $e');
    }
  }

  Future<void> _downloadAnlagenTemplate() async {
    try {
      final built = await CsvService.buildAnlagenCsvTemplate(
        csvSettings: _draft,
      );
      if (!mounted) return;
      final saved = await CsvService.saveFileToDevice(
        file: built.file,
        fileName: built.fileName,
      );
      if (saved != null) _snack('Anlagen-Vorlage heruntergeladen');
    } catch (e) {
      appLog('Anlagen-Vorlage Download fehlgeschlagen', error: e);
      _snack('Fehler: $e');
    }
  }

  Future<void> _downloadGewerkeVorlagenTemplate() async {
    try {
      final file = await TemplateService.buildGewerkeVorlagenCsvTemplate(
        csvSettings: _draft,
      );
      if (!mounted) return;
      final saved = await CsvService.saveFileToDevice(
        file: file,
        fileName: 'gewerkevorlagen_vorlage.csv',
      );
      if (saved != null) _snack('Gewerkevorlagen-Vorlage heruntergeladen');
    } catch (e) {
      appLog('Gewerkevorlagen-Vorlage Download fehlgeschlagen', error: e);
      _snack('Fehler: $e');
    }
  }

  Future<void> _confirmAndDeleteTemplates() async {
    final ok = await _confirmDanger(
      title: 'Alle Vorlagen löschen?',
      body:
          'Möchten Sie wirklich ALLE Vorlagen für dieses Projekt löschen?\n\n'
          'Hinweis: Bereits importierte Gewerke und Anlagen in den Gebäuden bleiben erhalten.\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden!',
    );
    if (!ok) return;

    try {
      await _withBlockingProgress(() async {
        final dbService = ref.read(databaseServiceProvider);
        await dbService.permanentlyDeleteProjectImportData(widget.projectId);
        await TemplateService.clearTemplateImportHeaderRow(widget.projectId);
        await ref
            .read(csvSettingsProvider(widget.projectId).notifier)
            .clearAnlagenCsvImportStructure();
        await _loadProjectTemplates();
        await _loadCsvSettings();
      });
    } catch (e, st) {
      appLog('Fehler beim Löschen der Vorlagen', error: e, stackTrace: st);
      _snack('Vorlagen konnten nicht gelöscht werden: $e');
    }
  }

  Future<void> _confirmAndDeleteAll() async {
    final ok = await _confirmDanger(
      title: 'Alle Daten löschen?',
      body:
          'Möchten Sie wirklich ALLES für dieses Gebäude und Projekt löschen?\n\n'
          '• Alle Anlagen und Gewerke (Gebäude)\n'
          '• Alle Grundrisse/Ebenen\n'
          '• Alle Gewerkevorlagen (Projekt)\n'
          '• Gespeicherte CSV-Import-Struktur\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden!',
    );
    if (!ok) return;

    try {
      await _withBlockingProgress(() async {
        final dbService = ref.read(databaseServiceProvider);
        final building = await dbService.getBuildingById(widget.buildingId);
        if (building == null) {
          throw StateError('Gebäude nicht gefunden');
        }

        await dbService.permanentlyDeleteAllBuildingOperationalData(
          widget.buildingId,
          floorPlansForFileCleanup: List.from(building.floors),
        );
        if (widget.projectId.isNotEmpty) {
          await dbService.permanentlyDeleteProjectImportData(widget.projectId);
          await TemplateService.clearTemplateImportHeaderRow(widget.projectId);
          await ref
              .read(csvSettingsProvider(widget.projectId).notifier)
              .clearAnlagenCsvImportStructure();
        }

        building.floors.clear();
        await ref.read(projectsProvider.notifier).updateBuilding(building);
        await clearBuildingCsvUiPrefs(widget.buildingId);

        await _loadProjectTemplates();
        await _loadDisciplines();
        await _loadCsvSettings();
        setState(() {
          _showDisciplineSelection = true;
          _editingDisciplineIndex = null;
          _editingRevisionsobjekt = null;
        });
      });

      if (!mounted) return;
      final dbService = ref.read(databaseServiceProvider);
      final remainingDisciplines =
          await dbService.getDisciplinesByBuildingId(widget.buildingId);
      final remainingAnlagen =
          await dbService.countAllAnlagenRowsForBuilding(widget.buildingId);
      final remainingTemplates = widget.projectId.isNotEmpty
          ? await dbService.countTemplatesByProjectId(widget.projectId)
          : 0;

      if (remainingDisciplines.isNotEmpty ||
          remainingAnlagen > 0 ||
          remainingTemplates > 0) {
        _snack(
          'Warnung: Noch $remainingAnlagen Anlagen, '
          '${remainingDisciplines.length} Gewerke, '
          '$remainingTemplates Vorlagen in der DB.',
          background: AppPalette.warning,
        );
      } else {
        _snack(
          'Alle Gewerke, Anlagen, Grundrisse und Gewerkevorlagen wurden gelöscht.',
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      appLog('Fehler beim Löschen aller Daten: $e');
      appLog('Stack Trace: $st');
      _snack('Löschen fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leavePage();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'CSV-Import',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: _leavePage,
            ),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.upload_file), text: 'CSV-Import'),
                Tab(icon: Icon(Icons.schema), text: 'Eingabefelder'),
              ],
            ),
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    CsvSettingsMappingTab(
                      draft: _draft,
                      controllers: _controllers,
                      templateCount: _projectTemplates.length,
                      hasAnlagenCsvImported: _hasAnlagenCsvImported,
                      onDraftChanged: (next) {
                        setState(() {
                          _draft = next;
                          _controllers.syncFrom(next);
                        });
                      },
                      onScheduleSave: _scheduleAutoSave,
                      onImportTemplates: _importTemplates,
                      onImportAnlagen: _importAnlagenCsv,
                      onDownloadGewerkeTemplate: _downloadGewerkeVorlagenTemplate,
                      onDownloadAnlagenTemplate: _downloadAnlagenTemplate,
                      onDeleteTemplates: _confirmAndDeleteTemplates,
                      onDeleteAll: _confirmAndDeleteAll,
                      onShowError: _snack,
                      onShowInfo: _snack,
                    ),
                    CsvSettingsSchemaTab(
                      disciplines: _disciplines,
                      templates: _projectTemplates,
                      labelGewerk: _draft.labelGewerk,
                      schemaItemLevelLabel:
                          CsvSettingsDraftOps.schemaItemLevelLabel(_draft),
                      showSelection: _showDisciplineSelection,
                      editingDisciplineIndex: _editingDisciplineIndex,
                      editingRevisionsobjekt: _editingRevisionsobjekt,
                      expandedIndices: _expandedSchemaDisciplineIndices,
                      onExpandedChanged: (next) => setState(
                        () {
                          _expandedSchemaDisciplineIndices
                            ..clear()
                            ..addAll(next);
                        },
                      ),
                      onEdit: (index, ro) => setState(() {
                        _showDisciplineSelection = false;
                        _editingDisciplineIndex = index;
                        _editingRevisionsobjekt = ro;
                      }),
                      onBackToSelection: () => setState(() {
                        _showDisciplineSelection = true;
                        _editingDisciplineIndex = null;
                        _editingRevisionsobjekt = null;
                      }),
                      onSchemaChanged: (newSchema) {
                        final index = _editingDisciplineIndex;
                        final ro = _editingRevisionsobjekt;
                        if (index == null || ro == null) return;
                        setState(() {
                          _disciplines[index] =
                              CsvSettingsSchemaHelpers
                                  .withUpdatedRevisionsobjektSchema(
                            _disciplines[index],
                            ro,
                            newSchema,
                          );
                        });
                        _scheduleAutoSave();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
