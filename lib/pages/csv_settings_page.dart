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
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
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
    final dbService = ref.read(databaseServiceProvider);
    await dbService.replaceDisciplines(widget.buildingId, _disciplines);
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Anlagen-Einstellungen'),
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0, left: 4),
            child: Text(
              'Ordnen Sie Ihre CSV-Spalten der App-Hierarchie zu:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          _buildHierarchicalCard(
            color: Colors.blueGrey.shade50,
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
            color: Colors.white,
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
                  onToggle: (val) => setState(() => _etageSpalte = val ? 3 : null),
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
                  onToggle: (val) => setState(() => _parameterSpalte = val ? 4 : null),
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
            color: Colors.orange.shade50,
            borderColor: Colors.orange.shade200,
            icon: Icons.build_circle_outlined,
            iconColor: Colors.orange,
            title: "Ebene 3: Bauteil (Unterobjekt)",
            description: "Wie werden Bauteile erkannt?",
            content: _buildToggleRow(
              icon: Icons.account_tree,
              label: 'Unterscheidung A/B nutzen?',
              isActive: _anlageBauteilSpalte != null,
              onToggle: (val) => setState(() => _anlageBauteilSpalte = val ? 4 : null),
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
    // Nimm das Schema des ersten Gewerks (alle haben das gleiche Schema)
    final currentSchema = _disciplines.isNotEmpty 
        ? List<Map<String, dynamic>>.from(_disciplines.first.schema)
        : <Map<String, dynamic>>[];

    return Column(
      children: [
        // Header mit Info und Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Eingabefelder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _disciplines.isEmpty
                          ? 'Keine Gewerke definiert'
                          : 'Gemeinsames Schema für alle ${_disciplines.length} Gewerke',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _editSchemaForAllDisciplines,
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text('Bearbeiten'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        // Liste der Felder anzeigen
        Expanded(
          child: _disciplines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Keine Gewerke definiert'),
                      const SizedBox(height: 8),
                      Text(
                        'Bitte fügen Sie zuerst Gewerke hinzu',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : currentSchema.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schema_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Noch keine Eingabefelder'),
                          const SizedBox(height: 8),
                          Text(
                            'Klicken Sie auf "Bearbeiten" um Felder hinzuzufügen',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: currentSchema.length,
                      itemBuilder: (context, index) {
                        final field = currentSchema[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: field['type'] == 'int'
                                    ? Colors.orange.withOpacity(0.15)
                                    : Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                field['type'] == 'int' ? Icons.numbers : Icons.text_fields,
                                color: field['type'] == 'int' ? Colors.orange[700] : Colors.green[700],
                                size: 20,
                              ),
                            ),
                            title: Text(
                              field['label'] ?? field['key'] ?? 'Unbekannt',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Key: ${field['key'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: field['type'] == 'int'
                                            ? Colors.orange.withOpacity(0.15)
                                            : Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        field['type'] == 'int' ? 'Zahl' : 'Text',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: field['type'] == 'int' ? Colors.orange[800] : Colors.green[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (field['editable'] ?? true)
                                            ? Colors.blue.withOpacity(0.15)
                                            : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (field['editable'] ?? true) ? 'Editierbar' : 'Gesperrt',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: (field['editable'] ?? true) ? Colors.blue[800] : Colors.grey[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _editSchemaForAllDisciplines() async {
    if (_disciplines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Gewerke definiert'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Nimm das Schema des ersten Gewerks (alle haben das gleiche Schema)
    final currentSchema = List<Map<String, dynamic>>.from(_disciplines.first.schema);

    final newSchema = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SchemaEditorDialog(existingSchema: currentSchema),
    );

    if (newSchema != null) {
      _applySchemaToAllDisciplines(newSchema);
    }
  }

  void _applySchemaToAllDisciplines(List<Map<String, dynamic>> newSchema) {
    setState(() {
      // Wende das neue Schema auf alle Gewerke an
      for (int i = 0; i < _disciplines.length; i++) {
        final d = _disciplines[i];
        _disciplines[i] = Disziplin(
          label: d.label,
          icon: d.icon,
          color: d.color,
          schema: newSchema,
          groupingKey: d.groupingKey,
        );
      }
    });
  }

  // --- TEMPLATE TAB ---

  Widget _buildTemplateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16.0, left: 4),
                  child: Text(
                    'Ordnen Sie Ihre CSV-Spalten für Gewerkevorlagen zu:',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Vorlagen importieren',
                onPressed: _importTemplates,
              ),
            ],
          ),

          // 1. EBENE: GEWERK
          _buildTemplateHierarchicalCard(
            color: Colors.blueGrey.shade50,
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
            color: Colors.white,
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
                  onToggle: (val) => setState(() => _templateAuswahlAnlagentypSpalte = val ? 2 : null),
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
            color: Colors.orange.shade50,
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
        color: color,
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor.withOpacity(0.5)),
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
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            Switch(value: isActive, onChanged: onToggle),
          ],
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
}
