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
  // Intern 0-basiert speichern, aber 1-basiert anzeigen
  int _lfdNummerSpalte = 0; // Wird als Spalte 1 angezeigt
  int _nameSpalte = 1; // Wird als Spalte 2 angezeigt
  int _gewerkSpalte = 2; // Wird als Spalte 3 angezeigt
  int? _anlageBauteilSpalte;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    // Automatisch speichern beim Verlassen
    _saveSettings();
    super.dispose();
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
      'anlageBauteilSpalte': _anlageBauteilSpalte,
    };
    await prefs.setString(key, json.encode(settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CSV-Einstellungen',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Spaltenzuordnung Card
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_chart_outlined,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Spaltenzuordnung',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Geben Sie die Spaltennummern (beginnend bei 1) für die jeweiligen Felder an.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  
                  // Laufende Nummer
                  _buildSpaltenSelector(
                    label: 'Laufende Nummer (lfd Nummer)',
                    value: _lfdNummerSpalte + 1, // 1-basiert anzeigen
                    onChanged: (userValue) {
                      setState(() {
                        _lfdNummerSpalte = userValue - 1; // Zurück zu 0-basiert
                      });
                    },
                    icon: Icons.numbers_outlined,
                    color: Colors.grey[700]!,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Name
                  _buildSpaltenSelector(
                    label: 'Anlagenname',
                    value: _nameSpalte + 1, // 1-basiert anzeigen
                    onChanged: (userValue) {
                      setState(() {
                        _nameSpalte = userValue - 1; // Zurück zu 0-basiert
                      });
                    },
                    icon: Icons.label_outline,
                    color: Colors.grey[700]!,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Gewerk
                  _buildSpaltenSelector(
                    label: 'Gewerk (Disziplin)',
                    value: _gewerkSpalte + 1, // 1-basiert anzeigen
                    onChanged: (userValue) {
                      setState(() {
                        _gewerkSpalte = userValue - 1; // Zurück zu 0-basiert
                      });
                    },
                    icon: Icons.build_outlined,
                    color: Colors.grey[700]!,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Anlage/Bauteil
                  _buildSpaltenSelector(
                    label: 'Anlage/Bauteil (a/b)',
                    value: _anlageBauteilSpalte != null ? _anlageBauteilSpalte! + 1 : -1, // 1-basiert anzeigen
                    onChanged: (userValue) {
                      setState(() {
                        _anlageBauteilSpalte = userValue >= 1 ? userValue - 1 : null; // Zurück zu 0-basiert
                      });
                    },
                    icon: Icons.category_outlined,
                    color: Colors.grey[700]!,
                    isOptional: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Validierung
                  if (_lfdNummerSpalte == _nameSpalte ||
                      _lfdNummerSpalte == _gewerkSpalte ||
                      _nameSpalte == _gewerkSpalte ||
                      (_anlageBauteilSpalte != null && (
                        _anlageBauteilSpalte == _lfdNummerSpalte ||
                        _anlageBauteilSpalte == _nameSpalte ||
                        _anlageBauteilSpalte == _gewerkSpalte)))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Alle Spalten müssen unterschiedlich sein',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
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
          
          // Hinweise Card
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hinweise',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHintItem(
                    'Die Spaltennummern beginnen bei 1 (erste Spalte = 1, zweite Spalte = 2, etc.)',
                  ),
                  const SizedBox(height: 8),
                  _buildHintItem(
                    'Die Parameter-Spalten beginnen automatisch nach der höchsten angegebenen Spalte',
                  ),
                  const SizedBox(height: 8),
                  _buildHintItem(
                    'Diese Einstellungen sind projektbezogen und werden pro Projekt gespeichert',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHintItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 10),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[500],
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpaltenSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required IconData icon,
    required Color color,
    bool isOptional = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      isOptional ? 'Spalte (optional): ' : 'Spalte: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Container(
                      width: 75,
                      child: TextField(
                        controller: TextEditingController(
                          text: value >= 1 ? value.toString() : '',
                        )..selection = TextSelection.fromPosition(
                          TextPosition(offset: value >= 1 ? value.toString().length : 0),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor.withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          hintText: isOptional ? 'leer' : null,
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        onChanged: (text) {
                          if (text.isEmpty && isOptional) {
                            onChanged(-1);
                          } else {
                            final newValue = int.tryParse(text);
                            if (newValue != null && newValue >= 1) {
                              onChanged(newValue);
                            }
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
    );
  }
}

