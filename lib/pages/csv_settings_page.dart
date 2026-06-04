// lib/pages/csv_settings_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/csv_hierarchy_level.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../providers/database_provider.dart';
import '../services/anlagen_csv_import_service.dart';
import '../services/template_service.dart';
import '../providers/projects_provider.dart';
import 'widgets/schema_editor_dialog.dart';
import 'widgets/settings_card.dart';
import '../utils/app_log.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

class CsvSettingsPage extends ConsumerStatefulWidget {
  final String projectId;
  final String buildingId;

  const CsvSettingsPage({
    Key? key,
    required this.projectId,
    required this.buildingId,
  }) : super(key: key);

  @override
  ConsumerState<CsvSettingsPage> createState() => _CsvSettingsPageState();
}

class _CsvSettingsPageState extends ConsumerState<CsvSettingsPage> {
  // Hierarchie-Ebenen (1 = oberste, 3 = Blatt)
  HierarchyLevelConfig _level1 = const HierarchyLevelConfig(enabled: true, nameColumn: 2);
  HierarchyLevelConfig _level2 = const HierarchyLevelConfig(enabled: false, nameColumn: 1);
  HierarchyLevelConfig _level3 = const HierarchyLevelConfig(
    enabled: true,
    nameColumn: 1,
    useIdColumn: false,
  );
  int? _anlageBauteilSpalte;
  String _anlageKuerzel = 'A,Anlage';
  String _bauteilKuerzel = 'B,Bauteil';
  String _labelGewerk = 'Gewerk';
  String _labelAnlage = 'Anlage';
  String _labelBauteil = 'Bauteil';
  String _groupingGewerkParamKey = '';
  String _groupingAnlageParamKey = '';
  String _displayNameParamKey = 'Name';
  int? _displayNameSpalte;

  /// Attribut-Vierergruppen: Name, Typ, Optionen, Art (z. B. ATT1 … ATT1_ART).
  List<AttributeTripletColumn> _attributeQuadrupletColumns = [];
  /// Attribut-Zweierpaare: ATTn + ATTn_wert (Anlagen-CSV).
  List<AttributeColumnPair> _attributeColumnPairs = [];

  /// Spalten-Labels für Fotonummern beim CSV-Export (1–4). Leer = Spalte nicht verwendet.
  String? _foto1SpalteLabel;
  String? _foto2SpalteLabel;
  String? _foto3SpalteLabel;
  String? _foto4SpalteLabel;

  // TextEditingController müssen über Rebuilds stabil bleiben,
  // sonst springen Cursor/Selection/Fokus beim Tippen zurück.
  late final TextEditingController _anlageKuerzelCtrl;
  late final TextEditingController _bauteilKuerzelCtrl;
  late final TextEditingController _labelGewerkCtrl;
  late final TextEditingController _labelAnlageCtrl;
  late final TextEditingController _labelBauteilCtrl;
  late final TextEditingController _groupingGewerkParamKeyCtrl;
  late final TextEditingController _groupingAnlageParamKeyCtrl;
  late final TextEditingController _displayNameParamKeyCtrl;
  late final TextEditingController _foto1SpalteLabelCtrl;
  late final TextEditingController _foto2SpalteLabelCtrl;
  late final TextEditingController _foto3SpalteLabelCtrl;
  late final TextEditingController _foto4SpalteLabelCtrl;
  late final TextEditingController _attrPairGenStartCtrl;
  late final TextEditingController _attrPairGenEndCtrl;
  late final TextEditingController _attrQuadGenStartCtrl;
  late final TextEditingController _attrQuadGenEndCtrl;

  // Bearbeitbar-Flags (für Kompatibilität)
  bool _lfdNummerBearbeitbar = true;
  bool _nameBearbeitbar = true;
  bool _gewerkBearbeitbar = true;
  bool _anlageBauteilBearbeitbar = true;
  bool _parameterBearbeitbar = true;

  bool _isLoading = true;
  List<Disziplin> _disciplines = [];
  bool _showDisciplineSelection = true;
  int? _editingDisciplineIndex;
  String? _editingRevisionsobjekt;
  final Set<int> _expandedSchemaDisciplineIndices = {};
  List<Template> _projectTemplates = [];
  bool _hasAnlagenCsvImported = false;

  // CSV-Header aus letztem Import (Anlagen oder Gewerkevorlagen)
  List<String>? _mappingCsvHeaders;

  // Auto-Save Timer
  Timer? _autoSaveTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _anlageKuerzelCtrl = TextEditingController(text: _anlageKuerzel);
    _bauteilKuerzelCtrl = TextEditingController(text: _bauteilKuerzel);
    _labelGewerkCtrl = TextEditingController(text: _labelGewerk);
    _labelAnlageCtrl = TextEditingController(text: _labelAnlage);
    _labelBauteilCtrl = TextEditingController(text: _labelBauteil);
    _groupingGewerkParamKeyCtrl = TextEditingController(text: _groupingGewerkParamKey);
    _groupingAnlageParamKeyCtrl = TextEditingController(text: _groupingAnlageParamKey);
    _displayNameParamKeyCtrl = TextEditingController(text: _displayNameParamKey);
    _foto1SpalteLabelCtrl = TextEditingController(text: _foto1SpalteLabel ?? '');
    _foto2SpalteLabelCtrl = TextEditingController(text: _foto2SpalteLabel ?? '');
    _foto3SpalteLabelCtrl = TextEditingController(text: _foto3SpalteLabel ?? '');
    _foto4SpalteLabelCtrl = TextEditingController(text: _foto4SpalteLabel ?? '');
    _attrPairGenStartCtrl = TextEditingController(text: '4');
    _attrPairGenEndCtrl = TextEditingController(text: '17');
    _attrQuadGenStartCtrl = TextEditingController(text: '4');
    _attrQuadGenEndCtrl = TextEditingController(text: '63');
    _loadAllData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _anlageKuerzelCtrl.dispose();
    _bauteilKuerzelCtrl.dispose();
    _labelGewerkCtrl.dispose();
    _labelAnlageCtrl.dispose();
    _labelBauteilCtrl.dispose();
    _groupingGewerkParamKeyCtrl.dispose();
    _groupingAnlageParamKeyCtrl.dispose();
    _displayNameParamKeyCtrl.dispose();
    _foto1SpalteLabelCtrl.dispose();
    _foto2SpalteLabelCtrl.dispose();
    _foto3SpalteLabelCtrl.dispose();
    _foto4SpalteLabelCtrl.dispose();
    _attrPairGenStartCtrl.dispose();
    _attrPairGenEndCtrl.dispose();
    _attrQuadGenStartCtrl.dispose();
    _attrQuadGenEndCtrl.dispose();
    super.dispose();
  }

  Future<void> _leavePage() async {
    _autoSaveTimer?.cancel();
    if (mounted) {
      await _saveAllSettings();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _syncTextControllersFromState() {
    // Nur außerhalb von build() setzen, damit die Selection nicht beim Tippen resettet wird.
    if (_anlageKuerzelCtrl.text != _anlageKuerzel) {
      _anlageKuerzelCtrl.value = TextEditingValue(
        text: _anlageKuerzel,
        selection: TextSelection.collapsed(offset: _anlageKuerzel.length),
      );
    }
    if (_bauteilKuerzelCtrl.text != _bauteilKuerzel) {
      _bauteilKuerzelCtrl.value = TextEditingValue(
        text: _bauteilKuerzel,
        selection: TextSelection.collapsed(offset: _bauteilKuerzel.length),
      );
    }
    if (_labelGewerkCtrl.text != _labelGewerk) {
      _labelGewerkCtrl.value = TextEditingValue(
        text: _labelGewerk,
        selection: TextSelection.collapsed(offset: _labelGewerk.length),
      );
    }
    if (_labelAnlageCtrl.text != _labelAnlage) {
      _labelAnlageCtrl.value = TextEditingValue(
        text: _labelAnlage,
        selection: TextSelection.collapsed(offset: _labelAnlage.length),
      );
    }
    if (_labelBauteilCtrl.text != _labelBauteil) {
      _labelBauteilCtrl.value = TextEditingValue(
        text: _labelBauteil,
        selection: TextSelection.collapsed(offset: _labelBauteil.length),
      );
    }
    if (_groupingGewerkParamKeyCtrl.text != _groupingGewerkParamKey) {
      _groupingGewerkParamKeyCtrl.value = TextEditingValue(
        text: _groupingGewerkParamKey,
        selection: TextSelection.collapsed(offset: _groupingGewerkParamKey.length),
      );
    }
    if (_groupingAnlageParamKeyCtrl.text != _groupingAnlageParamKey) {
      _groupingAnlageParamKeyCtrl.value = TextEditingValue(
        text: _groupingAnlageParamKey,
        selection: TextSelection.collapsed(offset: _groupingAnlageParamKey.length),
      );
    }
    if (_displayNameParamKeyCtrl.text != _displayNameParamKey) {
      _displayNameParamKeyCtrl.value = TextEditingValue(
        text: _displayNameParamKey,
        selection: TextSelection.collapsed(offset: _displayNameParamKey.length),
      );
    }
    final f1 = _foto1SpalteLabel ?? '';
    if (_foto1SpalteLabelCtrl.text != f1) {
      _foto1SpalteLabelCtrl.value = TextEditingValue(text: f1, selection: TextSelection.collapsed(offset: f1.length));
    }
    final f2 = _foto2SpalteLabel ?? '';
    if (_foto2SpalteLabelCtrl.text != f2) {
      _foto2SpalteLabelCtrl.value = TextEditingValue(text: f2, selection: TextSelection.collapsed(offset: f2.length));
    }
    final f3 = _foto3SpalteLabel ?? '';
    if (_foto3SpalteLabelCtrl.text != f3) {
      _foto3SpalteLabelCtrl.value = TextEditingValue(text: f3, selection: TextSelection.collapsed(offset: f3.length));
    }
    final f4 = _foto4SpalteLabel ?? '';
    if (_foto4SpalteLabelCtrl.text != f4) {
      _foto4SpalteLabelCtrl.value = TextEditingValue(text: f4, selection: TextSelection.collapsed(offset: f4.length));
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCsvSettings(),
      _loadDisciplines(),
      _loadProjectTemplates(),
    ]);
    await _loadImportStatus();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadImportStatus() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final hasAnlagen = await AnlagenCsvImportService.hasBuildingAnlagenCsvImport(
        dbService,
        widget.buildingId,
      );
      if (mounted) {
        setState(() => _hasAnlagenCsvImported = hasAnlagen);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Import-Status: $e');
    }
  }

  List<AttributeTripletColumn> _loadAttributeQuadrupletColumnsFromSettings(
    CsvSettings settings,
  ) {
    return List<AttributeTripletColumn>.from(settings.attributeTripletColumns);
  }

  Future<void> _loadCsvSettings() async {
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      await notifier.load();
      final settings = ref.read(csvSettingsProvider(widget.projectId));
      setState(() {
        _level1 = settings.level1;
        _level2 = settings.level2;
        _level3 = settings.level3;
        _anlageBauteilSpalte = settings.anlageBauteilSpalte;
        _anlageKuerzel = settings.anlageKuerzel;
        _bauteilKuerzel = settings.bauteilKuerzel;
        _labelGewerk = settings.labelGewerk;
        _labelAnlage = settings.labelAnlage;
        _labelBauteil = settings.labelBauteil;
        _attributeQuadrupletColumns = _loadAttributeQuadrupletColumnsFromSettings(settings);
        _attributeColumnPairs = List<AttributeColumnPair>.from(settings.attributeColumnPairs);
        _foto1SpalteLabel = settings.foto1SpalteLabel;
        _foto2SpalteLabel = settings.foto2SpalteLabel;
        _foto3SpalteLabel = settings.foto3SpalteLabel;
        _foto4SpalteLabel = settings.foto4SpalteLabel;
        _groupingGewerkParamKey = settings.groupingGewerkParamKey;
        _groupingAnlageParamKey = settings.groupingAnlageParamKey;
        _displayNameParamKey = settings.displayNameParamKey;
        _displayNameSpalte = settings.displayNameSpalte;
        _mappingCsvHeaders = settings.importHeaderRow.isNotEmpty
            ? List<String>.from(settings.importHeaderRow)
            : null;
      });
      _syncTextControllersFromState();
      _syncGroupingKeysFromLevels();
      if (_mappingCsvHeaders != null) {
        _syncGroupingGewerkKeyFromColumn();
        _syncGroupingAnlageKeyFromColumn();
        _syncAttributeMappingFromHeaders(_mappingCsvHeaders!);
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_${widget.projectId}';
      final settingsJson = prefs.getString(key);
      if (settingsJson != null) {
        final flags = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _lfdNummerBearbeitbar = flags['lfdNummerBearbeitbar'] as bool? ?? true;
          _nameBearbeitbar = flags['nameBearbeitbar'] as bool? ?? true;
          _gewerkBearbeitbar = flags['gewerkBearbeitbar'] as bool? ?? true;
          _anlageBauteilBearbeitbar = flags['anlageBauteilBearbeitbar'] as bool? ?? true;
          _parameterBearbeitbar = flags['parameterBearbeitbar'] as bool? ?? true;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der CSV-Einstellungen: $e');
    }
  }

  Future<void> _loadDisciplines() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      var loaded = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      if (loaded.isEmpty) {
        loaded = await TemplateService.ensureDisciplinesFromTemplates(
          dbService,
          widget.buildingId,
          widget.projectId,
        );
      }
      if (mounted) {
        setState(() {
          _disciplines = loaded;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Disziplinen: $e');
    }
  }

  Future<void> _loadProjectTemplates() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final templates = await TemplateService.loadTemplatesFromDatabase(
        dbService,
        widget.projectId,
      );
      if (mounted) {
        setState(() => _projectTemplates = templates);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Vorlagen: $e');
    }
  }

  List<String> _revisionsobjekteForDiscipline(Disziplin d) {
    final names = <String>{};
    for (final t in _projectTemplates) {
      if (t.gewerk.trim() == d.label.trim()) {
        final typ = t.anlagentyp.trim();
        if (typ.isNotEmpty) names.add(typ);
      }
    }
    names.addAll(d.revisionsobjektSchemas.keys);
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<Map<String, dynamic>> _schemaForRevisionsobjekt(Disziplin d, String ro) {
    final roFields = d.revisionsobjektSchemas[ro];
    if (roFields != null && roFields.isNotEmpty) {
      return roFields.map((f) => Map<String, dynamic>.from(f)).toList();
    }
    for (final t in _projectTemplates) {
      if (t.gewerk.trim() == d.label.trim() &&
          t.anlagentyp.trim() == ro.trim()) {
        final fromTemplate =
            TemplateService.getSchemaFromTemplateParameter(t.parameter);
        if (fromTemplate.isNotEmpty) return fromTemplate;
      }
    }
    if (d.revisionsobjektSchemas.isEmpty) {
      return d.legacyIndividualSchemaFields;
    }
    return const [];
  }

  // Entferne die Hilfsfunktion für automatisches Schema aus Mapping

  Future<void> _saveCsvSettings() async {
    if (!mounted) return;
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      final current = ref.read(csvSettingsProvider(widget.projectId));
      final settings = CsvSettings(
        level1: _level1,
        level2: _level2,
        level3: _level3,
        anlageBauteilSpalte: _anlageBauteilSpalte,
        delimiterMode: 'auto',
        anlageKuerzel: _anlageKuerzel,
        bauteilKuerzel: _bauteilKuerzel,
        useDisciplineGrouping: _level1.enabled,
        labelGewerk: _labelGewerk,
        labelAnlage: _labelAnlage,
        labelBauteil: _labelBauteil,
        attributeColumnPairs: List<AttributeColumnPair>.from(_attributeColumnPairs),
        attributeTripletColumns:
            List<AttributeTripletColumn>.from(_attributeQuadrupletColumns),
        foto1SpalteLabel: _foto1SpalteLabel,
        foto2SpalteLabel: _foto2SpalteLabel,
        foto3SpalteLabel: _foto3SpalteLabel,
        foto4SpalteLabel: _foto4SpalteLabel,
        importHeaderRow: current.importHeaderRow,
        exportDelimiter: current.exportDelimiter,
        groupingGewerkParamKey: _groupingGewerkParamKey,
        groupingAnlageParamKey: _groupingAnlageParamKey,
        displayNameParamKey: _displayNameParamKey,
        displayNameSpalte: _displayNameSpalte,
      );
      await notifier.save(settings);

      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_${widget.projectId}';
      final flags = {
        'lfdNummerBearbeitbar': _lfdNummerBearbeitbar,
        'nameBearbeitbar': _nameBearbeitbar,
        'gewerkBearbeitbar': _gewerkBearbeitbar,
        'anlageBauteilBearbeitbar': _anlageBauteilBearbeitbar,
        'parameterBearbeitbar': _parameterBearbeitbar,
      };
      final existing = json.decode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      await prefs.setString(key, json.encode({...existing, ...flags}));
    } catch (e) {
      debugPrint('Fehler beim automatischen Speichern der CSV-Einstellungen: $e');
    }
  }

  /// Speichert alle Einstellungen automatisch
  Future<void> _saveAllSettings() async {
    if (!mounted || _isSaving) return;

    _isSaving = true;
    try {
      await Future.wait([
        _saveCsvSettings(),
        _saveDisciplines(),
      ]);
    } catch (e) {
      debugPrint('Fehler beim automatischen Speichern: $e');
    } finally {
      if (mounted) {
        _isSaving = false;
      }
    }
  }

  /// Plant automatisches Speichern nach einer kurzen Verzögerung
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _saveAllSettings();
    });
  }

  Future<void> _saveDisciplines() async {
    if (!mounted) return;
    final dbService = ref.read(databaseServiceProvider);
    await dbService.replaceDisciplines(widget.buildingId, _disciplines);
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
              'CSV-Einstellungen',
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
                Tab(icon: Icon(Icons.map), text: 'CSV-Mapping'),
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
                    _buildMappingTab(),
                    _buildSchemaTab(),
                  ],
                ),
        ),
      ),
    );
  }

  // --- MAPPING TAB ---

  Widget _buildMappingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Spaltenzuordnung gilt einheitlich für Anlagen-Import, Anlagen-Export und Gewerkevorlagen. '
            'Nach einem CSV-Import werden die Spaltenüberschriften für die Auswahl übernommen.',
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeaderAction(
                icon: Icons.upload_file,
                label: 'Gewerkevorlagen',
                color: Colors.orange,
                imported: _projectTemplates.isNotEmpty,
                onPressed: _importTemplates,
              ),
              _buildHeaderAction(
                icon: Icons.download,
                label: 'Anlagen-CSV',
                color: Colors.green,
                imported: _hasAnlagenCsvImported,
                onPressed: _importAnlagenCsv,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            title: 'CSV-Mapping',
            subtitle: _hierarchySubtitle(),
          ),
          const SizedBox(height: 12),
          _buildHierarchyLevelCard(
            levelNum: 1,
            label: _labelGewerk,
            color: Colors.blueGrey,
            config: _level1,
            onChanged: (c) {
              setState(() {
                _level1 = c;
                _syncGroupingKeysFromLevels();
              });
              _scheduleAutoSave();
            },
          ),
          _buildConnector(),
          _buildHierarchyLevelCard(
            levelNum: 2,
            label: _labelAnlage,
            color: Colors.green,
            config: _level2,
            onChanged: (c) {
              setState(() {
                _level2 = c;
                _syncGroupingKeysFromLevels();
              });
              _scheduleAutoSave();
            },
          ),
          _buildConnector(),
          _buildHierarchyLevelCard(
            levelNum: 3,
            label: _labelBauteil,
            color: Colors.orange,
            config: _level3,
            isLeafLevel: true,
            onChanged: (c) {
              setState(() {
                _level3 = c;
                _syncGroupingKeysFromLevels();
              });
              _scheduleAutoSave();
            },
          ),
          const SizedBox(height: 16),
          _buildCollapsibleAttributeQuadrupletsSection(),
          const SizedBox(height: 16),
          _buildCollapsibleFotoSpaltenSection(),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Begriffe der Ebenen anpassen'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              TextField(
                controller: _labelGewerkCtrl,
                decoration: _themedInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 1',
                  helperText: 'Standard: Gewerk',
                ),
                onChanged: (val) {
                  setState(() => _labelGewerk = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelAnlageCtrl,
                decoration: _themedInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 2',
                  helperText: 'Standard: Anlage',
                ),
                onChanged: (val) {
                  setState(() => _labelAnlage = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelBauteilCtrl,
                decoration: _themedInputDecoration(
                  context,
                  labelText: 'Bezeichnung Ebene 3',
                  helperText: 'Standard: Bauteil',
                ),
                onChanged: (val) {
                  setState(() => _labelBauteil = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameParamKeyCtrl,
                decoration: _themedInputDecoration(
                  context,
                  labelText: 'Parameter für Anzeige Ebene 3',
                  helperText:
                      'Key aus Gewerkevorlagen-Schema (z. B. Name, Anlagenbezeichnung). '
                      'Wird bei Neuaufnahmen für die Beschriftung in der Anlagenliste genutzt.',
                ),
                onChanged: (val) {
                  setState(() => _displayNameParamKey = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              _buildColumnSelector(
                label: 'Alternativ: CSV-Spalte (nur Anlagen-Import)',
                value: _displayNameSpalte ?? _level3.nameColumn,
                onChanged: (v) {
                  setState(() => _displayNameSpalte = v);
                  _scheduleAutoSave();
                },
                csvHeaders: _mappingCsvHeaders,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildValidationWarning(),
          const SizedBox(height: 24),
          _buildBottomDeleteButton(
            title: 'Alle Vorlagen löschen',
            description:
                'Löscht alle importierten Gewerkevorlagen für dieses Projekt. '
                'Gewerke und Anlagen im Gebäude bleiben erhalten.',
            buttonText: 'Vorlagen löschen',
            onPressed: () => _confirmAndDeleteTemplates(),
          ),
          const SizedBox(height: 16),
          _buildBottomDeleteButton(
            title: 'Alle Daten löschen',
            description: 'Löscht alle Gewerke, Anlagen und Grundrisse (Ebenen) für dieses Gebäude. Diese Aktion kann nicht rückgängig gemacht werden.',
            buttonText: 'Alle löschen',
            onPressed: () => _confirmAndDeleteAll(),
          ),
        ],
      ),
    );
  }

  // --- SCHEMA TAB ---

  Widget _buildSchemaTab() {
    if (!_showDisciplineSelection &&
        _editingDisciplineIndex != null &&
        _editingRevisionsobjekt != null) {
      final d = _disciplines[_editingDisciplineIndex!];
      final ro = _editingRevisionsobjekt!;
      return Column(
        children: [
          _buildBackToSelectionHeader('${d.label} → $_schemaItemLevelLabel: $ro'),
          Expanded(
            child: SchemaEditorWidget(
              existingSchema: _schemaForRevisionsobjekt(d, ro),
              onSchemaChanged: (newSchema) {
                setState(() {
                  final updatedRoSchemas =
                      Map<String, List<Map<String, dynamic>>>.from(
                    d.revisionsobjektSchemas,
                  );
                  updatedRoSchemas[ro] = newSchema
                      .map((f) => Map<String, dynamic>.from(f))
                      .toList();

                  final globalOnly = d.schema
                      .where((f) => f['isGlobal'] == true)
                      .map((f) => Map<String, dynamic>.from(f))
                      .toList();

                  _disciplines[_editingDisciplineIndex!] = Disziplin(
                    label: d.label,
                    icon: d.icon,
                    color: d.color,
                    schema: globalOnly,
                    groupingKey: d.groupingKey,
                    revisionsobjektSchemas: updatedRoSchemas,
                  );
                });
                _scheduleAutoSave();
              },
            ),
          ),
        ],
      );
    }

    return _buildSchemaSelectionView();
  }

  Widget _buildBackToSelectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _showDisciplineSelection = true;
              _editingDisciplineIndex = null;
              _editingRevisionsobjekt = null;
            }),
          ),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_labelGewerk (Ebene 1)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Nach Import der Gewerkevorlagen: $_labelGewerk aufklappen, '
            'darunter $_schemaItemLevelLabel (Ebene 2) wählen, um die Attribute zu bearbeiten.',
            style: TextStyle(fontSize: 13, color: _mutedTextColor(context)),
          ),
          const SizedBox(height: 16),

          if (_disciplines.isEmpty && _projectTemplates.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Importieren Sie im Tab „CSV-Mapping“ Gewerkevorlagen, '
                  'damit $_labelGewerk und $_schemaItemLevelLabel hier erscheinen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _mutedTextColor(context),
                  ),
                ),
              ),
            )
          else if (_disciplines.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ...List.generate(_disciplines.length, (index) {
              final d = _disciplines[index];
              final roList = _revisionsobjekteForDiscipline(d);
              final isExpanded =
                  _expandedSchemaDisciplineIndices.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.25)),
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
                        setState(() {
                          if (expanded) {
                            _expandedSchemaDisciplineIndices.add(index);
                          } else {
                            _expandedSchemaDisciplineIndices.remove(index);
                          }
                        });
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: d.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(d.icon, color: d.color, size: 22),
                      ),
                      title: Text(
                        d.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        roList.isEmpty
                            ? 'Keine $_schemaItemLevelLabel (Ebene 2)'
                            : '${roList.length} $_schemaItemLevelLabel',
                        style: TextStyle(fontSize: 12, color: _mutedTextColor(context)),
                      ),
                      children: [
                        if (roList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              'Für dieses $_labelGewerk sind in den Gewerkevorlagen '
                              'keine $_schemaItemLevelLabel-Einträge hinterlegt.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _mutedTextColor(context),
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
                              leading: Icon(
                                Icons.account_tree_outlined,
                                color: d.color.withOpacity(0.8),
                                size: 20,
                              ),
                              title: Text(ro),
                              subtitle: Text(
                                '${_schemaForRevisionsobjekt(d, ro).length} Attribute',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _mutedTextColor(context),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(() {
                                _showDisciplineSelection = false;
                                _editingDisciplineIndex = index;
                                _editingRevisionsobjekt = ro;
                              }),
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

  Future<void> _importTemplates() async {
    // Zeige Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.orange),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Zeige Lade-Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await TemplateService.importTemplatesFromCsv(
        ref.read(databaseServiceProvider),
        widget.projectId,
        null,
        buildingId: widget.buildingId,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
        await _loadCsvSettings();
        await _loadProjectTemplates();
        await _loadDisciplines();
        await _loadImportStatus();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gewerkevorlagen importiert')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
    }
  }

  Future<void> _importAnlagenCsv() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dbService = ref.read(databaseServiceProvider);
      await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
      final csvSettings = ref.read(csvSettingsProvider(widget.projectId));

      final result = await AnlagenCsvImportService.runFullImport(
        dbService: dbService,
        projectId: widget.projectId,
        buildingId: widget.buildingId,
        csvSettings: csvSettings,
        saveSettings: (updated) =>
            ref.read(csvSettingsProvider(widget.projectId).notifier).save(updated),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await ref.read(csvSettingsProvider(widget.projectId).notifier).load();
      await _loadCsvSettings();
      await _loadDisciplines();
      await _loadImportStatus();

      if (!mounted) return;
      setState(() {});

      final msg =
          'Anlagen-CSV: ${result.savedCount} neu, ${result.skippedCount} übersprungen';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anlagen-Import fehlgeschlagen: $e')),
      );
    }
  }

  /// Bestätigt und löscht alle Vorlagen für das Projekt
  Future<void> _confirmAndDeleteTemplates() async {
    // Sicherheitsabfrage
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Alle Vorlagen löschen?'),
          ],
        ),
        content: const Text(
          'Möchten Sie wirklich ALLE Vorlagen für dieses Projekt löschen?\n\n'
          'Hinweis: Bereits importierte Gewerke und Anlagen in den Gebäuden bleiben erhalten.\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Lade-Dialog anzeigen
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final dbService = ref.read(databaseServiceProvider);
      
      await dbService.permanentlyDeleteProjectImportData(widget.projectId);
      await TemplateService.clearTemplateImportHeaderRow(widget.projectId);
      await ref
          .read(csvSettingsProvider(widget.projectId).notifier)
          .clearAnlagenCsvImportStructure();

      if (mounted) {
        await _loadProjectTemplates();
        setState(() {});
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
    } catch (e, stackTrace) {
      debugPrint('Fehler beim Löschen der Vorlagen: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
    }
  }

  // --- HELPERS ---

  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  BoxDecoration _themedSurfaceCardDecoration(
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
          color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.25 : 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  InputDecoration _themedInputDecoration(BuildContext context, {String? labelText, String? hintText, String? helperText, Widget? prefixIcon}) {
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

  Widget _buildConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Container(
        height: 20,
        width: 2,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  Widget _buildFotoSpalteField(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: controller,
      decoration: _themedInputDecoration(
        context,
        labelText: label,
        hintText: 'z.B. Foto1 oder Spaltenname aus Ihrer CSV',
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildCollapsibleFotoSpaltenSection() {
    const color = Colors.teal;
    final configuredCount = [
      _foto1SpalteLabel,
      _foto2SpalteLabel,
      _foto3SpalteLabel,
      _foto4SpalteLabel,
    ].where((label) => (label?.trim().isNotEmpty ?? false)).length;
    final subtitle = configuredCount == 0
        ? 'Keine Spalten – zum Konfigurieren aufklappen'
        : '$configuredCount Spalte${configuredCount == 1 ? '' : 'n'} konfiguriert';

    return Container(
      decoration: _themedSurfaceCardDecoration(context, borderColor: color.shade200),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo_library, color: color, size: 24),
          ),
          title: const Text(
            'Fotonummern-Spalten (Export)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: _mutedTextColor(context))),
          children: [
            Text(
              'Spalten-Labels Ihrer CSV, in die beim Export die Fotonummern (1–4) geschrieben werden. '
              'Beim Import können diese Spalten leer sein. Leer lassen = Spalte nicht verwenden.',
              style: TextStyle(fontSize: 12, color: _mutedTextColor(context)),
            ),
            const SizedBox(height: 16),
            _buildFotoSpalteField(
              'Fotonummer 1',
              _foto1SpalteLabelCtrl,
              (v) => setState(() { _foto1SpalteLabel = v.isEmpty ? null : v; _scheduleAutoSave(); }),
            ),
            const SizedBox(height: 8),
            _buildFotoSpalteField(
              'Fotonummer 2',
              _foto2SpalteLabelCtrl,
              (v) => setState(() { _foto2SpalteLabel = v.isEmpty ? null : v; _scheduleAutoSave(); }),
            ),
            const SizedBox(height: 8),
            _buildFotoSpalteField(
              'Fotonummer 3',
              _foto3SpalteLabelCtrl,
              (v) => setState(() { _foto3SpalteLabel = v.isEmpty ? null : v; _scheduleAutoSave(); }),
            ),
            const SizedBox(height: 8),
            _buildFotoSpalteField(
              'Fotonummer 4',
              _foto4SpalteLabelCtrl,
              (v) => setState(() { _foto4SpalteLabel = v.isEmpty ? null : v; _scheduleAutoSave(); }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required List<String>? csvHeaders,
  }) {
    // 1. Modus: Header sind geladen -> DROPDOWN
    if (csvHeaders != null && csvHeaders.isNotEmpty) {
      // Sicherstellen, dass der aktuelle Wert im gültigen Bereich liegt
      final int safeValue = (value >= 0 && value < csvHeaders.length) ? value : 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: _mutedTextColor(context), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            decoration: _themedInputDecoration(context).copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: List.generate(csvHeaders.length, (index) {
              return DropdownMenuItem(
                value: index,
                child: Text(
                  '${index + 1}: ${csvHeaders[index]}', // Zeige "1: Name"
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

    // 2. Modus: Keine Header -> TEXTFELD (1-basiert für den User!)
    return TextFormField(
      key: ValueKey('mapping_col_input_$label'),
      initialValue: (value + 1).toString(),
      keyboardType: TextInputType.number,
      decoration: _themedInputDecoration(
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


  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool isActive,
    required ValueChanged<bool> onToggle,
    Widget? child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
              Switch.adaptive(value: isActive, onChanged: onToggle),
            ],
          ),
        ),
        if (isActive && child != null) Padding(padding: const EdgeInsets.only(top: 8), child: child),
      ],
    );
  }

  Widget _buildCollapsibleAttributeQuadrupletsSection() {
    const color = Colors.deepPurple;
    final groupCount = _attributeQuadrupletColumns.length;
    final pairCount = _attributeColumnPairs.length;
    final subtitle = pairCount > 0
        ? '$pairCount Zweierpaar${pairCount == 1 ? '' : 'e'} (Anlagen-CSV)'
        : groupCount == 0
            ? 'Keine Vierergruppen – zum Konfigurieren aufklappen'
            : '$groupCount Vierergruppe${groupCount == 1 ? '' : 'n'} konfiguriert';

    return Container(
      decoration: _themedSurfaceCardDecoration(context, borderColor: color.shade200),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_column, color: color, size: 24),
          ),
          title: const Text(
            'Attribut-Spalten (4er-Gruppen)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: _mutedTextColor(context))),
          children: [
            Text(
              'Gewerkevorlagen: vier Spalten pro Attribut (ATT1, ATT1_TYPE, ATT1_OPTIONS, ATT1_ART) – unten als Vierergruppen eintragen. '
              'Anlagen-Import: Zweier-Format (ATT1 + ATT1_wert) wird aus der Import-CSV automatisch erkannt; Werte werden den Feldern aus den Gewerkevorlagen zugeordnet.',
              style: TextStyle(fontSize: 12, color: _mutedTextColor(context)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zweierpaare aus Spaltenbereich erzeugen (Anlagen-CSV)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reihenfolge: ATTn, ATTn_wert (z. B. Spalten 4–17). '
                    'Die Spaltenanzahl muss gerade sein.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _attrPairGenStartCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Erste Spalte',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Text('…'),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _attrPairGenEndCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Letzte Spalte',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Zweierpaare generieren'),
                        onPressed: () {
                          final start = int.tryParse(_attrPairGenStartCtrl.text.trim());
                          final end = int.tryParse(_attrPairGenEndCtrl.text.trim());
                          if (start == null || end == null || start >= end) {
                            _showAttrGenError(
                              'Ungültiger Spaltenbereich (Erste < Letzte).',
                            );
                            return;
                          }
                          final count = end - start + 1;
                          if (count % 2 != 0) {
                            _showAttrGenError(
                              'Anzahl Spalten ($count) muss gerade sein (ATT + ATT_wert).',
                            );
                            return;
                          }
                          final startIndex = start - 1;
                          final endIndex = end - 1;
                          final pairs = <AttributeColumnPair>[];
                          for (var i = startIndex; i <= endIndex; i += 2) {
                            pairs.add(AttributeColumnPair(
                              nameColumn: i,
                              valueColumn: i + 1,
                            ));
                          }
                          setState(() => _attributeColumnPairs = pairs);
                          _scheduleAutoSave();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${pairs.length} Zweierpaar${pairs.length == 1 ? '' : 'e'} erzeugt',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vierergruppen aus Spaltenbereich erzeugen',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reihenfolge: Name, Typ, Optionen, Art (z. B. 3–62 → ATT1/ATT1_TYPE/ATT1_OPTIONS/ATT1_ART, …). '
                    'Die Spaltenanzahl im Bereich muss durch 4 teilbar sein.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _attrQuadGenStartCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Erste Spalte',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Text('…'),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _attrQuadGenEndCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Letzte Spalte',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Vierergruppen generieren'),
                        onPressed: () {
                          final start = int.tryParse(_attrQuadGenStartCtrl.text.trim());
                          final end = int.tryParse(_attrQuadGenEndCtrl.text.trim());
                          if (start == null || end == null || start >= end) {
                            _showAttrGenError(
                              'Ungültiger Spaltenbereich (Erste < Letzte).',
                            );
                            return;
                          }
                          final count = end - start + 1;
                          if (count % 4 != 0) {
                            _showAttrGenError(
                              'Anzahl Spalten ($count) muss durch 4 teilbar sein.',
                            );
                            return;
                          }
                          final startIndex = start - 1;
                          final endIndex = end - 1;
                          final groups = <AttributeTripletColumn>[];
                          for (var i = startIndex; i <= endIndex; i += 4) {
                            groups.add(AttributeTripletColumn(
                              nameColumn: i,
                              typeColumn: i + 1,
                              optionsColumn: i + 2,
                              artColumn: i + 3,
                            ));
                          }
                          setState(() => _attributeQuadrupletColumns = groups);
                          _scheduleAutoSave();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${groups.length} Vierergruppe${groups.length == 1 ? '' : 'n'} erzeugt',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_attributeQuadrupletColumns.length, (idx) {
              final group = _attributeQuadrupletColumns[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attribut ${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _mutedTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildColumnSelector(
                            label: 'Name',
                            value: group.nameColumn,
                            onChanged: (v) => _updateQuadrupletColumn(
                              idx,
                              AttributeTripletColumn(
                                nameColumn: v,
                                typeColumn: group.typeColumn,
                                optionsColumn: group.optionsColumn,
                                artColumn: group.artColumn,
                              ),
                            ),
                            csvHeaders: _mappingCsvHeaders,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildColumnSelector(
                            label: 'Typ',
                            value: group.typeColumn,
                            onChanged: (v) => _updateQuadrupletColumn(
                              idx,
                              AttributeTripletColumn(
                                nameColumn: group.nameColumn,
                                typeColumn: v,
                                optionsColumn: group.optionsColumn,
                                artColumn: group.artColumn,
                              ),
                            ),
                            csvHeaders: _mappingCsvHeaders,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildColumnSelector(
                            label: 'Optionen',
                            value: group.optionsColumn,
                            onChanged: (v) => _updateQuadrupletColumn(
                              idx,
                              AttributeTripletColumn(
                                nameColumn: group.nameColumn,
                                typeColumn: group.typeColumn,
                                optionsColumn: v,
                                artColumn: group.artColumn,
                              ),
                            ),
                            csvHeaders: _mappingCsvHeaders,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildColumnSelector(
                            label: 'Art',
                            value: group.artColumn,
                            onChanged: (v) => _updateQuadrupletColumn(
                              idx,
                              AttributeTripletColumn(
                                nameColumn: group.nameColumn,
                                typeColumn: group.typeColumn,
                                optionsColumn: group.optionsColumn,
                                artColumn: v,
                              ),
                            ),
                            csvHeaders: _mappingCsvHeaders,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _attributeQuadrupletColumns =
                                  List<AttributeTripletColumn>.from(_attributeQuadrupletColumns)
                                    ..removeAt(idx);
                            });
                            _scheduleAutoSave();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Vierergruppe hinzufügen'),
              onPressed: () {
                final maxCol = (_mappingCsvHeaders?.length ?? 20) - 1;
                final used = _allReservedColumnIndices().toSet();
                for (final g in _attributeQuadrupletColumns) {
                  used.addAll(g.columnIndices);
                }
                var n = 0;
                while (used.contains(n) && n <= maxCol) n++;
                var t = n + 1;
                while (used.contains(t) && t <= maxCol) t++;
                var o = t + 1;
                while (used.contains(o) && o <= maxCol) o++;
                var a = o + 1;
                while (used.contains(a) && a <= maxCol) a++;
                setState(() {
                  _attributeQuadrupletColumns =
                      List<AttributeTripletColumn>.from(_attributeQuadrupletColumns)
                        ..add(AttributeTripletColumn(
                          nameColumn: n,
                          typeColumn: t,
                          optionsColumn: o,
                          artColumn: a,
                        ));
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuadrupletColumn(int idx, AttributeTripletColumn updated) {
    setState(() {
      _attributeQuadrupletColumns =
          List<AttributeTripletColumn>.from(_attributeQuadrupletColumns)..[idx] = updated;
    });
    _scheduleAutoSave();
  }

  String _hierarchySubtitle() {
    final parts = <String>[];
    if (_level1.enabled) parts.add(_labelGewerk);
    if (_level2.enabled) parts.add(_labelAnlage);
    if (_level3.enabled) parts.add(_labelBauteil);
    if (parts.isEmpty) return 'Keine Ebene aktiv';
    return parts.join(' → ');
  }

  String get _schemaItemLevelLabel {
    if (_level2.enabled && _countEnabledLevels() >= 2) return _labelAnlage;
    if (_level3.enabled) return _labelBauteil;
    return _labelAnlage;
  }

  int _countEnabledLevels() {
    var n = 0;
    if (_level1.enabled) n++;
    if (_level2.enabled) n++;
    if (_level3.enabled) n++;
    return n;
  }

  /// Spalten der Hierarchie-Ebenen (ohne Attribut-Paare).
  List<int> _mappingColumnIndices({int? excludeLevelNum}) {
    final used = <int>[];
    void addLevel(int levelNum, HierarchyLevelConfig level) {
      if (!level.enabled || excludeLevelNum == levelNum) return;
      used.add(level.nameColumn);
      if (level.useIdColumn && level.idColumn != null) {
        used.add(level.idColumn!);
      }
    }
    addLevel(1, _level1);
    addLevel(2, _level2);
    addLevel(3, _level3);
    if (_anlageBauteilSpalte != null) used.add(_anlageBauteilSpalte!);
    return used;
  }

  /// Alle reservierten Spalten inkl. Attribut-Mappings (für freie Spalte suchen).
  List<int> _allReservedColumnIndices() {
    final used = _mappingColumnIndices();
    for (final p in _attributeColumnPairs) {
      used.add(p.nameColumn);
      used.add(p.valueColumn);
    }
    for (final g in _attributeQuadrupletColumns) {
      used.addAll(g.columnIndices);
    }
    return used;
  }

  int _pickFreeMappingColumn(int preferred, {int? excludeLevelNum}) {
    final used = _mappingColumnIndices(excludeLevelNum: excludeLevelNum).toSet();
    if (!used.contains(preferred)) return preferred;
    return _nextFreeIndex(used);
  }

  String _columnLabel(int index) => '${index + 1}';

  Widget _buildHierarchyLevelCard({
    required int levelNum,
    required String label,
    required Color color,
    required HierarchyLevelConfig config,
    required ValueChanged<HierarchyLevelConfig> onChanged,
    bool isLeafLevel = false,
  }) {
    final canDisable = _countEnabledLevels() > 1 || !config.enabled;

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
          _buildToggleRow(
            icon: Icons.power_settings_new,
            label: 'Ebene aktiv',
            isActive: config.enabled,
            onToggle: (val) {
              if (!val && !canDisable) return;
              var updated = config.copyWith(enabled: val);
              if (val) {
                updated = updated.copyWith(
                  nameColumn: _pickFreeMappingColumn(
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
            _buildColumnSelector(
              label: 'Name-Spalte',
              value: config.nameColumn,
              onChanged: (v) {
                var updated = config.copyWith(nameColumn: v);
                if (updated.useIdColumn &&
                    updated.idColumn != null &&
                    updated.idColumn == v) {
                  updated = updated.copyWith(
                    idColumn: _nextFreeIndex([
                      ..._mappingColumnIndices(excludeLevelNum: levelNum),
                      v,
                    ]),
                  );
                }
                onChanged(updated);
              },
              csvHeaders: _mappingCsvHeaders,
            ),
            const SizedBox(height: 12),
            _buildToggleRow(
              icon: Icons.tag,
              label: 'ID-Spalte verwenden?',
              isActive: config.useIdColumn,
              onToggle: (val) {
                onChanged(
                  config.copyWith(
                    useIdColumn: val,
                    idColumn: val
                        ? _nextFreeIndex([
                            ..._mappingColumnIndices(excludeLevelNum: levelNum),
                            config.nameColumn,
                          ])
                        : null,
                    clearIdColumn: !val,
                  ),
                );
              },
              child: config.useIdColumn
                  ? _buildColumnSelector(
                      label: 'ID-Spalte (lfd Nr.)',
                      value: config.idColumn ??
                          _nextFreeIndex([
                            ..._mappingColumnIndices(excludeLevelNum: levelNum),
                            config.nameColumn,
                          ]),
                      onChanged: (v) => onChanged(config.copyWith(useIdColumn: true, idColumn: v)),
                      csvHeaders: _mappingCsvHeaders,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  void _syncGroupingKeysFromLevels() {
    _syncGroupingGewerkKeyFromColumn();
    _syncGroupingAnlageKeyFromColumn();
  }

  Widget _buildValidationWarning() {
    final conflicts = <String>[];
    final mappingByCol = <int, List<String>>{};

    void mapCol(int col, String label) {
      mappingByCol.putIfAbsent(col, () => []).add(label);
    }

    if (_level1.enabled) {
      mapCol(_level1.nameColumn, 'Ebene 1 ($_labelGewerk) Name');
      if (_level1.useIdColumn && _level1.idColumn != null) {
        mapCol(_level1.idColumn!, 'Ebene 1 ID');
      }
    }
    if (_level2.enabled) {
      mapCol(_level2.nameColumn, 'Ebene 2 ($_labelAnlage) Name');
      if (_level2.useIdColumn && _level2.idColumn != null) {
        mapCol(_level2.idColumn!, 'Ebene 2 ID');
      }
    }
    if (_level3.enabled) {
      mapCol(_level3.nameColumn, 'Ebene 3 ($_labelBauteil) Name');
      if (_level3.useIdColumn && _level3.idColumn != null) {
        mapCol(_level3.idColumn!, 'Ebene 3 ID');
      }
    }

    for (final e in mappingByCol.entries) {
      if (e.value.length > 1) {
        conflicts.add('Spalte ${_columnLabel(e.key)}: ${e.value.join(', ')}');
      }
    }

    for (var i = 0; i < _attributeQuadrupletColumns.length; i++) {
      final g = _attributeQuadrupletColumns[i];
      final groupLabel = 'Attribut ${i + 1}';
      final cols = g.columnIndices;
      if (cols.toSet().length != cols.length) {
        conflicts.add('$groupLabel: Spalten innerhalb der Gruppe doppelt vergeben');
      }
      for (final col in cols) {
        for (final e in mappingByCol.entries) {
          if (e.key == col) {
            conflicts.add(
              'Spalte ${_columnLabel(e.key)}: ${e.value.join(', ')} und $groupLabel',
            );
          }
        }
      }
    }

    if (conflicts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spalten-Konflikt:',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...conflicts.map(
                  (m) => Text(m, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text, {Color color = Colors.blue}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _mutedTextColor(context), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
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
                style: TextStyle(color: _mutedTextColor(context), fontSize: 12),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool imported = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: imported ? Colors.green.shade400 : color.withValues(alpha: 0.5),
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
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          ],
        ],
      ),
    );
  }

  void _showAttrGenError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Header nur ergänzen, wenn noch kein passendes Mapping existiert (nicht gegenseitig löschen).
  void _syncAttributeMappingFromHeaders(List<String> headers) {
    if (CsvSettings.headerLooksLikeAnlagenWertFormat(headers)) {
      final pairs = CsvSettings.detectAnlagenAttributePairsFromHeader(headers);
      if (pairs.isEmpty) return;
      final needsUpdate = _attributeColumnPairs.isEmpty ||
          !_pairsMatchHeader(_attributeColumnPairs, headers);
      if (!needsUpdate) return;
      setState(() => _attributeColumnPairs = pairs);
      _scheduleAutoSave();
      return;
    }
    if (CsvSettings.headerLooksLikeGewerkeQuadrupletFormat(headers)) {
      final quadruplets = CsvSettings.detectQuadrupletsFromHeader(headers);
      if (quadruplets.isEmpty) return;
      if (CsvSettings.quadrupletsMatchHeader(_attributeQuadrupletColumns, headers)) {
        return;
      }
      setState(() => _attributeQuadrupletColumns = quadruplets);
      _scheduleAutoSave();
    }
  }

  bool _pairsMatchHeader(
    List<AttributeColumnPair> pairs,
    List<String> headers,
  ) {
    final detected = CsvSettings.detectAnlagenAttributePairsFromHeader(headers);
    if (detected.length != pairs.length) return false;
    for (var i = 0; i < pairs.length; i++) {
      if (pairs[i].nameColumn != detected[i].nameColumn ||
          pairs[i].valueColumn != detected[i].valueColumn) {
        return false;
      }
    }
    return true;
  }

  void _syncGroupingGewerkKeyFromColumn() {
    final headers = _mappingCsvHeaders;
    if (headers == null || !_level1.enabled) return;
    final col = _level1.nameColumn;
    if (col < 0 || col >= headers.length) return;
    final label = headers[col].trim();
    if (label.isEmpty) return;
    _groupingGewerkParamKey = label;
    _groupingGewerkParamKeyCtrl.text = label;
  }

  void _syncGroupingAnlageKeyFromColumn() {
    final headers = _mappingCsvHeaders;
    if (headers == null || !_level2.enabled) return;
    final col = _level2.nameColumn;
    if (col < 0 || col >= headers.length) return;
    final label = headers[col].trim();
    if (label.isEmpty) return;
    _groupingAnlageParamKey = label;
    _groupingAnlageParamKeyCtrl.text = label;
  }

  int _nextFreeIndex(Iterable<int> values) {
    final used = values.toSet();
    var candidate = 0;
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  /// Diskret: Button zum Löschen (flexibel für Daten oder Vorlagen)
  Widget _buildBottomDeleteButton({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(buttonText, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                side: BorderSide(color: Colors.red.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bestätigt und löscht alle Gewerke und Anlagen
  Future<void> _confirmAndDeleteAll() async {
    // Sicherheitsabfrage
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Alle Daten löschen?'),
          ],
        ),
        content: const Text(
          'Möchten Sie wirklich ALLES für dieses Gebäude und Projekt löschen?\n\n'
          '• Alle Anlagen und Gewerke (Gebäude)\n'
          '• Alle Grundrisse/Ebenen\n'
          '• Alle Gewerkevorlagen (Projekt)\n'
          '• Gespeicherte CSV-Import-Struktur\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Lade-Dialog anzeigen
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final dbService = ref.read(databaseServiceProvider);
      
      // Lade das Gebäude, um die Grundrisse zu erhalten
      final building = await dbService.getBuildingById(widget.buildingId);
      if (building == null) throw Exception('Gebäude nicht gefunden');

      final disciplines = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      final floorsCount = building.floors.length;
      final anlagenCount =
          await dbService.countAllAnlagenRowsForBuilding(widget.buildingId);
      final templateCount = widget.projectId.isNotEmpty
          ? await dbService.countTemplatesByProjectId(widget.projectId)
          : 0;

      debugPrint(
        'Endgültiges Löschen: $anlagenCount Anlagen, ${disciplines.length} Gewerke, '
        '$floorsCount Grundrisse, $templateCount Vorlagen',
      );

      // 1. Alle Betriebsdaten endgültig aus der DB (inkl. soft-deleted Anlagen)
      await dbService.permanentlyDeleteAllBuildingOperationalData(
        widget.buildingId,
        floorPlansForFileCleanup: List.from(building.floors),
      );

      // 2. Gewerkevorlagen + globales Schema (projektweit)
      if (widget.projectId.isNotEmpty) {
        await dbService.permanentlyDeleteProjectImportData(widget.projectId);
        await TemplateService.clearTemplateImportHeaderRow(widget.projectId);
        await ref
            .read(csvSettingsProvider(widget.projectId).notifier)
            .clearAnlagenCsvImportStructure();
      }

      // 3. Grundrisse im Building-Modell leeren und persistieren
      building.floors.clear();
      await ref.read(projectsProvider.notifier).updateBuilding(building);

      // Alle SharedPreferences-Einträge für dieses Gebäude löschen
      final prefs = await SharedPreferences.getInstance();
      
      // Disziplinen-Initialisierungs-Flag löschen
      final disciplinesInitializedKey = 'disciplines_initialized_${widget.buildingId}';
      await prefs.remove(disciplinesInitializedKey);
      
      // Alle expanded_groups für alle Disziplinen dieses Gebäudes löschen
      // Da wir die Disziplinen bereits gelöscht haben, müssen wir alle möglichen Keys durchgehen
      // oder alle Keys mit dem Gebäude-Präfix finden
      final allKeys = prefs.getKeys();
      final buildingPrefix = 'expanded_groups_${widget.buildingId}_';
      final keysToRemove = allKeys.where((key) => key.startsWith(buildingPrefix)).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
        debugPrint('Gelöscht: $key');
      }
      
      // Fallback: Alte Disziplinen aus SharedPreferences löschen (falls vorhanden)
      final oldDisciplinesKey = 'disziplinen_${widget.buildingId}';
      await prefs.remove(oldDisciplinesKey);
      
      debugPrint('Alle SharedPreferences-Einträge für Gebäude ${widget.buildingId} gelöscht');

      // Disziplinen und Vorlagen neu laden
      if (mounted) {
        await _loadProjectTemplates();
        await _loadDisciplines();
        
        // Zusätzlich setState aufrufen, um sicherzustellen, dass die UI aktualisiert wird
        setState(() {
          // State wird bereits in _loadDisciplines aktualisiert, aber zur Sicherheit hier nochmal
          _showDisciplineSelection = true;
          _editingDisciplineIndex = null;
          _editingRevisionsobjekt = null;
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        final remainingDisciplines =
            await dbService.getDisciplinesByBuildingId(widget.buildingId);
        final remainingAnlagen =
            await dbService.countAllAnlagenRowsForBuilding(widget.buildingId);
        final remainingTemplates = widget.projectId.isNotEmpty
            ? await dbService.countTemplatesByProjectId(widget.projectId)
            : 0;

        debugPrint(
          'Nach dem Löschen: ${remainingDisciplines.length} Gewerke, '
          '$remainingAnlagen Anlagen, $remainingTemplates Vorlagen verbleibend',
        );

        if (remainingDisciplines.isNotEmpty ||
            remainingAnlagen > 0 ||
            remainingTemplates > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Warnung: Noch $remainingAnlagen Anlagen, '
                '${remainingDisciplines.length} Gewerke, '
                '$remainingTemplates Vorlagen in der DB.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Alle Gewerke, Anlagen, Grundrisse und Gewerkevorlagen wurden gelöscht.',
              ),
            ),
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Fehler beim Löschen aller Daten: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
    }
  }
}
