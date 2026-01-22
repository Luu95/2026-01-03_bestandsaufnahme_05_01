// lib/pages/csv_settings_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CsvSettingsPage extends StatefulWidget {
  final String projectId;

  const CsvSettingsPage({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<CsvSettingsPage> createState() => _CsvSettingsPageState();
}

class _CsvSettingsPageState extends State<CsvSettingsPage> {
  int _lfdNummerSpalte = 0;
  int _nameSpalte = 1;
  int _gewerkSpalte = 2;
  int? _etageSpalte;
  int? _anlageBauteilSpalte;
  int? _parameterSpalte;
  
  // Bearbeitbar-Flags für jede Spalte
  bool _lfdNummerBearbeitbar = true;
  bool _nameBearbeitbar = true;
  bool _gewerkBearbeitbar = true;
  bool _etageBearbeitbar = true;
  bool _anlageBauteilBearbeitbar = true;
  bool _parameterBearbeitbar = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_${widget.projectId}';
    final settingsJson = prefs.getString(key);
    
    if (settingsJson != null) {
      try {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _lfdNummerSpalte = settings['lfdNummerSpalte'] as int? ?? 0;
          _nameSpalte = settings['nameSpalte'] as int? ?? 1;
          _gewerkSpalte = settings['gewerkSpalte'] as int? ?? 2;
          _etageSpalte = settings['etageSpalte'] as int?;
          _anlageBauteilSpalte = settings['anlageBauteilSpalte'] as int?;
          _parameterSpalte = settings['parameterSpalte'] as int?;
          
          // Bearbeitbar-Flags laden
          _lfdNummerBearbeitbar = settings['lfdNummerBearbeitbar'] as bool? ?? true;
          _nameBearbeitbar = settings['nameBearbeitbar'] as bool? ?? true;
          _gewerkBearbeitbar = settings['gewerkBearbeitbar'] as bool? ?? true;
          _etageBearbeitbar = settings['etageBearbeitbar'] as bool? ?? true;
          _anlageBauteilBearbeitbar = settings['anlageBauteilBearbeitbar'] as bool? ?? true;
          _parameterBearbeitbar = settings['parameterBearbeitbar'] as bool? ?? true;
        });
      } catch (e) {
        // Fehler beim Laden, verwende Standardwerte
      }
    }
  }

  Future<void> _saveSettings() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV-Einstellungen'),
        elevation: 0,
        actions: [
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
                      'Konfigurieren Sie die Spaltenzuordnung und Bearbeitbarkeit für den CSV-Import.',
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
                    
                    // Laufende Nummer
                    _buildSpaltenSelector(
                      label: 'Laufende Nummer',
                      value: _lfdNummerSpalte,
                      bearbeitbar: _lfdNummerBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _lfdNummerSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _lfdNummerBearbeitbar = value;
                        });
                      },
                      icon: Icons.numbers,
                      color: Colors.blue,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Name
                    _buildSpaltenSelector(
                      label: 'Anlagenname',
                      value: _nameSpalte,
                      bearbeitbar: _nameBearbeitbar,
                      onChanged: (value) {
                        setState(() {
                          _nameSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _nameBearbeitbar = value;
                        });
                      },
                      icon: Icons.label,
                      color: Colors.green,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Gewerk
                    _buildSpaltenSelector(
                      label: 'Gewerk (Disziplin)',
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

                    // Etage (optional)
                    _buildOptionalSpaltenSelector(
                      label: 'Etage',
                      value: _etageSpalte,
                      bearbeitbar: _etageBearbeitbar,
                      enabled: _etageSpalte != null,
                      onEnabledChanged: (enabled) {
                        setState(() {
                          if (enabled) {
                            _etageSpalte = 3;
                          } else {
                            _etageSpalte = null;
                          }
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _etageSpalte = value;
                        });
                      },
                      onBearbeitbarChanged: (value) {
                        setState(() {
                          _etageBearbeitbar = value;
                        });
                      },
                      icon: Icons.layers,
                      color: Colors.indigo,
                    ),
                    
                    const Divider(height: 32),
                    
                    // Anlage/Bauteil (optional)
                    _buildOptionalSpaltenSelector(
                      label: 'Anlage/Bauteil (A/B)',
                      value: _anlageBauteilSpalte,
                      bearbeitbar: _anlageBauteilBearbeitbar,
                      enabled: _anlageBauteilSpalte != null,
                      onEnabledChanged: (enabled) {
                        setState(() {
                          if (enabled) {
                            _anlageBauteilSpalte = 3;
                          } else {
                            _anlageBauteilSpalte = null;
                          }
                        });
                      },
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
                    _buildHintItem('Die Parameter-Spalten beginnen automatisch nach der höchsten angegebenen Spalte'),
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
      _lfdNummerSpalte,
      _nameSpalte,
      _gewerkSpalte,
      _etageSpalte,
      _anlageBauteilSpalte,
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
