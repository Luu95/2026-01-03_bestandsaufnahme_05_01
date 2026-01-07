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
    };
    await prefs.setString(key, json.encode(settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV-Einstellungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Einstellungen gespeichert'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spaltenzuordnung',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Geben Sie die Spaltennummern (beginnend bei 0) für die jeweiligen Felder an.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Laufende Nummer
                  _buildSpaltenSelector(
                    label: 'Laufende Nummer (lfd Nummer)',
                    value: _lfdNummerSpalte,
                    onChanged: (value) {
                      setState(() {
                        _lfdNummerSpalte = value;
                      });
                    },
                    icon: Icons.numbers,
                    color: Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name
                  _buildSpaltenSelector(
                    label: 'Anlagenname',
                    value: _nameSpalte,
                    onChanged: (value) {
                      setState(() {
                        _nameSpalte = value;
                      });
                    },
                    icon: Icons.label,
                    color: Colors.green,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Gewerk
                  _buildSpaltenSelector(
                    label: 'Gewerk (Disziplin)',
                    value: _gewerkSpalte,
                    onChanged: (value) {
                      setState(() {
                        _gewerkSpalte = value;
                      });
                    },
                    icon: Icons.build,
                    color: Colors.orange,
                  ),
                  
                  const SizedBox(height: 16),

                  // Etage (optional)
                  Row(
                    children: [
                      Icon(Icons.layers, color: Colors.indigo, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Etage',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Switch(
                                  value: _etageSpalte != null,
                                  onChanged: (enabled) {
                                    setState(() {
                                      if (enabled) {
                                        _etageSpalte = 3; // Default
                                      } else {
                                        _etageSpalte = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_etageSpalte != null)
                              Row(
                                children: [
                                  const Text(
                                    'Spalte: ',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Container(
                                    width: 80,
                                    child: TextField(
                                      controller: TextEditingController(text: _etageSpalte.toString()),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (text) {
                                        final newValue = int.tryParse(text);
                                        if (newValue != null && newValue >= 0) {
                                          setState(() {
                                            _etageSpalte = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Anlage/Bauteil (optional)
                  Row(
                    children: [
                      Icon(Icons.account_tree, color: Colors.purple, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Anlage/Bauteil (A/B)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Switch(
                                  value: _anlageBauteilSpalte != null,
                                  onChanged: (enabled) {
                                    setState(() {
                                      if (enabled) {
                                        _anlageBauteilSpalte = 3; // Default
                                      } else {
                                        _anlageBauteilSpalte = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_anlageBauteilSpalte != null)
                              Row(
                                children: [
                                  const Text(
                                    'Spalte: ',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Container(
                                    width: 80,
                                    child: TextField(
                                      controller: TextEditingController(text: _anlageBauteilSpalte.toString()),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (text) {
                                        final newValue = int.tryParse(text);
                                        if (newValue != null && newValue >= 0) {
                                          setState(() {
                                            _anlageBauteilSpalte = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Validierung
                  if (_lfdNummerSpalte == _nameSpalte ||
                      _lfdNummerSpalte == _gewerkSpalte ||
                      _nameSpalte == _gewerkSpalte ||
                      (_etageSpalte != null && (_etageSpalte == _lfdNummerSpalte || _etageSpalte == _nameSpalte || _etageSpalte == _gewerkSpalte)) ||
                      (_anlageBauteilSpalte != null && (_anlageBauteilSpalte == _lfdNummerSpalte || _anlageBauteilSpalte == _nameSpalte || _anlageBauteilSpalte == _gewerkSpalte || (_etageSpalte != null && _anlageBauteilSpalte == _etageSpalte))))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Achtung: Alle Spalten müssen unterschiedlich sein!',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
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
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hinweise',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Die Spaltennummern beginnen bei 0 (erste Spalte = 0, zweite Spalte = 1, etc.)\n'
                    '• Die Parameter-Spalten beginnen automatisch nach der höchsten angegebenen Spalte\n'
                    '• Diese Einstellungen sind projektbezogen und werden pro Projekt gespeichert',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
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
    required ValueChanged<int> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Spalte: ',
                    style: TextStyle(fontSize: 14),
                  ),
                  Container(
                    width: 80,
                    child: TextField(
                      controller: TextEditingController(text: value.toString()),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
            ],
          ),
        ),
      ],
    );
  }
}

