// lib/pages/csv_settings_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/csv_hierarchy_level.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../providers/database_provider.dart';
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
  int? _etageSpalte;
  int? _anlageBauteilSpalte;
  String _anlageKuerzel = 'A,Anlage';
  String _bauteilKuerzel = 'B,Bauteil';
  String _labelGewerk = 'Gewerk';
  String _labelAnlage = 'Anlage';
  String _labelBauteil = 'Bauteil';
  String _groupingEtageParamKey = '';
  String _groupingGewerkParamKey = '';
  String _groupingAnlageParamKey = '';

  /// Explizite Spaltenpaare: welche Spalte = Attributname, welche = Attributwert (pro Zeile variabel).
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
  late final TextEditingController _groupingEtageParamKeyCtrl;
  late final TextEditingController _groupingGewerkParamKeyCtrl;
  late final TextEditingController _groupingAnlageParamKeyCtrl;
  late final TextEditingController _foto1SpalteLabelCtrl;
  late final TextEditingController _foto2SpalteLabelCtrl;
  late final TextEditingController _foto3SpalteLabelCtrl;
  late final TextEditingController _foto4SpalteLabelCtrl;
  late final TextEditingController _attrPairGenStartCtrl;
  late final TextEditingController _attrPairGenEndCtrl;
  late final TextEditingController _templateAttrTripletGenStartCtrl;
  late final TextEditingController _templateAttrTripletGenEndCtrl;

  // Bearbeitbar-Flags (für Kompatibilität)
  bool _lfdNummerBearbeitbar = true;
  bool _nameBearbeitbar = true;
  bool _gewerkBearbeitbar = true;
  bool _etageBearbeitbar = true;
  bool _anlageBauteilBearbeitbar = true;
  bool _parameterBearbeitbar = true;

  bool _isLoading = true;
  List<Disziplin> _disciplines = [];
  List<Map<String, dynamic>> _globalSchema = [];
  bool _showDisciplineSelection = true;
  int? _editingDisciplineIndex;
  String? _editingRevisionsobjekt;
  bool _editingGlobal = false;
  final Set<int> _expandedSchemaDisciplineIndices = {};
  List<Template> _projectTemplates = [];
  
  // CSV Header für beide Tabs
  List<String>? _mappingCsvHeaders;
  List<String>? _templateCsvHeaders;
  
  // Template CSV Settings
  int _templateGewerkSpalte = 0;
  int _templateRevisionsobjektSpalte = 1;
  int _templateErsteSpalteAttributDefinitionen = 2;
  List<AttributeTripletColumn> _templateAttributeTriplets = [];

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
    _groupingEtageParamKeyCtrl = TextEditingController(text: _groupingEtageParamKey);
    _groupingGewerkParamKeyCtrl = TextEditingController(text: _groupingGewerkParamKey);
    _groupingAnlageParamKeyCtrl = TextEditingController(text: _groupingAnlageParamKey);
    _foto1SpalteLabelCtrl = TextEditingController(text: _foto1SpalteLabel ?? '');
    _foto2SpalteLabelCtrl = TextEditingController(text: _foto2SpalteLabel ?? '');
    _foto3SpalteLabelCtrl = TextEditingController(text: _foto3SpalteLabel ?? '');
    _foto4SpalteLabelCtrl = TextEditingController(text: _foto4SpalteLabel ?? '');
    _attrPairGenStartCtrl = TextEditingController(text: '24');
    _attrPairGenEndCtrl = TextEditingController(text: '63');
    _templateAttrTripletGenStartCtrl = TextEditingController(text: '3');
    _templateAttrTripletGenEndCtrl = TextEditingController(text: '62');
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
    _groupingEtageParamKeyCtrl.dispose();
    _groupingGewerkParamKeyCtrl.dispose();
    _groupingAnlageParamKeyCtrl.dispose();
    _foto1SpalteLabelCtrl.dispose();
    _foto2SpalteLabelCtrl.dispose();
    _foto3SpalteLabelCtrl.dispose();
    _foto4SpalteLabelCtrl.dispose();
    _attrPairGenStartCtrl.dispose();
    _attrPairGenEndCtrl.dispose();
    _templateAttrTripletGenStartCtrl.dispose();
    _templateAttrTripletGenEndCtrl.dispose();
    // Speichere beim Verlassen der Seite, falls noch nicht gespeichert
    _saveAllSettings();
    super.dispose();
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
    if (_groupingEtageParamKeyCtrl.text != _groupingEtageParamKey) {
      _groupingEtageParamKeyCtrl.value = TextEditingValue(
        text: _groupingEtageParamKey,
        selection: TextSelection.collapsed(offset: _groupingEtageParamKey.length),
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
      _loadTemplateCsvSettings(),
      _loadGlobalSchema(),
      _loadProjectTemplates(),
    ]);
    _syncGlobalSchemaToDisciplines();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGlobalSchema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'global_schema_${widget.projectId}';
      final schemaJson = prefs.getString(key);
      if (schemaJson != null) {
        setState(() {
          _globalSchema = (json.decode(schemaJson) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des globalen Schemas: $e');
    }
  }

  Future<void> _saveGlobalSchema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'global_schema_${widget.projectId}';
      await prefs.setString(key, json.encode(_globalSchema));
    } catch (e) {
      debugPrint('Fehler beim Speichern des globalen Schemas: $e');
    }
  }
  
  Future<void> _loadTemplateCsvSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'template_csv_settings_${widget.projectId}';
      final settingsJson = prefs.getString(key);
      
      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        final tripletsRaw = settings['attributeTripletColumns'];
        final triplets = <AttributeTripletColumn>[];
        if (tripletsRaw is List) {
          for (final e in tripletsRaw) {
            if (e is Map<String, dynamic>) {
              triplets.add(AttributeTripletColumn.fromJson(e));
            } else if (e is Map) {
              triplets.add(AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
        setState(() {
          _templateGewerkSpalte = settings['revisionsfeldSpalte'] as int? ??
              settings['gewerkSpalte'] as int? ??
              0;
          _templateRevisionsobjektSpalte = settings['revisionsobjektSpalte'] as int? ??
              settings['anlagentypSpalte'] as int? ??
              1;
          _templateErsteSpalteAttributDefinitionen =
              settings['ersteSpalteAttributDefinitionen'] as int? ?? 2;
          _templateAttributeTriplets = triplets;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Vorlagen-CSV-Einstellungen: $e');
    }
  }
  
  Future<void> _saveTemplateCsvSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'template_csv_settings_${widget.projectId}';
    final settings = {
      'gewerkSpalte': _templateGewerkSpalte,
      'revisionsfeldSpalte': _templateGewerkSpalte,
      'revisionsobjektSpalte': _templateRevisionsobjektSpalte,
      'anlagentypSpalte': _templateRevisionsobjektSpalte,
      'bezeichnungSpalte': _templateRevisionsobjektSpalte,
      'ersteSpalteAttributDefinitionen': _templateErsteSpalteAttributDefinitionen,
      'attributeTripletColumns': _templateAttributeTriplets.map((t) => t.toJson()).toList(),
    };
    await prefs.setString(key, json.encode(settings));
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
        _etageSpalte = settings.etageSpalte;
        _anlageBauteilSpalte = settings.anlageBauteilSpalte;
        _anlageKuerzel = settings.anlageKuerzel;
        _bauteilKuerzel = settings.bauteilKuerzel;
        _labelGewerk = settings.labelGewerk;
        _labelAnlage = settings.labelAnlage;
        _labelBauteil = settings.labelBauteil;
        _attributeColumnPairs = List<AttributeColumnPair>.from(settings.attributeColumnPairs);
        _foto1SpalteLabel = settings.foto1SpalteLabel;
        _foto2SpalteLabel = settings.foto2SpalteLabel;
        _foto3SpalteLabel = settings.foto3SpalteLabel;
        _foto4SpalteLabel = settings.foto4SpalteLabel;
        _groupingEtageParamKey = settings.groupingEtageParamKey;
        _groupingGewerkParamKey = settings.groupingGewerkParamKey;
        _groupingAnlageParamKey = settings.groupingAnlageParamKey;
      });
      _syncTextControllersFromState();
      _syncGroupingKeysFromLevels();

      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_${widget.projectId}';
      final settingsJson = prefs.getString(key);
      if (settingsJson != null) {
        final flags = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _lfdNummerBearbeitbar = flags['lfdNummerBearbeitbar'] as bool? ?? true;
          _nameBearbeitbar = flags['nameBearbeitbar'] as bool? ?? true;
          _gewerkBearbeitbar = flags['gewerkBearbeitbar'] as bool? ?? true;
          _etageBearbeitbar = flags['etageBearbeitbar'] as bool? ?? true;
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
      final loaded = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      setState(() {
        _disciplines = loaded;
      });
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
      if (t.gewerk.trim() == d.label.trim() && t.anlageBauteil == 'a') {
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
    if (d.revisionsobjektSchemas.isEmpty) {
      return d.legacyIndividualSchemaFields;
    }
    return const [];
  }

  // Entferne die Hilfsfunktion für automatisches Schema aus Mapping

  Future<void> _saveCsvSettings() async {
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      final current = ref.read(csvSettingsProvider(widget.projectId));
      final settings = CsvSettings(
        level1: _level1,
        level2: _level2,
        level3: _level3,
        etageSpalte: _etageSpalte,
        anlageBauteilSpalte: _anlageBauteilSpalte,
        delimiterMode: 'auto',
        anlageKuerzel: _anlageKuerzel,
        bauteilKuerzel: _bauteilKuerzel,
        useDisciplineGrouping: _level1.enabled,
        labelGewerk: _labelGewerk,
        labelAnlage: _labelAnlage,
        labelBauteil: _labelBauteil,
        attributeColumnPairs: List<AttributeColumnPair>.from(_attributeColumnPairs),
        foto1SpalteLabel: _foto1SpalteLabel,
        foto2SpalteLabel: _foto2SpalteLabel,
        foto3SpalteLabel: _foto3SpalteLabel,
        foto4SpalteLabel: _foto4SpalteLabel,
        importHeaderRow: current.importHeaderRow,
        exportDelimiter: current.exportDelimiter,
        groupingEtageParamKey: _groupingEtageParamKey,
        groupingGewerkParamKey: _groupingGewerkParamKey,
        groupingAnlageParamKey: _groupingAnlageParamKey,
      );
      await notifier.save(settings);

      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_${widget.projectId}';
      final flags = {
        'lfdNummerBearbeitbar': _lfdNummerBearbeitbar,
        'nameBearbeitbar': _nameBearbeitbar,
        'gewerkBearbeitbar': _gewerkBearbeitbar,
        'etageBearbeitbar': _etageBearbeitbar,
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
    if (_isSaving) return; // Verhindere gleichzeitige Speichervorgänge
    
    _isSaving = true;
    try {
      await Future.wait([
        _saveCsvSettings(),
        _saveDisciplines(),
        _saveTemplateCsvSettings(),
        _saveGlobalSchema(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einstellungen gespeichert'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Fehler beim automatischen Speichern: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  /// Plant automatisches Speichern nach einer kurzen Verzögerung
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveAllSettings();
    });
  }

  Future<void> _saveDisciplines() async {
    _syncGlobalSchemaToDisciplines();
    final dbService = ref.read(databaseServiceProvider);
    await dbService.replaceDisciplines(widget.buildingId, _disciplines);
  }

  void _syncGlobalSchemaToDisciplines() {
    final markedGlobalSchema =
        _globalSchema.map((f) => {...f, 'isGlobal': true}).toList();
    final globalKeys = markedGlobalSchema.map((f) => f['key']).toSet();

    for (int i = 0; i < _disciplines.length; i++) {
      final d = _disciplines[i];
      final newSchema = markedGlobalSchema
          .map((f) => Map<String, dynamic>.from(f))
          .toList();

      final legacyIndividual = d.schema
          .where((f) => f['isGlobal'] != true && !globalKeys.contains(f['key']))
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
      if (legacyIndividual.isNotEmpty && d.revisionsobjektSchemas.isEmpty) {
        newSchema.addAll(legacyIndividual);
      }

      final newRoSchemas = <String, List<Map<String, dynamic>>>{};
      d.revisionsobjektSchemas.forEach((ro, fields) {
        newRoSchemas[ro] = fields
            .where((f) => !globalKeys.contains(f['key']))
            .map((f) => Map<String, dynamic>.from(f))
            .toList();
      });

      _disciplines[i] = Disziplin(
        label: d.label,
        icon: d.icon,
        color: d.color,
        schema: newSchema,
        groupingKey: d.groupingKey,
        revisionsobjektSchemas: newRoSchemas,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'CSV Einstellungen',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'CSV-Mapping'),
              Tab(icon: Icon(Icons.schema), text: 'Eingabefelder'),
              Tab(icon: Icon(Icons.table_view), text: 'Gewerkevorlagen'),
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
                  _buildTemplateTab(),
                ],
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
          _buildConnector(),
          SettingsCard(
            color: Colors.cyan,
            borderColor: Colors.cyan.shade200,
            icon: Icons.layers,
            iconColor: Colors.cyan,
            title: 'Etage (optional)',
            description: 'Separate Spalte, nicht Teil der Hierarchie-Ebenen.',
            child: _buildToggleRow(
              icon: Icons.layers,
              label: 'Spalte für Etage?',
              isActive: _etageSpalte != null,
              onToggle: (val) {
                setState(() {
                  _etageSpalte = val ? _nextFreeIndex(_allReservedColumnIndices()) : null;
                  if (val) _syncGroupingEtageKeyFromColumn();
                });
                _scheduleAutoSave();
              },
              child: _etageSpalte != null
                  ? _buildColumnSelector(
                      label: 'Spalte Etage',
                      value: _etageSpalte!,
                      onChanged: (v) {
                        setState(() {
                          _etageSpalte = v;
                          _syncGroupingEtageKeyFromColumn();
                        });
                        _scheduleAutoSave();
                      },
                      csvHeaders: _mappingCsvHeaders,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          _buildCollapsibleAttributePairsSection(),
          const SizedBox(height: 16),
          SettingsCard(
            color: Colors.teal,
            borderColor: Colors.teal.shade200,
            icon: Icons.photo_library,
            iconColor: Colors.teal,
            title: 'Fotonummern-Spalten (Export)',
            description: 'Spalten-Labels Ihrer CSV, in die beim Export die Fotonummern (1–4) geschrieben werden. Beim Import können diese Spalten leer sein. Leer lassen = Spalte nicht verwenden.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Begriffe der Ebenen anpassen'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              TextField(
                controller: _labelGewerkCtrl,
                decoration: InputDecoration(
                  labelText: 'Bezeichnung Ebene 1',
                  helperText: 'Standard: Gewerk',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  setState(() => _labelGewerk = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelAnlageCtrl,
                decoration: InputDecoration(
                  labelText: 'Bezeichnung Ebene 2',
                  helperText: 'Standard: Anlage',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  setState(() => _labelAnlage = val);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelBauteilCtrl,
                decoration: InputDecoration(
                  labelText: 'Bezeichnung Ebene 3',
                  helperText: 'Standard: Bauteil',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  setState(() => _labelBauteil = val);
                  _scheduleAutoSave();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildValidationWarning(),
          const SizedBox(height: 32),
          // Beta-Funktion: Beispiel-CSV laden (ausgeblendet, nur als kleine Option)
          _buildBetaCsvLoader(forTemplate: false),
          const SizedBox(height: 24),
          // Diskret: Alle Gewerke, Anlagen und Grundrisse löschen
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
    if (_disciplines.isEmpty && _globalSchema.isEmpty) {
      // Wenn alles leer ist, lade Standard-Heizung als Basis für Global wenn nichts da ist
      // Aber eigentlich sollte der User einfach starten können.
    }

    if (!_showDisciplineSelection) {
      if (_editingGlobal) {
        return Column(
          children: [
            _buildBackToSelectionHeader('Globales Standard-Schema'),
            Expanded(
              child: SchemaEditorWidget(
                existingSchema: _globalSchema,
                allowEditGlobal: true,
                onSchemaChanged: (newSchema) {
                  setState(() {
                    _globalSchema = newSchema.map((f) => {...f, 'isGlobal': true}).toList();
                    _syncGlobalSchemaToDisciplines();
                  });
                  _scheduleAutoSave();
                },
              ),
            ),
          ],
        );
      } else if (_editingDisciplineIndex != null &&
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
    }

    return _buildSchemaSelectionView();
  }

  Widget _buildBackToSelectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _showDisciplineSelection = true;
              _editingGlobal = false;
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
          
          // GLOBAL CARD
          _buildSelectionCard(
            title: 'Globales Standard-Schema',
            icon: Icons.public,
            color: Colors.blue,
            onTap: () => setState(() {
              _showDisciplineSelection = false;
              _editingGlobal = true;
            }),
          ),
          
          const SizedBox(height: 32),
          Text(
            _labelGewerk,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Entspricht Ebene 1 im CSV-Mapping (${_hierarchySubtitle()}). '
            '$_labelGewerk aufklappen, dann $_schemaItemLevelLabel wählen, um dessen Attribute zu bearbeiten.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          if (_disciplines.isEmpty)
            const Center(child: Text('Keine Gewerke vorhanden'))
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
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
                            ? 'Keine $_schemaItemLevelLabel'
                            : '${roList.length} $_schemaItemLevelLabel',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        if (roList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              'Importieren Sie Gewerkevorlagen, damit $_schemaItemLevelLabel-Einträge erscheinen.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
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
                                Icons.category_outlined,
                                color: d.color.withOpacity(0.8),
                                size: 20,
                              ),
                              title: Text(ro),
                              subtitle: Text(
                                '${_schemaForRevisionsobjekt(d, ro).length} Felder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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

  Widget _buildSelectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: (subtitle != null && subtitle.isNotEmpty) ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // --- TEMPLATE TAB ---

  Widget _buildTemplateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Ordnen Sie hier fest, welche CSV-Spalten in der App welche Bedeutung haben. '
                'Geben Sie die Spaltennummern manuell ein (Start bei 1).',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildHeaderAction(
              icon: Icons.upload_file,
              label: 'Vorlagen importieren',
              onPressed: _importTemplates,
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            title: 'CSV-Mapping für Vorlagen',
            subtitle: 'Revisionsfeld → Revisionsobjekt → Attribute',
          ),
          const SizedBox(height: 16),

          SettingsCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: 'Revisionsfeld',
            description: 'Welche Spalte enthält das Revisionsfeld (Gewerk)?',
            child: _buildTemplateColumnSelector(
              label: 'Spalte für Revisionsfeld',
              value: _templateGewerkSpalte,
              onChanged: (v) {
                setState(() => _templateGewerkSpalte = v);
                _scheduleAutoSave();
              },
            ),
          ),

          _buildConnector(),

          SettingsCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: 'Revisionsobjekt',
            description: 'Welche Spalte enthält das Revisionsobjekt (Anlagentyp)?',
            child: _buildTemplateColumnSelector(
              label: 'Spalte für Revisionsobjekt',
              value: _templateRevisionsobjektSpalte,
              onChanged: (v) {
                setState(() => _templateRevisionsobjektSpalte = v);
                _scheduleAutoSave();
              },
            ),
          ),

          const SizedBox(height: 16),
          _buildCollapsibleAttributeTripletsSection(),
          
          const SizedBox(height: 24),
          _buildTemplateValidationWarning(),
          const SizedBox(height: 32),
          // Beta-Funktion: Beispiel-CSV laden (ausgeblendet, nur als kleine Option)
          _buildBetaCsvLoader(forTemplate: true),
          const SizedBox(height: 24),
          // Diskret: Vorlagen für das Projekt löschen
          _buildBottomDeleteButton(
            title: 'Alle Vorlagen löschen',
            description: 'Löscht alle importierten Vorlagen für dieses Projekt. Gewerke und Anlagen im Gebäude bleiben erhalten.',
            buttonText: 'Vorlagen löschen',
            onPressed: () => _confirmAndDeleteTemplates(),
          ),
        ],
      ),
    );
  }


  Widget _buildTemplateColumnSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    String? keySuffix,
  }) {
    final fieldKey = keySuffix ?? label;

    if (_templateCsvHeaders != null &&
        _templateCsvHeaders!.isNotEmpty &&
        value >= 0 &&
        value < _templateCsvHeaders!.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            key: ValueKey('template_col_dropdown_${fieldKey}_$value'),
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: List.generate(_templateCsvHeaders!.length, (index) {
              return DropdownMenuItem(
                value: index,
                child: Text(
                  '${index + 1}: ${_templateCsvHeaders![index]}',
                  overflow: TextOverflow.ellipsis,
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
      key: ValueKey('template_col_input_${fieldKey}_$value'),
      initialValue: (value + 1).toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.view_column, size: 18),
        helperText: _templateCsvHeaders != null && value >= _templateCsvHeaders!.length
            ? 'Spalte ${value + 1} liegt außerhalb der geladenen CSV (${_templateCsvHeaders!.length} Spalten)'
            : null,
      ),
      onFieldSubmitted: (text) {
        final userInput = int.tryParse(text.trim());
        if (userInput != null && userInput > 0) {
          onChanged(userInput - 1);
        }
      },
    );
  }

  Widget _buildCollapsibleAttributeTripletsSection() {
    const color = Colors.deepPurple;
    final tripletCount = _templateAttributeTriplets.length;
    final subtitle = tripletCount == 0
        ? 'Keine Dreiergruppen – zum Konfigurieren aufklappen'
        : '$tripletCount Dreiergruppe${tripletCount == 1 ? '' : 'n'} konfiguriert';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_column, color: color, size: 24),
          ),
          title: const Text(
            'Attribut-Dreiergruppen',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          children: [
            Text(
              'CSV-Spalten für Attributdefinitionen: Name (z. B. ATT1), Typ (z. B. ATT1_TYPE), '
              'Optionen (z. B. ATT1_OPTIONS). Pro Attribut eine Dreiergruppe.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                    'Dreiergruppen aus Spaltenbereich erzeugen',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Spaltennummern wie in der Dropdown-Anzeige (1 = erste Spalte). '
                    'Reihenfolge: Name, Typ, Optionen (z. B. 3–62 → ATT1/ATT1_TYPE/ATT1_OPTIONS, ATT2/…). '
                    'Spaltenanzahl im Bereich muss durch 3 teilbar sein.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
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
                          controller: _templateAttrTripletGenStartCtrl,
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
                          controller: _templateAttrTripletGenEndCtrl,
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
                        label: const Text('Dreiergruppen generieren'),
                        onPressed: () {
                          final start = int.tryParse(_templateAttrTripletGenStartCtrl.text.trim());
                          final end = int.tryParse(_templateAttrTripletGenEndCtrl.text.trim());
                          if (start == null || end == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bitte gültige Zahlen für erste und letzte Spalte eingeben.'),
                              ),
                            );
                            return;
                          }
                          if (start >= end) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Letzte Spalte muss größer als die erste sein.'),
                              ),
                            );
                            return;
                          }
                          final count = end - start + 1;
                          if (count % 3 != 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Spaltenanzahl im Bereich muss durch 3 teilbar sein (aktuell: $count).',
                                ),
                              ),
                            );
                            return;
                          }
                          // Eingabe ist 1-basiert (wie Dropdown-Anzeige), intern 0-basiert speichern
                          final startIndex = start - 1;
                          final endIndex = end - 1;
                          final triplets = <AttributeTripletColumn>[];
                          for (var i = startIndex; i <= endIndex; i += 3) {
                            triplets.add(AttributeTripletColumn(
                              nameColumn: i,
                              typeColumn: i + 1,
                              optionsColumn: i + 2,
                            ));
                          }
                          setState(() {
                            _templateAttributeTriplets = triplets;
                            _templateErsteSpalteAttributDefinitionen = startIndex;
                          });
                          _scheduleAutoSave();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${triplets.length} Dreiergruppen generiert (Spalten $start–$end).',
                              ),
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
            ...List.generate(_templateAttributeTriplets.length, (idx) {
              final triplet = _templateAttributeTriplets[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attribut ${idx + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTemplateColumnSelector(
                            label: 'Spalte Name',
                            keySuffix: 'attr_${idx}_name',
                            value: triplet.nameColumn,
                            onChanged: (v) {
                              setState(() {
                                _templateAttributeTriplets = List<AttributeTripletColumn>.from(_templateAttributeTriplets)
                                  ..[idx] = AttributeTripletColumn(
                                    nameColumn: v,
                                    typeColumn: triplet.typeColumn,
                                    optionsColumn: triplet.optionsColumn,
                                  );
                              });
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTemplateColumnSelector(
                            label: 'Spalte Typ',
                            keySuffix: 'attr_${idx}_type',
                            value: triplet.typeColumn,
                            onChanged: (v) {
                              setState(() {
                                _templateAttributeTriplets = List<AttributeTripletColumn>.from(_templateAttributeTriplets)
                                  ..[idx] = AttributeTripletColumn(
                                    nameColumn: triplet.nameColumn,
                                    typeColumn: v,
                                    optionsColumn: triplet.optionsColumn,
                                  );
                              });
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTemplateColumnSelector(
                            label: 'Spalte Optionen',
                            keySuffix: 'attr_${idx}_options',
                            value: triplet.optionsColumn,
                            onChanged: (v) {
                              setState(() {
                                _templateAttributeTriplets = List<AttributeTripletColumn>.from(_templateAttributeTriplets)
                                  ..[idx] = AttributeTripletColumn(
                                    nameColumn: triplet.nameColumn,
                                    typeColumn: triplet.typeColumn,
                                    optionsColumn: v,
                                  );
                              });
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _templateAttributeTriplets = List<AttributeTripletColumn>.from(_templateAttributeTriplets)
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
              label: const Text('Dreiergruppe hinzufügen'),
              onPressed: () {
                final maxCol = (_templateCsvHeaders?.length ?? 20) - 1;
                final used = _allReservedTemplateColumnIndices().toSet();
                var n = 0;
                while (used.contains(n) && n <= maxCol) n++;
                var t = n + 1;
                while (used.contains(t) && t <= maxCol) t++;
                var o = t + 1;
                while (used.contains(o) && o <= maxCol) o++;
                setState(() {
                  _templateAttributeTriplets = List<AttributeTripletColumn>.from(_templateAttributeTriplets)
                    ..add(AttributeTripletColumn(nameColumn: n, typeColumn: t, optionsColumn: o));
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _allReservedTemplateColumnIndices() {
    final used = <int>{
      _templateGewerkSpalte,
      _templateRevisionsobjektSpalte,
    };
    for (final t in _templateAttributeTriplets) {
      used.add(t.nameColumn);
      used.add(t.typeColumn);
      used.add(t.optionsColumn);
    }
    return used;
  }

  Widget _buildTemplateValidationWarning() {
    final values = <int>[
      _templateGewerkSpalte,
      _templateRevisionsobjektSpalte,
    ];
    for (final t in _templateAttributeTriplets) {
      values.addAll([t.nameColumn, t.typeColumn, t.optionsColumn]);
    }
    final uniqueValues = values.toSet();
    
    if (values.length != uniqueValues.length) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Achtung: Eine Spaltennummer wurde mehrfach vergeben!',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
      final count = await TemplateService.importTemplatesFromCsv(
        ref.read(databaseServiceProvider),
        widget.projectId,
        null,
        buildingId: widget.buildingId,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        await Future.wait([
          _loadDisciplines(),
          _loadProjectTemplates(),
        ]);
        _syncGlobalSchemaToDisciplines();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count Vorlagen erfolgreich importiert'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      
      // Vorlagen löschen
      await dbService.deleteTemplatesByProjectId(widget.projectId);
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Vorlagen erfolgreich gelöscht'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Fehler beim Löschen der Vorlagen: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // --- HELPERS ---

  Widget _buildConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Container(height: 20, width: 2, color: Colors.grey.shade300),
    );
  }


  /// Lädt nur die Header-Zeile einer CSV für die Vorschau
  Future<void> _loadExampleCsvHeaders({required bool forTemplate}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      // Encoding Erkennung (wie in CsvService)
      String csvString;
      try {
        csvString = utf8.decode(bytes);
      } catch (_) {
        csvString = latin1.decode(bytes);
      }

      // Nur die erste Zeile parsen
      final eolIndex = csvString.indexOf('\n');
      final headerLine = eolIndex != -1 ? csvString.substring(0, eolIndex) : csvString;
      
      // Automatische Trennzeichen-Erkennung
      String delimiter = ';';
      if (headerLine.contains(',') && !headerLine.contains(';')) {
        delimiter = ',';
      } else if (headerLine.contains('\t')) {
        delimiter = '\t';
      }

      final List<List<dynamic>> rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        shouldParseNumbers: false,
      ).convert(headerLine);

      if (rows.isNotEmpty) {
        setState(() {
          if (forTemplate) {
            _templateCsvHeaders = rows.first.map((e) => e.toString().trim()).toList();
          } else {
            _mappingCsvHeaders = rows.first.map((e) => e.toString().trim()).toList();
          }
        });
        
        if (mounted) {
          final headers = forTemplate ? _templateCsvHeaders : _mappingCsvHeaders;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${headers!.length} Spalten erkannt. Dropdown-Modus aktiv.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Lesen der CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFotoSpalteField(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'z.B. Foto1 oder Spaltenname aus Ihrer CSV',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: onChanged,
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
            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
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

  Widget _buildCollapsibleAttributePairsSection() {
    const color = Colors.deepPurple;
    final pairCount = _attributeColumnPairs.length;
    final subtitle = pairCount == 0
        ? 'Keine Paare – zum Konfigurieren aufklappen'
        : '$pairCount Paar${pairCount == 1 ? '' : 'e'} konfiguriert';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_column, color: color, size: 24),
          ),
          title: const Text(
            'Attribut-Spaltenpaare',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          children: [
            Text(
              'CSV-Spalten, in denen pro Zeile Attributname und Attributwert stehen. '
              'Jedes Paar: eine Spalte für den Namen, eine für den Wert.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                    'Paare aus Spaltenbereich erzeugen',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Erste Spalte = Attributname, nächste = Attributwert (z. B. 24–63 → Paare 24/25, 26/27, …). '
                    'Gerade Anzahl Spalten im Bereich nötig.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
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
                        label: const Text('Paare generieren'),
                        onPressed: () {
                          final start = int.tryParse(_attrPairGenStartCtrl.text.trim());
                          final end = int.tryParse(_attrPairGenEndCtrl.text.trim());
                          if (start == null || end == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bitte gültige Zahlen für erste und letzte Spalte eingeben.'),
                              ),
                            );
                            return;
                          }
                          if (start >= end) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Letzte Spalte muss größer als die erste sein.'),
                              ),
                            );
                            return;
                          }
                          final count = end - start + 1;
                          if (count.isOdd) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Spaltenanzahl im Bereich muss gerade sein (aktuell: $count).',
                                ),
                              ),
                            );
                            return;
                          }
                          final pairs = <AttributeColumnPair>[];
                          for (var i = start; i < end; i += 2) {
                            pairs.add(AttributeColumnPair(nameColumn: i, valueColumn: i + 1));
                          }
                          setState(() => _attributeColumnPairs = pairs);
                          _scheduleAutoSave();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${pairs.length} Paare generiert (Spalten $start–$end).')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_attributeColumnPairs.length, (idx) {
              final pair = _attributeColumnPairs[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildColumnSelector(
                        label: 'Spalte Attributname',
                        value: pair.nameColumn,
                        onChanged: (v) {
                          setState(() {
                            _attributeColumnPairs = List<AttributeColumnPair>.from(_attributeColumnPairs)
                              ..[idx] = AttributeColumnPair(nameColumn: v, valueColumn: pair.valueColumn);
                          });
                          _scheduleAutoSave();
                        },
                        csvHeaders: _mappingCsvHeaders,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildColumnSelector(
                        label: 'Spalte Attributwert',
                        value: pair.valueColumn,
                        onChanged: (v) {
                          setState(() {
                            _attributeColumnPairs = List<AttributeColumnPair>.from(_attributeColumnPairs)
                              ..[idx] = AttributeColumnPair(nameColumn: pair.nameColumn, valueColumn: v);
                          });
                          _scheduleAutoSave();
                        },
                        csvHeaders: _mappingCsvHeaders,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _attributeColumnPairs = List<AttributeColumnPair>.from(_attributeColumnPairs)
                            ..removeAt(idx);
                        });
                        _scheduleAutoSave();
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Paar hinzufügen'),
              onPressed: () {
                final maxCol = (_mappingCsvHeaders?.length ?? 10) - 1;
                final used = _allReservedColumnIndices().toSet();
                for (final p in _attributeColumnPairs) {
                  used.add(p.nameColumn);
                  used.add(p.valueColumn);
                }
                var n = 0;
                while (used.contains(n) && n <= maxCol) n++;
                var v = n + 1;
                while (used.contains(v) && v <= maxCol) v++;
                if (v > maxCol) v = n;
                setState(() {
                  _attributeColumnPairs = List<AttributeColumnPair>.from(_attributeColumnPairs)
                    ..add(AttributeColumnPair(nameColumn: n, valueColumn: v));
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
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

  /// Spalten der Hierarchie-Ebenen + Etage (ohne Attribut-Paare).
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
    if (_etageSpalte != null) used.add(_etageSpalte!);
    if (_anlageBauteilSpalte != null) used.add(_anlageBauteilSpalte!);
    return used;
  }

  /// Alle reservierten Spalten inkl. Attribut-Paare (für freie Spalte suchen).
  List<int> _allReservedColumnIndices() {
    final used = _mappingColumnIndices();
    for (final p in _attributeColumnPairs) {
      used.add(p.nameColumn);
      used.add(p.valueColumn);
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
    if (_etageSpalte != null) {
      mapCol(_etageSpalte!, 'Etage');
    }

    for (final e in mappingByCol.entries) {
      if (e.value.length > 1) {
        conflicts.add('Spalte ${_columnLabel(e.key)}: ${e.value.join(', ')}');
      }
    }

    for (var i = 0; i < _attributeColumnPairs.length; i++) {
      final p = _attributeColumnPairs[i];
      final pairLabel = 'Attribut-Paar ${i + 1}';
      if (p.nameColumn == p.valueColumn) {
        conflicts.add(
          'Spalte ${_columnLabel(p.nameColumn)}: Name und Wert im $pairLabel identisch',
        );
      }
      for (final e in mappingByCol.entries) {
        if (e.key == p.nameColumn) {
          conflicts.add(
            'Spalte ${_columnLabel(e.key)}: ${e.value.join(', ')} und $pairLabel (Name)',
          );
        }
        if (e.key == p.valueColumn) {
          conflicts.add(
            'Spalte ${_columnLabel(e.key)}: ${e.value.join(', ')} und $pairLabel (Wert)',
          );
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
              style: TextStyle(color: Colors.grey[800], fontSize: 13),
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
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _syncGroupingEtageKeyFromColumn() {
    final headers = _mappingCsvHeaders;
    final col = _etageSpalte;
    if (headers == null || col == null || col < 0 || col >= headers.length) return;
    final label = headers[col].trim();
    if (label.isEmpty) return;
    _groupingEtageParamKey = label;
    _groupingEtageParamKeyCtrl.text = label;
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
    if (headers == null || !_level2.enabled || !_level3.enabled) return;
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

  /// Beta-Funktion: Kleine Option ganz unten zum Laden einer Beispiel-CSV
  Widget _buildBetaCsvLoader({required bool forTemplate}) {
    final headers = forTemplate ? _templateCsvHeaders : _mappingCsvHeaders;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BETA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Beispiel-CSV laden (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _loadExampleCsvHeaders(forTemplate: forTemplate),
                  icon: Icon(
                    headers == null ? Icons.table_chart_outlined : Icons.refresh,
                    size: 16,
                  ),
                  label: Text(
                    headers == null ? 'CSV laden' : 'Neu laden',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),
              if (headers != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (forTemplate) {
                        _templateCsvHeaders = null;
                      } else {
                        _mappingCsvHeaders = null;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dropdown-Modus deaktiviert'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Aus', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ],
            ],
          ),
          if (headers != null) ...[
            const SizedBox(height: 8),
            Text(
              '${headers.length} Spalten geladen - Dropdowns aktiv',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
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
          'Möchten Sie wirklich ALLE Gewerke, Anlagen und Grundrisse (Ebenen) für dieses Gebäude löschen?\n\n'
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

      // Anzahl vor dem Löschen speichern für die Meldung
      final anlagen = await dbService.getAnlagenByBuildingId(widget.buildingId);
      final disciplines = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      final floorsCount = building.floors.length;
      final anlagenCount = anlagen.length;
      final disciplinesCount = disciplines.length;
      
      debugPrint('Lösche $anlagenCount Anlagen, $disciplinesCount Gewerke und $floorsCount Grundrisse für Gebäude ${widget.buildingId}');
      
      // 1. Alle Grundrisse löschen (Dateisystem + Liste im Building)
      // Wir löschen die Dateien physisch vom Gerät
      for (final floor in building.floors) {
        if (floor.pdfPath != null) {
          final file = File(floor.pdfPath!);
          if (await file.exists()) {
            try {
              await file.delete();
              debugPrint('Datei gelöscht: ${floor.pdfPath}');
            } catch (e) {
              debugPrint('Fehler beim Löschen der Datei ${floor.pdfPath}: $e');
            }
          }
        }
      }
      
      // Liste der Grundrisse im Building-Objekt leeren
      building.floors.clear();
      
      // 2. Gebäude in DB und Provider aktualisieren
      // Dies löscht die Einträge aus der floorPlans-Tabelle in der DB
      // und informiert alle Listener (wie BuildingDetailsPage), dass sich das Gebäude geändert hat
      await ref.read(projectsProvider.notifier).updateBuilding(building);

      // 3. Alle Anlagen für dieses Gebäude löschen
      for (final anlage in anlagen) {
        await dbService.deleteAnlage(anlage.id);
      }

      // 4. Alle Disziplinen für dieses Gebäude löschen (mit replaceDisciplines mit leerer Liste)
      await dbService.replaceDisciplines(widget.buildingId, []);
      
      // Cache explizit leeren (wird zwar schon in replaceDisciplines gemacht, aber zur Sicherheit)
      // Der Cache wird in _getDisciplinesMap verwendet, daher müssen wir sicherstellen, dass er leer ist
      
      // Warte kurz, damit die Datenbank-Operation abgeschlossen ist
      await Future.delayed(const Duration(milliseconds: 200));
      
      debugPrint('Alle Disziplinen gelöscht. Lade Disziplinen neu...');
      
      // Verifiziere, dass wirklich alle Disziplinen gelöscht wurden
      final verifyDisciplines = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      if (verifyDisciplines.isNotEmpty) {
        debugPrint('WARNUNG: Nach dem Löschen sind noch ${verifyDisciplines.length} Disziplinen vorhanden!');
        // Versuche es nochmal mit explizitem Löschen
        for (final disc in verifyDisciplines) {
          await dbService.deleteDiscipline(widget.buildingId, disc.label);
        }
        await dbService.replaceDisciplines(widget.buildingId, []);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Alle SharedPreferences-Einträge für dieses Gebäude löschen
      final prefs = await SharedPreferences.getInstance();
      
      // Globales Schema löschen
      if (mounted) {
        setState(() {
          _globalSchema = [];
        });
        final globalSchemaKey = 'global_schema_${widget.projectId}';
        await prefs.remove(globalSchemaKey);
      }
      
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

      // Disziplinen neu laden und State aktualisieren
      if (mounted) {
        await _loadDisciplines();
        
        // Zusätzlich setState aufrufen, um sicherzustellen, dass die UI aktualisiert wird
        setState(() {
          // State wird bereits in _loadDisciplines aktualisiert, aber zur Sicherheit hier nochmal
          _showDisciplineSelection = true;
          _editingDisciplineIndex = null;
          _editingRevisionsobjekt = null;
          _editingGlobal = false;
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        // Prüfen, ob wirklich alle gelöscht wurden
        final remainingDisciplines = await dbService.getDisciplinesByBuildingId(widget.buildingId);
        final remainingAnlagen = await dbService.getAnlagenByBuildingId(widget.buildingId);
        
        debugPrint('Nach dem Löschen: ${remainingDisciplines.length} Gewerke, ${remainingAnlagen.length} Anlagen verbleibend');
        
        // Wenn noch Disziplinen vorhanden sind, zeige Warnung
        if (remainingDisciplines.isNotEmpty) {
          debugPrint('FEHLER: Es sind noch Disziplinen vorhanden: ${remainingDisciplines.map((d) => d.label).join(", ")}');
          for (final disc in remainingDisciplines) {
            debugPrint('  - ${disc.label} (groupingKey: ${disc.groupingKey})');
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remainingDisciplines.isEmpty && remainingAnlagen.isEmpty
                  ? '$anlagenCount Anlagen, $disciplinesCount Gewerke und $floorsCount Grundrisse gelöscht'
                  : '$anlagenCount Anlagen, $disciplinesCount Gewerke und $floorsCount Grundrisse gelöscht. Bitte App neu starten, um Änderungen zu sehen.',
            ),
            backgroundColor: remainingDisciplines.isEmpty && remainingAnlagen.isEmpty ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Seite schließen, damit beim nächsten Öffnen alles neu geladen wird
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Fehler beim Löschen aller Daten: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
