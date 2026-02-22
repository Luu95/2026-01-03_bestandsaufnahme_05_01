// lib/pages/csv_settings_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../providers/database_provider.dart';
import '../services/dropdown_csv_service.dart';
import '../services/template_service.dart';
import '../providers/projects_provider.dart';
import 'widgets/schema_editor_dialog.dart';
import 'widgets/settings_card.dart';
import '../utils/app_log.dart';
import '../utils/csv_utils.dart';

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
  // Standardwerte für CSV-Mapping
  int _lfdNummerSpalte = 0;
  int _nameSpalte = 1;
  int _gewerkSpalte = 2;
  int? _etageSpalte;
  int? _anlageBauteilSpalte;
  int? _parameterSpalte;
  String _delimiterMode = 'auto';
  String _anlageKuerzel = 'A,Anlage';
  String _bauteilKuerzel = 'B,Bauteil';
  bool _useDisciplineGrouping = true;
  String _labelGewerk = 'Gewerk';
  String _labelAnlage = 'Anlage';
  String _labelBauteil = 'Bauteil';

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
  bool _editingGlobal = false;
  
  // CSV Header für beide Tabs
  List<String>? _mappingCsvHeaders;
  List<String>? _templateCsvHeaders;
  
  // Dropdown-CSV (für Schema-Felder vom Typ "Dropdown")
  String? _dropdownCsvPath;
  List<String>? _dropdownCsvHeaders;
  Map<String, List<String>> _dropdownValuesByHeader = {};
  String? _dropdownCsvError;
  bool _dropdownIsLoading = false;
  
  // Template CSV Settings
  int _templateGewerkSpalte = 0;
  int _templateAnlageBauteilSpalte = 1;
  int _templateAnlagentypSpalte = 2;
  int _templateBezeichnungSpalte = 3;
  int _templateParameterSpalte = 4;
  int? _templateAuswahlAnlagentypSpalte;

  // Auto-Save Timer
  Timer? _autoSaveTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // Speichere beim Verlassen der Seite, falls noch nicht gespeichert
    _saveAllSettings();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCsvSettings(),
      _loadDisciplines(),
      _loadTemplateCsvSettings(),
      _loadGlobalSchema(),
      _loadDropdownCsvSettings(),
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
        setState(() {
          _templateGewerkSpalte = settings['gewerkSpalte'] as int? ?? 0;
          _templateAnlageBauteilSpalte = settings['anlageBauteilSpalte'] as int? ?? 1;
          _templateAnlagentypSpalte = settings['anlagentypSpalte'] as int? ?? 2;
          _templateBezeichnungSpalte = settings['bezeichnungSpalte'] as int? ?? 3;
          _templateParameterSpalte = settings['parameterSpalte'] as int? ?? 4;
          _templateAuswahlAnlagentypSpalte = settings['auswahlAnlagentypSpalte'] as int?;
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
      'anlageBauteilSpalte': _templateAnlageBauteilSpalte,
      'anlagentypSpalte': _templateAnlagentypSpalte,
      'bezeichnungSpalte': _templateBezeichnungSpalte,
      'parameterSpalte': _templateParameterSpalte,
      'auswahlAnlagentypSpalte': _templateAuswahlAnlagentypSpalte,
    };
    await prefs.setString(key, json.encode(settings));
  }

  Future<void> _loadCsvSettings() async {
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      await notifier.load();
      final settings = ref.read(csvSettingsProvider(widget.projectId));
      setState(() {
        _lfdNummerSpalte = settings.lfdNummerSpalte;
        _nameSpalte = settings.nameSpalte;
        _gewerkSpalte = settings.gewerkSpalte;
        _etageSpalte = settings.etageSpalte;
        _anlageBauteilSpalte = settings.anlageBauteilSpalte;
        _parameterSpalte = settings.parameterSpalte;
        _delimiterMode = settings.delimiterMode;
        _anlageKuerzel = settings.anlageKuerzel;
        _bauteilKuerzel = settings.bauteilKuerzel;
        _useDisciplineGrouping = settings.useDisciplineGrouping;
        _labelGewerk = settings.labelGewerk;
        _labelAnlage = settings.labelAnlage;
        _labelBauteil = settings.labelBauteil;
      });

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

  // Entferne die Hilfsfunktion für automatisches Schema aus Mapping

  Future<void> _saveCsvSettings() async {
    try {
      final notifier = ref.read(csvSettingsProvider(widget.projectId).notifier);
      final settings = CsvSettings(
        lfdNummerSpalte: _lfdNummerSpalte,
        nameSpalte: _nameSpalte,
        gewerkSpalte: _gewerkSpalte,
        etageSpalte: _etageSpalte,
        anlageBauteilSpalte: _anlageBauteilSpalte,
        parameterSpalte: _parameterSpalte,
        delimiterMode: _delimiterMode,
        anlageKuerzel: _anlageKuerzel,
        bauteilKuerzel: _bauteilKuerzel,
        useDisciplineGrouping: _useDisciplineGrouping,
        labelGewerk: _labelGewerk,
        labelAnlage: _labelAnlage,
        labelBauteil: _labelBauteil,
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
        _saveDropdownCsvSettings(),
        _saveDropdownValues(),
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

  Future<void> _loadDropdownCsvSettings() async {
    try {
      if (mounted) setState(() => _dropdownIsLoading = true);
      final data = await DropdownCsvService.loadForBuilding(widget.buildingId);
      if (!mounted) return;
      setState(() {
        _dropdownCsvPath = data.path;
        _dropdownCsvHeaders = data.headers.isEmpty ? null : data.headers;
        _dropdownValuesByHeader = Map<String, List<String>>.from(data.valuesByHeader);
        _dropdownCsvError = data.error;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der Dropdown-CSV: $e');
      if (!mounted) return;
      setState(() => _dropdownCsvError = e.toString());
    } finally {
      if (mounted) setState(() => _dropdownIsLoading = false);
    }
  }

  Future<void> _saveDropdownCsvSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = DropdownCsvService.prefsKeyForBuilding(widget.buildingId);
      if (_dropdownCsvPath == null || _dropdownCsvPath!.trim().isEmpty) {
        await prefs.remove(key);
        return;
      }
      await prefs.setString(
        key,
        json.encode({
          'path': _dropdownCsvPath,
          'headers': _dropdownCsvHeaders ?? <String>[],
        }),
      );
    } catch (e) {
      debugPrint('Fehler beim Speichern der Dropdown-CSV: $e');
    }
  }

  Future<void> _saveDropdownValues() async {
    await DropdownCsvService.saveValuesForBuilding(widget.buildingId, _dropdownValuesByHeader);
  }

  Future<void> _persistDropdownEdits() async {
    // Stelle sicher, dass alle Dropdown-Namen auch in der Header-Liste liegen
    final headers = <String>[
      ...?_dropdownCsvHeaders,
    ];
    for (final k in _dropdownValuesByHeader.keys) {
      if (!headers.contains(k)) headers.add(k);
    }
    setState(() => _dropdownCsvHeaders = headers);
    await _saveDropdownCsvSettings();
    await _saveDropdownValues();
  }

  Future<void> _importDropdownCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final csvString = CsvUtils.normalizeCsvStringFromBytes(bytes);
      final headerLine = csvString.split('\n').first;
      final delimiter = CsvUtils.detectDelimiterFromLine(headerLine);

      final List<List<dynamic>> rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(headerLine);

      if (rows.isEmpty || rows.first.isEmpty) {
        throw Exception('Keine Header-Zeile in der CSV erkannt');
      }

      final headers =
          rows.first.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (headers.isEmpty) {
        throw Exception('Header-Zeile ist leer');
      }

      setState(() {
        _dropdownCsvPath = filePath;
        _dropdownCsvHeaders = headers;
      });
      await _saveDropdownCsvSettings();
      await _loadDropdownCsvSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${headers.length} Spalten erkannt. Dropdown-Felder können jetzt Spalten auswählen.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import der Dropdown-CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearDropdownCsv() async {
    setState(() {
      _dropdownCsvPath = null;
      _dropdownCsvHeaders = null;
      _dropdownValuesByHeader = {};
      _dropdownCsvError = null;
    });
    await DropdownCsvService.clearValuesForBuilding(widget.buildingId);
    await _saveDropdownCsvSettings();
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
    // Markiere alle Felder im globalen Schema als global
    final markedGlobalSchema = _globalSchema.map((f) => {...f, 'isGlobal': true}).toList();
    final globalKeys = markedGlobalSchema.map((f) => f['key']).toSet();

    for (int i = 0; i < _disciplines.length; i++) {
      final d = _disciplines[i];
      
      // Trenne bestehende individuelle Felder von alten globalen Feldern
      final individualFields = d.schema.where((f) => f['isGlobal'] != true).toList();
      
      // Entferne individuelle Felder, die jetzt im globalen Schema sind (Vermeidung von Dubletten)
      individualFields.removeWhere((f) => globalKeys.contains(f['key']));

      // Neues kombiniertes Schema: Global zuerst, dann individuell
      final newSchema = [...markedGlobalSchema, ...individualFields];

      _disciplines[i] = Disziplin(
        label: d.label,
        icon: d.icon,
        color: d.color,
        schema: newSchema,
        groupingKey: d.groupingKey,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
              Tab(icon: Icon(Icons.arrow_drop_down_circle_outlined), text: 'Dropdown'),
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
                  _buildDropdownTab(),
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
            title: 'CSV-Format',
            subtitle: 'Trennzeichen und Kennungen',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _delimiterMode,
            decoration: InputDecoration(
              labelText: 'Trennzeichen',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto (empfohlen)')),
              DropdownMenuItem(value: ';', child: Text('Semikolon (;)')),
              DropdownMenuItem(value: ',', child: Text('Komma (,)')),
              DropdownMenuItem(value: '\t', child: Text('Tabulator (\\t)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _delimiterMode = val);
                _scheduleAutoSave();
              }
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(
            title: 'CSV-Mapping',
            subtitle: '$_labelGewerk → $_labelAnlage → $_labelBauteil',
          ),
          const SizedBox(height: 16),
          SettingsCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: "Ebene 1: $_labelGewerk",
            description: "",
            child: _useDisciplineGrouping
                ? _buildColumnSelector(
                    label: 'Spalte für $_labelGewerk',
                    value: _gewerkSpalte,
                    onChanged: (v) {
                      setState(() => _gewerkSpalte = v);
                      _scheduleAutoSave();
                    },
                    csvHeaders: _mappingCsvHeaders,
                  )
                : const Text(
                    'Gewerk-Gruppierung ist deaktiviert. Die Spalte wird nicht verwendet.',
                    style: TextStyle(color: Colors.grey),
                  ),
          ),
          _buildConnector(),
          SettingsCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: "Ebene 2: $_labelAnlage (Hauptobjekt)",
            description: "Welche Spalten definieren $_labelAnlage?",
            child: Column(
              children: [
                _buildColumnSelector(
                  label: 'Spalte für Name ($_labelAnlage)',
                  value: _nameSpalte,
                  onChanged: (v) {
                    setState(() => _nameSpalte = v);
                    _scheduleAutoSave();
                  },
                  csvHeaders: _mappingCsvHeaders,
                ),
                const SizedBox(height: 12),
                _buildColumnSelector(
                  label: 'Spalte ID (lfd Nr.)',
                  value: _lfdNummerSpalte,
                  onChanged: (v) {
                    setState(() => _lfdNummerSpalte = v);
                    _scheduleAutoSave();
                  },
                  csvHeaders: _mappingCsvHeaders,
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.layers,
                  label: 'Spalte für Etage?',
                  isActive: _etageSpalte != null,
                  onToggle: (val) {
                    setState(() {
                      _etageSpalte = val
                          ? _nextFreeIndex([
                              _lfdNummerSpalte,
                              _nameSpalte,
                              if (_useDisciplineGrouping) _gewerkSpalte,
                              _parameterSpalte,
                              _anlageBauteilSpalte,
                            ])
                          : null;
                    });
                    _scheduleAutoSave();
                  },
                  child: _etageSpalte != null 
                    ? _buildColumnSelector(
                        label: 'Spalte Etage', 
                        value: _etageSpalte!, 
                        onChanged: (v) {
                          setState(() => _etageSpalte = v);
                          _scheduleAutoSave();
                        },
                        csvHeaders: _mappingCsvHeaders,
                      )
                    : null,
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.settings_input_component,
                  label: 'Spalte für Leistungsparameter?',
                  isActive: _parameterSpalte != null,
                  onToggle: (val) {
                    setState(() {
                      _parameterSpalte = val
                          ? _nextFreeIndex([
                              _lfdNummerSpalte,
                              _nameSpalte,
                              if (_useDisciplineGrouping) _gewerkSpalte,
                              _etageSpalte,
                              _anlageBauteilSpalte,
                            ])
                          : null;
                    });
                    _scheduleAutoSave();
                  },
                  child: _parameterSpalte != null 
                    ? _buildColumnSelector(
                        label: 'Spalte Parameter', 
                        value: _parameterSpalte!, 
                        onChanged: (v) {
                          setState(() => _parameterSpalte = v);
                          _scheduleAutoSave();
                        },
                        csvHeaders: _mappingCsvHeaders,
                      )
                    : null,
                ),
              ],
            ),
          ),
          _buildConnector(),
          SettingsCard(
            color: Colors.orange,
            borderColor: Colors.orange.shade200,
            icon: Icons.build_circle_outlined,
            iconColor: Colors.orange,
            title: "Ebene 3: $_labelBauteil (Unterobjekt)",
            description: "Wie werden $_labelBauteil erkannt?",
            child: _buildToggleRow(
              icon: Icons.account_tree,
              label: 'Unterscheidung A/B nutzen?',
              isActive: _anlageBauteilSpalte != null,
              onToggle: (val) {
                setState(() {
                  _anlageBauteilSpalte = val
                      ? _nextFreeIndex([
                          _lfdNummerSpalte,
                          _nameSpalte,
                          if (_useDisciplineGrouping) _gewerkSpalte,
                          _etageSpalte,
                          _parameterSpalte,
                        ])
                      : null;
                });
                _scheduleAutoSave();
              },
              child: _anlageBauteilSpalte != null 
                ? _buildColumnSelector(
                    label: 'Spalte A/B', 
                    value: _anlageBauteilSpalte!, 
                    onChanged: (v) {
                      setState(() => _anlageBauteilSpalte = v);
                      _scheduleAutoSave();
                    },
                    csvHeaders: _mappingCsvHeaders,
                  )
                : null,
            ),
          ),
          if (_anlageBauteilSpalte != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _anlageKuerzel),
              decoration: InputDecoration(
                labelText: 'Kürzel für $_labelAnlage',
                helperText: 'Mehrere Kürzel mit Komma trennen (z.B. A,$_labelAnlage,MA)',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() => _anlageKuerzel = val);
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _bauteilKuerzel),
              decoration: InputDecoration(
                labelText: 'Kürzel für $_labelBauteil',
                helperText: 'Mehrere Kürzel mit Komma trennen (z.B. B,$_labelBauteil,SL)',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() => _bauteilKuerzel = val);
                _scheduleAutoSave();
              },
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Anzeige & Struktur',
            subtitle: 'Begriffe und Gruppierung',
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            icon: Icons.group_work,
            label: 'Nach Gewerk gruppieren?',
            isActive: _useDisciplineGrouping,
            onToggle: (val) {
              setState(() => _useDisciplineGrouping = val);
              _scheduleAutoSave();
            },
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Begriffe anpassen'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              TextField(
                controller: TextEditingController(text: _labelGewerk),
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
                controller: TextEditingController(text: _labelAnlage),
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
                controller: TextEditingController(text: _labelBauteil),
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
                dropdownCsvPath: _dropdownCsvPath,
                dropdownCsvHeaders: _dropdownCsvHeaders,
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
      } else if (_editingDisciplineIndex != null) {
        final d = _disciplines[_editingDisciplineIndex!];
        return Column(
          children: [
            _buildBackToSelectionHeader('Gewerk: ${d.label}'),
            Expanded(
              child: SchemaEditorWidget(
                existingSchema: d.schema,
                dropdownCsvPath: _dropdownCsvPath,
                dropdownCsvHeaders: _dropdownCsvHeaders,
                onSchemaChanged: (newSchema) {
                  setState(() {
                    _disciplines[_editingDisciplineIndex!] = Disziplin(
                      label: d.label,
                      icon: d.icon,
                      color: d.color,
                      schema: newSchema,
                      groupingKey: d.groupingKey,
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
          const Text(
            'Individuelle Gewerke',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (_disciplines.isEmpty)
            const Center(child: Text('Keine Gewerke vorhanden'))
          else
            ...List.generate(_disciplines.length, (index) {
              final d = _disciplines[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  title: d.label,
                  icon: d.icon,
                  color: d.color,
                  onTap: () => setState(() {
                    _showDisciplineSelection = false;
                    _editingDisciplineIndex = index;
                  }),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDropdownTab() {
    final headers = _dropdownCsvHeaders ?? const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Hier importieren und verwalten Sie Dropdown-Werte. Diese Werte stehen anschließend in Eingabefeldern vom Typ „Dropdown“ zur Auswahl.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _importDropdownCsv,
                icon: Icon(
                  (headers.isNotEmpty) ? Icons.refresh : Icons.upload_file,
                  size: 16,
                ),
                label: Text(
                  (headers.isNotEmpty) ? 'Dropdown-CSV neu laden' : 'Dropdown-CSV importieren',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  side: BorderSide(color: Colors.grey.withOpacity(0.35)),
                  foregroundColor: Colors.grey[800],
                ),
              ),
              const SizedBox(width: 10),
              if (_dropdownCsvPath != null && _dropdownCsvPath!.isNotEmpty)
                Expanded(
                  child: Text(
                    '${headers.length} Dropdowns',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.green[800]),
                  ),
                ),
              if (_dropdownCsvPath != null && _dropdownCsvPath!.isNotEmpty)
                IconButton(
                  tooltip: 'Dropdown-CSV entfernen',
                  onPressed: _clearDropdownCsv,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (_dropdownIsLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_dropdownCsvError != null && _dropdownCsvError!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoCard('Fehler: $_dropdownCsvError'),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: _buildHeaderAction(
              icon: Icons.add,
              label: 'Neues Dropdown',
              onPressed: () async {
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController();
                    return AlertDialog(
                      title: const Text('Neues Dropdown'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Abbrechen'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                          child: const Text('Erstellen'),
                        ),
                      ],
                    );
                  },
                );
                final cleaned = name?.trim();
                if (cleaned == null || cleaned.isEmpty) return;
                setState(() {
                  _dropdownValuesByHeader.putIfAbsent(cleaned, () => <String>[]);
                  _dropdownCsvHeaders = [...headers, if (!headers.contains(cleaned)) cleaned];
                });
                await _persistDropdownEdits();
              },
            ),
          ),
          const SizedBox(height: 12),
          if (headers.isEmpty)
            const Center(child: Text('Noch keine Dropdowns vorhanden.'))
          else
            ...headers.map((h) {
              final values = _dropdownValuesByHeader[h] ?? const <String>[];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ListTile(
                  title: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${values.length} Wert${values.length == 1 ? '' : 'e'}'),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final updated = await showDialog<List<String>>(
                          context: context,
                          builder: (ctx) {
                            var local = [...values];
                            local.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                            return StatefulBuilder(
                              builder: (ctx, setLocal) {
                                Future<void> promptAddValue() async {
                                  final newValue = await showDialog<String>(
                                    context: ctx,
                                    builder: (ctx2) {
                                      final ctrl = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('Neuer Wert'),
                                        content: TextField(
                                          controller: ctrl,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Wert',
                                          ),
                                          onSubmitted: (_) => Navigator.of(ctx2).pop(ctrl.text.trim()),
                                        ),
                                        actions: [
                                          IconButton(
                                            tooltip: 'Abbrechen',
                                            onPressed: () => Navigator.of(ctx2).pop(),
                                            icon: const Icon(Icons.close),
                                          ),
                                          IconButton(
                                            tooltip: 'Bestätigen',
                                            onPressed: () => Navigator.of(ctx2).pop(ctrl.text.trim()),
                                            icon: const Icon(Icons.check),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  final t = newValue?.trim();
                                  if (t == null || t.isEmpty) return;
                                  setLocal(() {
                                    if (!local.contains(t)) local.add(t);
                                    local.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  });
                                }

                                return AlertDialog(
                                title: Text('Dropdown: $h'),
                                content: SizedBox(
                                  width: 420,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          tooltip: 'Neuen Wert hinzufügen',
                                          onPressed: promptAddValue,
                                          icon: const Icon(Icons.add),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Flexible(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: local.length,
                                          itemBuilder: (ctx, i) {
                                            final v = local[i];
                                            return ListTile(
                                              dense: true,
                                              title: Text(v),
                                              trailing: IconButton(
                                                tooltip: 'Entfernen',
                                                icon: const Icon(Icons.close, size: 18),
                                                onPressed: () => setLocal(() => local.removeAt(i)),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Abbrechen'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(local),
                                    child: const Text('Speichern'),
                                  ),
                                ],
                              );
                              },
                            );
                          },
                        );
                        if (updated != null) {
                          setState(() {
                            _dropdownValuesByHeader[h] = updated;
                          });
                          await _persistDropdownEdits();
                        }
                      } else if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Dropdown löschen?'),
                            content: Text('„$h“ wirklich löschen?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          setState(() {
                            _dropdownValuesByHeader.remove(h);
                            _dropdownCsvHeaders = headers.where((x) => x != h).toList();
                          });
                          await _persistDropdownEdits();
                        }
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                      PopupMenuItem(value: 'delete', child: Text('Löschen')),
                    ],
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
            subtitle: 'Gewerk → Vorlagendetails → Struktur',
          ),
          const SizedBox(height: 16),

          // 1. EBENE: GEWERK
          SettingsCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: "Ebene 1: Gewerk",
            description: "Welche Spalte definiert das Gewerk der Vorlage?",
            child: _buildTemplateColumnSelector(
              label: 'Spalte für Gewerk',
              value: _templateGewerkSpalte,
              onChanged: (v) {
                setState(() => _templateGewerkSpalte = v);
                _scheduleAutoSave();
              },
            ),
          ),

          _buildConnector(),

          // 2. EBENE: VORLAGEN-DEFINITION (ANLAGE)
          SettingsCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: "Ebene 2: Vorlage (Anlage/Typ)",
            description: "Welche Spalten definieren die Vorlagendetails?",
            child: Column(
              children: [
                _buildTemplateColumnSelector(
                  label: 'Spalte Anlagentyp',
                  value: _templateAnlagentypSpalte,
                  onChanged: (v) {
                    setState(() => _templateAnlagentypSpalte = v);
                    _scheduleAutoSave();
                  },
                ),
                const SizedBox(height: 12),
                _buildTemplateColumnSelector(
                  label: 'Spalte Bezeichnung',
                  value: _templateBezeichnungSpalte,
                  onChanged: (v) {
                    setState(() => _templateBezeichnungSpalte = v);
                    _scheduleAutoSave();
                  },
                ),
                const SizedBox(height: 12),
                _buildTemplateColumnSelector(
                  label: 'Spalte Parameter',
                  value: _templateParameterSpalte,
                  onChanged: (v) {
                    setState(() => _templateParameterSpalte = v);
                    _scheduleAutoSave();
                  },
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.checklist,
                  label: 'Gibt es eine Spalte für Auswahl-Typ?',
                  isActive: _templateAuswahlAnlagentypSpalte != null,
                  onToggle: (val) {
                    setState(() {
                      _templateAuswahlAnlagentypSpalte = val
                          ? _nextFreeIndex([
                              _templateGewerkSpalte,
                              _templateAnlageBauteilSpalte,
                              _templateAnlagentypSpalte,
                              _templateBezeichnungSpalte,
                              _templateParameterSpalte,
                            ])
                          : null;
                    });
                    _scheduleAutoSave();
                  },
                  child: _templateAuswahlAnlagentypSpalte != null 
                    ? _buildTemplateColumnSelector(
                        label: 'Spalte Auswahl-Typ', 
                        value: _templateAuswahlAnlagentypSpalte!, 
                        onChanged: (v) {
                          setState(() => _templateAuswahlAnlagentypSpalte = v);
                          _scheduleAutoSave();
                        }
                      )
                    : null,
                ),
              ],
            ),
          ),

          _buildConnector(),

          // 3. EBENE: UNTERSCHEIDUNG
          SettingsCard(
            color: Colors.orange,
            borderColor: Colors.orange.shade200,
            icon: Icons.build_circle_outlined,
            iconColor: Colors.orange,
            title: "Ebene 3: Struktur-Kennung",
            description: "Wie wird zwischen Anlage und Bauteil unterschieden?",
            child: Column(
              children: [
                const Text(
                  "Spalte, die 'A' (Anlage) oder 'B' (Bauteil) enthält.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildTemplateColumnSelector(
                  label: 'Spalte A/B Kennung',
                  value: _templateAnlageBauteilSpalte,
                  onChanged: (v) {
                    setState(() => _templateAnlageBauteilSpalte = v);
                    _scheduleAutoSave();
                  },
                ),
              ],
            ),
          ),
          
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
  }) {
    if (_templateCsvHeaders != null && _templateCsvHeaders!.isNotEmpty) {
      final int safeValue = (value >= 0 && value < _templateCsvHeaders!.length) ? value : 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold)),
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

    return TextField(
      controller: TextEditingController(text: (value + 1).toString())
        ..selection = TextSelection.fromPosition(TextPosition(offset: (value + 1).toString().length)),
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
        final userInput = int.tryParse(text);
        if (userInput != null && userInput > 0) {
          onChanged(userInput - 1);
        }
      },
    );
  }

  Widget _buildTemplateValidationWarning() {
    final values = [
      _templateGewerkSpalte,
      _templateAnlageBauteilSpalte,
      _templateAnlagentypSpalte,
      _templateBezeichnungSpalte,
      _templateParameterSpalte,
      if (_templateAuswahlAnlagentypSpalte != null) _templateAuswahlAnlagentypSpalte,
    ];
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
    return TextField(
      controller: TextEditingController(text: (value + 1).toString())
        ..selection = TextSelection.fromPosition(TextPosition(offset: (value + 1).toString().length)),
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
        final userInput = int.tryParse(text);
        if (userInput != null && userInput > 0) {
          // User gibt 1 ein -> wir speichern 0
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

  Widget _buildValidationWarning() {
    final values = [
      _lfdNummerSpalte,
      _nameSpalte,
      if (_useDisciplineGrouping) _gewerkSpalte,
      if (_etageSpalte != null) _etageSpalte,
      if (_anlageBauteilSpalte != null) _anlageBauteilSpalte,
      if (_parameterSpalte != null) _parameterSpalte,
    ];
    if (values.length != values.toSet().length) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Achtung: Spaltennummern doppelt vergeben!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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

  int _nextFreeIndex(List<int?> values) {
    final used = values.whereType<int>().toSet();
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

      // Dropdown-CSV entfernen (für Dropdown-Felder)
      if (mounted) {
        setState(() {
          _dropdownCsvPath = null;
          _dropdownCsvHeaders = null;
        });
      }
      await prefs.remove(DropdownCsvService.prefsKeyForBuilding(widget.buildingId));
      
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
