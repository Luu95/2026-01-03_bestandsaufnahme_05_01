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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
        // Fehler beim Laden, verwende Standardwerte
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV-Einstellungen – Vorlagen'),
        elevation: 0,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.table_chart,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Spaltenzuordnung',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Konfigurieren Sie die Spaltenzuordnung und Bearbeitbarkeit für den Gewerkevorlagen-Import.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Spalten-Konfiguration
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pflichtfelder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Gewerk
                    _buildSpaltenSelector(
                      label: 'Gewerk',
                      value: _gewerkSpalte,
                      bearbeitbar: _gewerkBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _gewerkSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _gewerkBearbeitbar = value;
                        });
                      },
                      icon: Icons.build,
                      color: Colors.orange,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Anlage/Bauteil
                    _buildSpaltenSelector(
                      label: 'Anlage/Bauteil',
                      value: _anlageBauteilSpalte,
                      bearbeitbar: _anlageBauteilBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _anlageBauteilSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _anlageBauteilBearbeitbar = value;
                        });
                      },
                      icon: Icons.account_tree,
                      color: Colors.purple,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Anlagentyp
                    _buildSpaltenSelector(
                      label: 'Anlagentyp',
                      value: _anlagentypSpalte,
                      bearbeitbar: _anlagentypBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _anlagentypSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _anlagentypBearbeitbar = value;
                        });
                      },
                      icon: Icons.category,
                      color: Colors.blue,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Bezeichnung
                    _buildSpaltenSelector(
                      label: 'Bezeichnung Anlage/Bauteile',
                      value: _bezeichnungSpalte,
                      bearbeitbar: _bezeichnungBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _bezeichnungSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _bezeichnungBearbeitbar = value;
                        });
                      },
                      icon: Icons.label,
                      color: Colors.green,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Parameter
                    _buildSpaltenSelector(
                      label: 'Parameter',
                      value: _parameterSpalte,
                      bearbeitbar: _parameterBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _parameterSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _parameterBearbeitbar = value;
                        });
                      },
                      icon: Icons.settings,
                      color: Colors.teal,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Optionale Felder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Auswahl Anlagentyp (optional)
                    _buildOptionalSpaltenSelector(
                      label: 'Auswahl Anlagentyp',
                      value: _auswahlAnlagentypSpalte,
                      bearbeitbar: _auswahlAnlagentypBearbeitbar,
                      enabled: _auswahlAnlagentypSpalte != null,
                      onEnabledChanged: (enabled) {
                        setState(() {
                          if (enabled) {
                            _auswahlAnlagentypSpalte = 2;
                          } else {
                            _auswahlAnlagentypSpalte = null;
                          }
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _auswahlAnlagentypSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _auswahlAnlagentypBearbeitbar = value;
                        });
                      },
                      icon: Icons.checklist,
                      color: Colors.indigo,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Validierung
                    if (_hasDuplicateColumns())
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Achtung: Alle Spalten müssen unterschiedlich sein!',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Hinweise Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Hinweise',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHintItem('Die Spaltennummern beginnen bei 0 (erste Spalte = 0, zweite Spalte = 1, etc.)'),
                    _buildHintItem('"Auswahl Anlagentyp" ist die Spalte, die im Dropdown für die Vorlagenauswahl verwendet wird'),
                    _buildHintItem('"Bearbeitbar" bestimmt, ob die Spalte nach dem Import manuell geändert werden kann'),
                    _buildHintItem('Diese Einstellungen sind projektbezogen und werden pro Projekt gespeichert'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasDuplicateColumns() {
    final columns = <int?>[
      _gewerkSpalte,
      _anlageBauteilSpalte,
      _anlagentypSpalte,
      _bezeichnungSpalte,
      _parameterSpalte,
      _auswahlAnlagentypSpalte,
    ].where((c) => c != null).toList();
    
    return columns.length != columns.toSet().length;
  }

  Widget _buildHintItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaltenSelector({
    required String label,
    required int value,
    required bool bearbeitbar,
    required ValueChanged<int> onChanged,
    required ValueChanged<bool> onBearbeitbarChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.grid_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Spaltennummer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      child: TextField(
                        controller: TextEditingController(text: value.toString()),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.numbers, size: 18, color: color),
                        ),
                        onChanged: (text) {
                          final newValue = int.tryParse(text);
                          if (newValue != null && newValue >= 0) {
                            onChanged(newValue);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          bearbeitbar ? Icons.edit : Icons.lock,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bearbeitbar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: bearbeitbar ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: bearbeitbar ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: SwitchListTile(
                        value: bearbeitbar,
                        onChanged: onBearbeitbarChanged,
                        activeColor: color,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        dense: true,
                        title: Text(
                          bearbeitbar ? 'Ja' : 'Nein',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: bearbeitbar ? color : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalSpaltenSelector({
    required String label,
    required int? value,
    required bool bearbeitbar,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<int> onChanged,
    required ValueChanged<bool> onBearbeitbarChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onEnabledChanged,
                activeColor: color,
              ),
            ],
          ),
          if (enabled && value != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.grid_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Spaltennummer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        child: TextField(
                          controller: TextEditingController(text: value.toString()),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.numbers, size: 18, color: color),
                          ),
                          onChanged: (text) {
                            final newValue = int.tryParse(text);
                            if (newValue != null && newValue >= 0) {
                              onChanged(newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            bearbeitbar ? Icons.edit : Icons.lock,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bearbeitbar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: bearbeitbar ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: bearbeitbar ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          value: bearbeitbar,
                          onChanged: onBearbeitbarChanged,
                          activeColor: color,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          title: Text(
                            bearbeitbar ? 'Ja' : 'Nein',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: bearbeitbar ? color : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
