// lib/pages/csv_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/disziplin_schnittstelle.dart';
import '../providers/database_provider.dart';
import '../services/template_service.dart';
import 'widgets/schema_editor_dialog.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_${widget.projectId}';
      final settingsJson = prefs.getString(key);
      
      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _lfdNummerSpalte = settings['lfdNummerSpalte'] as int? ?? 0;
          _nameSpalte = settings['nameSpalte'] as int? ?? 1;
          _gewerkSpalte = settings['gewerkSpalte'] as int? ?? 2;
          _etageSpalte = settings['etageSpalte'] as int?;
          _anlageBauteilSpalte = settings['anlageBauteilSpalte'] as int?;
          _parameterSpalte = settings['parameterSpalte'] as int?;
          
          _lfdNummerBearbeitbar = settings['lfdNummerBearbeitbar'] as bool? ?? true;
          _nameBearbeitbar = settings['nameBearbeitbar'] as bool? ?? true;
          _gewerkBearbeitbar = settings['gewerkBearbeitbar'] as bool? ?? true;
          _etageBearbeitbar = settings['etageBearbeitbar'] as bool? ?? true;
          _anlageBauteilBearbeitbar = settings['anlageBauteilBearbeitbar'] as bool? ?? true;
          _parameterBearbeitbar = settings['parameterBearbeitbar'] as bool? ?? true;
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
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_${widget.projectId}';
    final settings = {
      'lfdNummerSpalte': _lfdNummerSpalte,
      'nameSpalte': _nameSpalte,
      'gewerkSpalte': _gewerkSpalte,
      'etageSpalte': _etageSpalte,
      'anlageBauteilSpalte': _anlageBauteilSpalte,
      'parameterSpalte': _parameterSpalte,
      'lfdNummerBearbeitbar': _lfdNummerBearbeitbar,
      'nameBearbeitbar': _nameBearbeitbar,
      'gewerkBearbeitbar': _gewerkBearbeitbar,
      'etageBearbeitbar': _etageBearbeitbar,
      'anlageBauteilBearbeitbar': _anlageBauteilBearbeitbar,
      'parameterBearbeitbar': _parameterBearbeitbar,
    };
    await prefs.setString(key, json.encode(settings));
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
            'Ordnen Sie hier fest, welche CSV-Spalten in der App welche Bedeutung haben. '
            'Die Spaltennummern sind 0-basiert (Spalte 0 ist die erste Spalte).',
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            title: 'CSV-Mapping',
            subtitle: 'Gewerk → Anlage → Bauteil',
          ),
          const SizedBox(height: 16),
          _buildHierarchicalCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: "Ebene 1: Gewerk (Disziplin)",
            description: "In welcher Spalte steht das Gewerk?",
            content: _buildCompactInput(
              label: 'Spalte für Gewerk',
              value: _gewerkSpalte,
              onChanged: (v) => setState(() => _gewerkSpalte = v),
            ),
          ),
          _buildConnector(),
          _buildHierarchicalCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: "Ebene 2: Anlage (Hauptobjekt)",
            description: "Welche Spalten definieren die Anlage?",
            content: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInput(
                        label: 'Spalte für Name',
                        value: _nameSpalte,
                        onChanged: (v) => setState(() => _nameSpalte = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInput(
                        label: 'Spalte ID (lfd Nr.)',
                        value: _lfdNummerSpalte,
                        onChanged: (v) => setState(() => _lfdNummerSpalte = v),
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
                    ? _buildCompactInput(
                        label: 'Spalte Etage', 
                        value: _etageSpalte!, 
                        onChanged: (v) => setState(() => _etageSpalte = v)
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
                    ? _buildCompactInput(
                        label: 'Spalte Parameter', 
                        value: _parameterSpalte!, 
                        onChanged: (v) => setState(() => _parameterSpalte = v)
                      )
                    : null,
                ),
              ],
            ),
          ),
          _buildConnector(),
          _buildHierarchicalCard(
            color: Colors.orange,
            borderColor: Colors.orange.shade200,
            icon: Icons.build_circle_outlined,
            iconColor: Colors.orange,
            title: "Ebene 3: Bauteil (Unterobjekt)",
            description: "Wie werden Bauteile erkannt?",
            content: _buildToggleRow(
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
                ? _buildCompactInput(
                    label: 'Spalte A/B', 
                    value: _anlageBauteilSpalte!, 
                    onChanged: (v) => setState(() => _anlageBauteilSpalte = v)
                  )
                : null,
            ),
          ),
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
          _buildInfoCard(
            'Konfigurieren Sie hier das Mapping für Vorlagen. '
            'Damit lassen sich Gewerke und Anlagentypen später schneller anlegen.',
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            title: 'CSV-Mapping für Vorlagen',
            subtitle: 'Gewerk → Vorlagendetails → Struktur',
            trailing: _buildHeaderAction(
              icon: Icons.upload_file,
              label: 'Vorlagen importieren',
              onPressed: _importTemplates,
            ),
          ),
          const SizedBox(height: 16),

          // 1. EBENE: GEWERK
          _buildTemplateHierarchicalCard(
            color: Colors.blueGrey,
            borderColor: Colors.blueGrey.shade200,
            icon: Icons.folder_open,
            iconColor: Colors.blueGrey,
            title: "Ebene 1: Gewerk",
            description: "Welche Spalte definiert das Gewerk der Vorlage?",
            content: _buildCompactInput(
              label: 'Spalte für Gewerk',
              value: _templateGewerkSpalte,
              onChanged: (v) => setState(() => _templateGewerkSpalte = v),
            ),
          ),

          _buildConnector(),

          // 2. EBENE: VORLAGEN-DEFINITION (ANLAGE)
          _buildTemplateHierarchicalCard(
            color: Colors.green,
            borderColor: Colors.green.shade200,
            icon: Icons.settings_applications,
            iconColor: Colors.green,
            title: "Ebene 2: Vorlage (Anlage/Typ)",
            description: "Welche Spalten definieren die Vorlagendetails?",
            content: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInput(
                        label: 'Spalte Anlagentyp',
                        value: _templateAnlagentypSpalte,
                        onChanged: (v) => setState(() => _templateAnlagentypSpalte = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInput(
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
                      child: _buildCompactInput(
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
                    ? _buildCompactInput(
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
          _buildTemplateHierarchicalCard(
            color: Colors.orange,
            borderColor: Colors.orange.shade200,
            icon: Icons.build_circle_outlined,
            iconColor: Colors.orange,
            title: "Ebene 3: Struktur-Kennung",
            description: "Wie wird zwischen Anlage und Bauteil unterschieden?",
            content: Column(
              children: [
                const Text(
                  "Spalte, die 'A' (Anlage) oder 'B' (Bauteil) enthält.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildCompactInput(
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

  Widget _buildTemplateHierarchicalCard({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4.0), 
            child: content,
          ),
        ],
      ),
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

  Widget _buildHierarchicalCard({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildCompactInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value.toString()),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: '0 = erste Spalte',
        prefixText: 'Spalte ',
      ),
      onChanged: (text) {
        final newValue = int.tryParse(text);
        if (newValue != null && newValue >= 0) {
          onChanged(newValue);
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
