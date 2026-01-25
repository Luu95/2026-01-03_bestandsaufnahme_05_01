// lib/pages/csv_settings_page.dart

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
import '../services/template_service.dart';
import 'widgets/schema_editor_dialog.dart';
import 'widgets/settings_card.dart';

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
  
  // Template CSV Settings
  int _templateGewerkSpalte = 0;
  int _templateAnlageBauteilSpalte = 1;
  int _templateAnlagentypSpalte = 2;
  int _templateBezeichnungSpalte = 3;
  int _templateParameterSpalte = 4;
  int? _templateAuswahlAnlagentypSpalte;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCsvSettings(),
      _loadDisciplines(),
      _loadTemplateCsvSettings(),
      _loadGlobalSchema(),
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
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                setState(() => _isLoading = true);
                await Future.wait([
                  _saveCsvSettings(),
                  _saveDisciplines(),
                  _saveTemplateCsvSettings(),
                  _saveGlobalSchema(),
                ]);
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alle Einstellungen gespeichert')),
                  );
                  Navigator.of(context).pop();
                }
              },
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
          _buildInfoCard(
            _mappingCsvHeaders == null
                ? 'Ordnen Sie hier fest, welche CSV-Spalten in der App welche Bedeutung haben. '
                    'Laden Sie eine Beispiel-CSV, um Spaltennamen statt Nummern zu sehen.'
                : 'Beispiel-CSV geladen. Wählen Sie die passenden Spalten aus dem Dropdown.',
          ),
          const SizedBox(height: 12),
          // Toggle-Button für Beispiel-CSV
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadExampleCsvHeaders(forTemplate: false),
                  icon: Icon(_mappingCsvHeaders == null ? Icons.table_chart_outlined : Icons.refresh),
                  label: Text(_mappingCsvHeaders == null ? 'Beispiel-CSV laden' : 'CSV neu laden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mappingCsvHeaders == null ? Colors.blue : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_mappingCsvHeaders != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _mappingCsvHeaders = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dropdown-Modus deaktiviert. Verwenden Sie Spaltennummern.')),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Deaktivieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ],
          ),
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
              }
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(
            title: 'CSV-Mapping',
            subtitle: 'Gewerk → Anlage → Bauteil',
          ),
          const SizedBox(height: 16),
          SettingsCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: "Ebene 1: Gewerk (Disziplin)",
            description: "In welcher Spalte steht das Gewerk?",
            child: _buildColumnSelector(
              label: 'Spalte für Gewerk',
              value: _gewerkSpalte,
              onChanged: (v) => setState(() => _gewerkSpalte = v),
              csvHeaders: _mappingCsvHeaders,
            ),
          ),
          _buildConnector(),
          SettingsCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: "Ebene 2: Anlage (Hauptobjekt)",
            description: "Welche Spalten definieren die Anlage?",
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildColumnSelector(
                        label: 'Spalte für Name',
                        value: _nameSpalte,
                        onChanged: (v) => setState(() => _nameSpalte = v),
                        csvHeaders: _mappingCsvHeaders,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildColumnSelector(
                        label: 'Spalte ID (lfd Nr.)',
                        value: _lfdNummerSpalte,
                        onChanged: (v) => setState(() => _lfdNummerSpalte = v),
                        csvHeaders: _mappingCsvHeaders,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.layers,
                  label: 'Spalte für Etage?',
                  isActive: _etageSpalte != null,
                  onToggle: (val) => setState(() {
                    _etageSpalte = val
                        ? _nextFreeIndex([
                            _lfdNummerSpalte,
                            _nameSpalte,
                            _gewerkSpalte,
                            _parameterSpalte,
                            _anlageBauteilSpalte,
                          ])
                        : null;
                  }),
                  child: _etageSpalte != null 
                    ? _buildColumnSelector(
                        label: 'Spalte Etage', 
                        value: _etageSpalte!, 
                        onChanged: (v) => setState(() => _etageSpalte = v),
                        csvHeaders: _mappingCsvHeaders,
                      )
                    : null,
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.settings_input_component,
                  label: 'Spalte für Leistungsparameter?',
                  isActive: _parameterSpalte != null,
                  onToggle: (val) => setState(() {
                    _parameterSpalte = val
                        ? _nextFreeIndex([
                            _lfdNummerSpalte,
                            _nameSpalte,
                            _gewerkSpalte,
                            _etageSpalte,
                            _anlageBauteilSpalte,
                          ])
                        : null;
                  }),
                  child: _parameterSpalte != null 
                    ? _buildColumnSelector(
                        label: 'Spalte Parameter', 
                        value: _parameterSpalte!, 
                        onChanged: (v) => setState(() => _parameterSpalte = v),
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
            title: "Ebene 3: Bauteil (Unterobjekt)",
            description: "Wie werden Bauteile erkannt?",
            child: _buildToggleRow(
              icon: Icons.account_tree,
              label: 'Unterscheidung A/B nutzen?',
              isActive: _anlageBauteilSpalte != null,
              onToggle: (val) => setState(() {
                _anlageBauteilSpalte = val
                    ? _nextFreeIndex([
                        _lfdNummerSpalte,
                        _nameSpalte,
                        _gewerkSpalte,
                        _etageSpalte,
                        _parameterSpalte,
                      ])
                    : null;
              }),
              child: _anlageBauteilSpalte != null 
                ? _buildColumnSelector(
                    label: 'Spalte A/B', 
                    value: _anlageBauteilSpalte!, 
                    onChanged: (v) => setState(() => _anlageBauteilSpalte = v),
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
                labelText: 'Kürzel für Anlage',
                helperText: 'Mehrere Kürzel mit Komma trennen (z.B. A,Anlage,MA)',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _anlageKuerzel = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _bauteilKuerzel),
              decoration: InputDecoration(
                labelText: 'Kürzel für Bauteil',
                helperText: 'Mehrere Kürzel mit Komma trennen (z.B. B,Bauteil,SL)',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _bauteilKuerzel = val),
            ),
          ],
          const SizedBox(height: 24),
          _buildValidationWarning(),
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
          const Text(
            'Konfigurations-Modus wählen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wählen Sie, ob Sie das globale Standard-Schema für neue Gewerke oder ein spezifisches Gewerk bearbeiten möchten.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // GLOBAL CARD
          _buildSelectionCard(
            title: 'Globales Standard-Schema',
            subtitle: 'Definiert, wie neue Gewerke standardmäßig aussehen',
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
                  subtitle: '${d.schema.length} Felder definiert',
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

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
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
        subtitle: Text(subtitle),
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
          _buildInfoCard(_templateCsvHeaders == null
              ? 'Tipp: Laden Sie eine Beispiel-CSV, um Spaltennamen statt Nummern zu sehen.'
              : 'Beispiel-CSV geladen. Wählen Sie die passenden Spalten aus dem Dropdown.'),
          const SizedBox(height: 12),
          // Toggle-Button für Beispiel-CSV
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadExampleCsvHeaders(forTemplate: true),
                  icon: Icon(_templateCsvHeaders == null ? Icons.table_chart_outlined : Icons.refresh),
                  label: Text(_templateCsvHeaders == null ? 'Beispiel-CSV laden' : 'CSV neu laden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _templateCsvHeaders == null ? Colors.blue : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_templateCsvHeaders != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _templateCsvHeaders = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dropdown-Modus deaktiviert. Verwenden Sie Spaltennummern.')),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Deaktivieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ],
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
              onChanged: (v) => setState(() => _templateGewerkSpalte = v),
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
                Row(
                  children: [
                    Expanded(
                      child: _buildTemplateColumnSelector(
                        label: 'Spalte Anlagentyp',
                        value: _templateAnlagentypSpalte,
                        onChanged: (v) => setState(() => _templateAnlagentypSpalte = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTemplateColumnSelector(
                        label: 'Spalte Bezeichnung',
                        value: _templateBezeichnungSpalte,
                        onChanged: (v) => setState(() => _templateBezeichnungSpalte = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTemplateColumnSelector(
                        label: 'Spalte Parameter',
                        value: _templateParameterSpalte,
                        onChanged: (v) => setState(() => _templateParameterSpalte = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildToggleRow(
                  icon: Icons.checklist,
                  label: 'Gibt es eine Spalte für Auswahl-Typ?',
                  isActive: _templateAuswahlAnlagentypSpalte != null,
                  onToggle: (val) => setState(() {
                    _templateAuswahlAnlagentypSpalte = val
                        ? _nextFreeIndex([
                            _templateGewerkSpalte,
                            _templateAnlageBauteilSpalte,
                            _templateAnlagentypSpalte,
                            _templateBezeichnungSpalte,
                            _templateParameterSpalte,
                          ])
                        : null;
                  }),
                  child: _templateAuswahlAnlagentypSpalte != null 
                    ? _buildTemplateColumnSelector(
                        label: 'Spalte Auswahl-Typ', 
                        value: _templateAuswahlAnlagentypSpalte!, 
                        onChanged: (v) => setState(() => _templateAuswahlAnlagentypSpalte = v)
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
                  onChanged: (v) => setState(() => _templateAnlageBauteilSpalte = v),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildTemplateValidationWarning(),
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
        helperText: 'Spaltennummer (Start bei 1)',
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
        helperText: 'Spaltennummer (Start bei 1)',
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
      _lfdNummerSpalte, _nameSpalte, _gewerkSpalte,
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
}
