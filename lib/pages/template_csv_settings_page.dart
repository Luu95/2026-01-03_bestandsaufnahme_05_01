// lib/pages/template_csv_settings_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/template_service.dart';

class TemplateCsvSettingsPage extends StatefulWidget {
  final String projectId;
  final String? buildingId; // Optional: für automatische Disziplin-Erstellung

  const TemplateCsvSettingsPage({
    Key? key,
    required this.projectId,
    this.buildingId,
  }) : super(key: key);

  @override
  State<TemplateCsvSettingsPage> createState() => _TemplateCsvSettingsPageState();
}

class _TemplateCsvSettingsPageState extends State<TemplateCsvSettingsPage> {
  int _gewerkSpalte = 0;
  int _anlageBauteilSpalte = 1;
  int _anlagentypSpalte = 2;
  int _bezeichnungSpalte = 3;
  int _parameterSpalte = 4;
  int? _auswahlAnlagentypSpalte;
  
  // Bearbeitbar-Flags für jede Spalte
  bool _gewerkBearbeitbar = true;
  bool _anlageBauteilBearbeitbar = true;
  bool _anlagentypBearbeitbar = true;
  bool _bezeichnungBearbeitbar = true;
  bool _parameterBearbeitbar = true;
  bool _auswahlAnlagentypBearbeitbar = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'template_csv_settings_${widget.projectId}';
      final settingsJson = prefs.getString(key);
      
      if (settingsJson != null) {
        try {
          final settings = json.decode(settingsJson) as Map<String, dynamic>;
          setState(() {
            _gewerkSpalte = settings['gewerkSpalte'] as int? ?? 0;
            _anlageBauteilSpalte = settings['anlageBauteilSpalte'] as int? ?? 1;
            _anlagentypSpalte = settings['anlagentypSpalte'] as int? ?? 2;
            _bezeichnungSpalte = settings['bezeichnungSpalte'] as int? ?? 3;
            _parameterSpalte = settings['parameterSpalte'] as int? ?? 4;
            _auswahlAnlagentypSpalte = settings['auswahlAnlagentypSpalte'] as int?;
            
            // Bearbeitbar-Flags laden
            _gewerkBearbeitbar = settings['gewerkBearbeitbar'] as bool? ?? true;
            _anlageBauteilBearbeitbar = settings['anlageBauteilBearbeitbar'] as bool? ?? true;
            _anlagentypBearbeitbar = settings['anlagentypBearbeitbar'] as bool? ?? true;
            _bezeichnungBearbeitbar = settings['bezeichnungBearbeitbar'] as bool? ?? true;
            _parameterBearbeitbar = settings['parameterBearbeitbar'] as bool? ?? true;
            _auswahlAnlagentypBearbeitbar = settings['auswahlAnlagentypBearbeitbar'] as bool? ?? true;
          });
        } catch (e) {
          debugPrint('Fehler beim JSON-Parsing der Vorlagen-CSV-Einstellungen: $e');
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Vorlagen-CSV-Einstellungen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'template_csv_settings_${widget.projectId}';
    final settings = {
      'gewerkSpalte': _gewerkSpalte,
      'anlageBauteilSpalte': _anlageBauteilSpalte,
      'anlagentypSpalte': _anlagentypSpalte,
      'bezeichnungSpalte': _bezeichnungSpalte,
      'parameterSpalte': _parameterSpalte,
      'auswahlAnlagentypSpalte': _auswahlAnlagentypSpalte,
      'gewerkBearbeitbar': _gewerkBearbeitbar,
      'anlageBauteilBearbeitbar': _anlageBauteilBearbeitbar,
      'anlagentypBearbeitbar': _anlagentypBearbeitbar,
      'bezeichnungBearbeitbar': _bezeichnungBearbeitbar,
      'parameterBearbeitbar': _parameterBearbeitbar,
      'auswahlAnlagentypBearbeitbar': _auswahlAnlagentypBearbeitbar,
    };
    await prefs.setString(key, json.encode(settings));
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('CSV-Einstellungen – Vorlagen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Import-Struktur (Vorlagen)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Vorlagen importieren',
            onPressed: () async {
              await _importTemplates();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Speichern',
            onPressed: () async {
              await _saveSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Einstellungen gespeichert'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0, left: 4),
              child: Text(
                'Ordnen Sie Ihre CSV-Spalten für Gewerkevorlagen zu:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),

            // VISUELLE HIERARCHIE
            
            // 1. EBENE: GEWERK
            _buildHierarchicalCard(
              color: Colors.blueGrey.shade50,
              borderColor: Colors.blueGrey.shade200,
              icon: Icons.folder_open,
              iconColor: Colors.blueGrey,
              title: "Ebene 1: Gewerk",
              description: "Welche Spalte definiert das Gewerk der Vorlage?",
              content: _buildCompactInput(
                label: 'Spalte für Gewerk',
                value: _gewerkSpalte,
                onChanged: (v) => setState(() => _gewerkSpalte = v),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Container(height: 20, width: 2, color: Colors.grey.shade300),
            ),

            // 2. EBENE: VORLAGEN-DEFINITION (ANLAGE)
            _buildHierarchicalCard(
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
                          value: _anlagentypSpalte,
                          onChanged: (v) => setState(() => _anlagentypSpalte = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInput(
                          label: 'Spalte Bezeichnung',
                          value: _bezeichnungSpalte,
                          onChanged: (v) => setState(() => _bezeichnungSpalte = v),
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
                          value: _parameterSpalte,
                          onChanged: (v) => setState(() => _parameterSpalte = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildToggleRow(
                    icon: Icons.checklist,
                    label: 'Gibt es eine Spalte für Auswahl-Typ?',
                    isActive: _auswahlAnlagentypSpalte != null,
                    onToggle: (val) => setState(() => _auswahlAnlagentypSpalte = val ? 2 : null),
                    child: _auswahlAnlagentypSpalte != null 
                      ? _buildCompactInput(
                          label: 'Spalte Auswahl-Typ', 
                          value: _auswahlAnlagentypSpalte!, 
                          onChanged: (v) => setState(() => _auswahlAnlagentypSpalte = v)
                        )
                      : null,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Container(height: 20, width: 2, color: Colors.grey.shade300),
            ),

            // 3. EBENE: UNTERSCHEIDUNG
            _buildHierarchicalCard(
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
                    value: _anlageBauteilSpalte,
                    onChanged: (v) => setState(() => _anlageBauteilSpalte = v),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            _buildValidationWarning(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

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

  Widget _buildCompactInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value.toString())
        ..selection = TextSelection.fromPosition(TextPosition(offset: value.toString().length)),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixText: 'Spalte ',
        prefixStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: isActive,
              onChanged: onToggle,
              activeColor: Colors.blue,
            ),
          ],
        ),
        if (isActive && child != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 0),
            child: child,
          ),
      ],
    );
  }

  Widget _buildValidationWarning() {
    final values = [
      _gewerkSpalte,
      _anlageBauteilSpalte,
      _anlagentypSpalte,
      _bezeichnungSpalte,
      _parameterSpalte,
      if (_auswahlAnlagentypSpalte != null) _auswahlAnlagentypSpalte,
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
}
