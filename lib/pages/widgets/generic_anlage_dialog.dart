// lib/pages/widgets/generic_anlage_dialog.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/database_provider.dart';
import '../../services/anlage_validation_service.dart';
import '../../services/dropdown_csv_service.dart';
import '../../services/ocr_service.dart';
import 'photo_manager.dart';
import 'ocr_camera_page.dart';

/// Custom InputBorder, der die untere Linie rechts kürzer macht (für grobmotorische Bedienung)
class ShortenedUnderlineInputBorder extends InputBorder {
  final double rightPadding;
  
  const ShortenedUnderlineInputBorder({
    this.rightPadding = 60.0,
    super.borderSide = const BorderSide(),
  });

  @override
  InputBorder copyWith({
    BorderSide? borderSide,
    double? rightPadding,
  }) {
    return ShortenedUnderlineInputBorder(
      borderSide: borderSide ?? this.borderSide,
      rightPadding: rightPadding ?? this.rightPadding,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: borderSide.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    // Zeichne nur die untere Linie, aber kürzer (rechts endet früher)
    final left = rect.left;
    final right = rect.right - rightPadding;
    final bottom = rect.bottom;
    
    canvas.drawLine(
      Offset(left, bottom),
      Offset(right, bottom),
      borderSide.toPaint(),
    );
  }

  @override
  bool get isOutline => false;

  @override
  ShapeBorder scale(double t) {
    return ShortenedUnderlineInputBorder(
      borderSide: borderSide.scale(t),
      rightPadding: rightPadding * t,
    );
  }
}

class GenericAnlageDialog extends ConsumerStatefulWidget {
  final Disziplin discipline;
  final String buildingId;
  final String floorId;
  /// Optional: Parent-Anlage-ID (für Bauteile). Wenn gesetzt, wird beim Speichern
  /// `parentId` am neuen/editierten Datensatz entsprechend gesetzt.
  final String? parentId;
  final Anlage? existingAnlage;
  final int? index;
  final void Function(Anlage anlage, int? index) onSave;

  const GenericAnlageDialog({
    Key? key,
    required this.discipline,
    required this.buildingId,
    required this.floorId,
    this.parentId,
    this.existingAnlage,
    this.index,
    required this.onSave,
  }) : super(key: key);

  @override
  ConsumerState<GenericAnlageDialog> createState() => _GenericGewerkDialogState();
}

class _GenericGewerkDialogState extends ConsumerState<GenericAnlageDialog> {
  late TextEditingController _nameController;
  final Map<String, dynamic> _params = {};
  final Map<String, TextEditingController> _controllers = {};
  late PhotoManager _photoManager;
  DropdownCsvData? _dropdownCsvData;
  bool _isLoadingDropdownCsv = false;
  // Trackt Felder, die beim Initialisieren bereits befüllt waren (aus CSV)
  final Set<String> _prefilledFields = {};
  bool _isNameEditable = true;
  late Disziplin _currentDiscipline; // Aktuelle Disziplin-Daten (frisch aus DB geladen)
  
  // Listener für Validierungs-Updates
  void _updateValidationStatus() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _photoManager = PhotoManager();
    // Initialisiere mit übergebener Disziplin, wird dann in _initData aktualisiert
    _currentDiscipline = widget.discipline;
    _initData();
    _loadDropdownCsv();
  }

  Future<void> _loadDropdownCsv() async {
    setState(() => _isLoadingDropdownCsv = true);
    final data = await DropdownCsvService.loadForBuilding(widget.buildingId);
    if (!mounted) return;
    setState(() {
      _dropdownCsvData = data;
      _isLoadingDropdownCsv = false;
    });
  }

  Future<void> _initData() async {
    // Lade die aktuelle Disziplin aus der Datenbank, um sicherzustellen, dass Schema-Änderungen sofort wirksam werden
    try {
      final dbService = ref.read(databaseServiceProvider);
      final disciplines = await dbService.getDisciplinesByBuildingId(widget.buildingId);
      final updatedDiscipline = disciplines.firstWhere(
        (d) => d.label == widget.discipline.label,
        orElse: () => widget.discipline, // Fallback auf übergebene Disziplin
      );
      if (mounted) {
        setState(() {
          _currentDiscipline = updatedDiscipline;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Disziplin in GenericAnlageDialog: $e');
      // Bei Fehler die übergebene Disziplin verwenden
      _currentDiscipline = widget.discipline;
    }
    if (widget.existingAnlage != null) {
      _params.addAll(widget.existingAnlage!.params);
      // Tracke alle Felder, die beim Initialisieren bereits einen Wert hatten
      for (var entry in widget.existingAnlage!.params.entries) {
        final key = entry.key;
        final value = entry.value;
        // Ignoriere interne Felder (die mit _ beginnen)
        if (!key.startsWith('_') && value != null && value.toString().trim().isNotEmpty) {
          _prefilledFields.add(key);
        }
      }
      final existingPaths = widget.existingAnlage!.params['photoPaths'] as List<dynamic>?;
      if (existingPaths != null) {
        final files = existingPaths
            .map((p) => File(p.toString()))
            .where((f) => f.existsSync())
            .toList();
        _photoManager.updateImageFiles(files);
      }
    }
    
    // Stelle sicher, dass Leistungsparameter immer vorhanden ist (auch wenn leer)
    if (!_params.containsKey('Leistungsparameter')) {
      _params['Leistungsparameter'] = <String, String>{};
    }
    _nameController = TextEditingController(text: widget.existingAnlage?.name ?? '');
    _nameController.addListener(_updateValidationStatus);

    // Lade CSV-Einstellungen für Name-Bearbeitbarkeit und Vorbefüllung
    await _loadSettingsAndPrefill();
  }

  Future<void> _loadSettingsAndPrefill() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final projectId = await dbService.getProjectIdByBuildingId(widget.buildingId);
      if (projectId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_$projectId';
      final settingsJson = prefs.getString(key);
      
      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _isNameEditable = settings['nameBearbeitbar'] as bool? ?? true;
        });

        // Vorbefüllung nur bei Neuanlage
        if (widget.existingAnlage == null) {
          // Suche Felder im Schema, die diesen Spalten entsprechen
          for (var field in _currentDiscipline.schema) {
            final fieldKey = field['key'];
            if (fieldKey == null) continue;

            // Vorbefüllung "Gewerk"
            if (field['label']?.toString().toLowerCase().contains('gewerk') == true) {
              _params[fieldKey] = _currentDiscipline.label;
              if (!_controllers.containsKey(fieldKey)) {
                _controllers[fieldKey] = TextEditingController(text: _currentDiscipline.label);
                _controllers[fieldKey]!.addListener(_updateValidationStatus);
              } else {
                _controllers[fieldKey]!.text = _currentDiscipline.label;
              }
            }

            // Vorbefüllung "Anlagentyp"
            if (field['label']?.toString().toLowerCase().contains('anlagentyp') == true ||
                field['label']?.toString().toLowerCase().contains('typ') == true) {
              _params[fieldKey] = _currentDiscipline.label; // Standardmäßig das Gewerk als Typ
              if (!_controllers.containsKey(fieldKey)) {
                _controllers[fieldKey] = TextEditingController(text: _currentDiscipline.label);
                _controllers[fieldKey]!.addListener(_updateValidationStatus);
              } else {
                _controllers[fieldKey]!.text = _currentDiscipline.label;
              }
            }

            // Vorbefüllung "Anlage/Bauteil"
            if (field['label']?.toString().toLowerCase().contains('bauteil') == true ||
                field['label']?.toString().toLowerCase() == 'a/b') {
              final value = widget.parentId != null ? 'B' : 'A';
              _params[fieldKey] = value;
              if (!_controllers.containsKey(fieldKey)) {
                _controllers[fieldKey] = TextEditingController(text: value);
                _controllers[fieldKey]!.addListener(_updateValidationStatus);
              } else {
                _controllers[fieldKey]!.text = value;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Einstellungen in GenericAnlageDialog: $e');
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateValidationStatus);
    _nameController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (!_photoManager.canAddPhoto) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximal 4 Fotos pro Anlage erlaubt'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final success = await _photoManager.takePhoto();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximal 4 Fotos pro Anlage erlaubt'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
    setState(() {});
  }

  void _removeImage(int idx) {
    _photoManager.removeImage(idx);
    setState(() {});
  }

  Future<void> _takePhotoForOcr() async {
    if (!_photoManager.canAddPhoto) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximal 4 Fotos pro Anlage erlaubt'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      // Öffne Kamera-Seite mit Orientierungsrahmen direkt auf der Kamera
      final image = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          builder: (context) => const OcrCameraPage(),
          fullscreenDialog: true,
        ),
      );

      if (image != null) {
        // Füge das Bild zu den Fotos hinzu
        if (_photoManager.canAddPhoto) {
          _photoManager.updateImageFiles([..._photoManager.images, image]);
          setState(() {});
        }
        
        // Führe automatisch OCR aus
        await _performOcr(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen der Kamera: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _performOcr(File image) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final results = await OcrService.recognizeTypenschild(image);
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen

      if (results.isEmpty || (results['hersteller'] == null && results['baujahr'] == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine relevanten Daten auf dem Typenschild erkannt')),
        );
        return;
      }

      await _showOcrResultDialog(results);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Texterkennung: $e')),
      );
    }
  }

  Future<void> _showOcrResultDialog(Map<String, String> results) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.document_scanner,
                      color: Colors.green[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Typenschild-Daten erkannt',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Folgende Daten wurden erkannt:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: results.entries.map((e) {
                      // Finde das Label für den Key im Schema
                      final fieldDef = _currentDiscipline.schema.firstWhere(
                        (f) => f['key'] == e.key,
                        orElse: () => {'label': e.key},
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fieldDef['label'] ?? e.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sollen diese Daten in die entsprechenden Felder übertragen werden?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Abbrechen',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
              setState(() {
                results.forEach((ocrKey, ocrValue) {
                  // Hilfsfunktion: Normalisiert einen String für Vergleich (lowercase, Leerzeichen entfernen)
                  String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
                  
                  // 1. Suche das passende Feld im Schema
                  // Zuerst versuchen: Exakter Key-Match
                  var fieldDef = _currentDiscipline.schema.firstWhere(
                    (f) => f['key'] == ocrKey,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  // Falls kein exakter Match: Suche über Label oder Key-Präfix
                  if (fieldDef.isEmpty) {
                    fieldDef = _currentDiscipline.schema.firstWhere(
                      (f) {
                        final schemaKey = f['key'] ?? '';
                        final schemaLabel = f['label'] ?? '';
                        final normalizedOcrKey = normalize(ocrKey);
                        final normalizedSchemaLabel = normalize(schemaLabel);
                        final normalizedSchemaKey = normalize(schemaKey);
                        
                        // Prüfe ob OCR-Key mit Label übereinstimmt
                        if (normalizedSchemaLabel == normalizedOcrKey) {
                          return true;
                        }
                        
                        // Prüfe ob Schema-Key mit OCR-Key beginnt (für UUID-Endungen)
                        if (normalizedSchemaKey.startsWith(normalizedOcrKey + '_')) {
                          return true;
                        }
                        
                        // Prüfe ob Schema-Key den OCR-Key enthält (für komplexere Fälle)
                        if (normalizedSchemaKey.contains(normalizedOcrKey)) {
                          return true;
                        }
                        
                        return false;
                      },
                      orElse: () => <String, dynamic>{},
                    );
                  }
                  
                  // Wenn kein passendes Feld gefunden wurde, überspringe dieses Ergebnis
                  if (fieldDef.isEmpty) {
                    return;
                  }
                  
                  // Verwende den tatsächlichen Schema-Key (kann mit UUID-Endung sein)
                  final realKey = fieldDef['key']!;
                  final type = fieldDef['type'] ?? 'string';

                  // Setze Wert in _params
                  if (type == 'int') {
                    final num = int.tryParse(ocrValue) ?? double.tryParse(ocrValue)?.toInt();
                    if (num != null) {
                      _params[realKey] = num;
                    } else {
                      _params[realKey] = ocrValue;
                    }
                  } else {
                    _params[realKey] = ocrValue;
                  }

                  // Stelle sicher, dass Controller existiert und setze Wert
                  if (!_controllers.containsKey(realKey)) {
                    _controllers[realKey] = TextEditingController();
                    _controllers[realKey]!.addListener(_updateValidationStatus);
                  }
                  
                  // Setze den Wert im Controller (wichtig: verwende den Wert aus _params für int-Felder)
                  final displayValue = type == 'int' && _params[realKey] is int 
                      ? _params[realKey].toString() 
                      : ocrValue;
                  _controllers[realKey]!.text = displayValue;
                });
                
                // Erstelle temporäre Anlage für Status-Updates (mit bereits aktualisierten _params)
                var tempAnlage = Anlage(
                  id: widget.existingAnlage?.id ?? '',
                  parentId: widget.parentId ?? widget.existingAnlage?.parentId,
                  name: _nameController.text.trim(),
                  params: Map<String, dynamic>.from(_params),
                  floorId: widget.floorId,
                  buildingId: widget.buildingId,
                  isMarker: widget.existingAnlage?.isMarker ?? false,
                  markerInfo: widget.existingAnlage?.markerInfo,
                  markerType: _currentDiscipline.label,
                  discipline: _currentDiscipline,
                );

                // Setze Validierungsstatus für alle erkannten Felder, die im Schema sind
                results.forEach((ocrKey, ocrValue) {
                  // Normalisiere für Vergleich
                  String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
                  
                  // Finde das passende Feld (gleiche Logik wie oben)
                  var fieldDef = _currentDiscipline.schema.firstWhere(
                    (f) => f['key'] == ocrKey,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (fieldDef.isEmpty) {
                    fieldDef = _currentDiscipline.schema.firstWhere(
                      (f) {
                        final schemaKey = f['key'] ?? '';
                        final schemaLabel = f['label'] ?? '';
                        final normalizedOcrKey = normalize(ocrKey);
                        final normalizedSchemaLabel = normalize(schemaLabel);
                        final normalizedSchemaKey = normalize(schemaKey);
                        
                        if (normalizedSchemaLabel == normalizedOcrKey) return true;
                        if (normalizedSchemaKey.startsWith(normalizedOcrKey + '_')) return true;
                        if (normalizedSchemaKey.contains(normalizedOcrKey)) return true;
                        return false;
                      },
                      orElse: () => <String, dynamic>{},
                    );
                  }
                  
                  if (fieldDef.isNotEmpty) {
                    final realKey = fieldDef['key']!;
                    tempAnlage = AnlageValidationService.setFieldAsMissing(tempAnlage, realKey, false);
                    tempAnlage = AnlageValidationService.setFieldValidated(tempAnlage, realKey, true);
                  }
                });
                
                // Params synchronisieren (Metadaten zurück in _params)
                _params.addAll(tempAnlage.params);
                
                // Validierungsstatus aktualisieren
                _updateValidationStatus();
              });
              Navigator.of(context).pop();
            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Übertragen',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewImage(File image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(image, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.photo_library,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Fotos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        Text(
                          '${_photoManager.images.length}/${PhotoManager.maxPhotos}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _photoManager.canAddPhoto
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _photoManager.canAddPhoto ? _takePhoto : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              color: _photoManager.canAddPhoto
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hinzufügen',
                              style: TextStyle(
                                color: _photoManager.canAddPhoto
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_photoManager.images.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Noch keine Fotos',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_photoManager.images.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoManager.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final f = _photoManager.images[i];
                    return RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _viewImage(f),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  f,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  cacheWidth: 220,
                                  cacheHeight: 220,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _removeImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleFieldValidation(String key) {
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _nameController.text.trim(),
      params: Map<String, dynamic>.from(_params),
      floorId: widget.floorId,
      buildingId: widget.buildingId,
      isMarker: widget.existingAnlage?.isMarker ?? false,
      markerInfo: widget.existingAnlage?.markerInfo,
      markerType: _currentDiscipline.label,
      discipline: _currentDiscipline,
    );
    
    final isCurrentlyValidated = AnlageValidationService.isFieldValidated(tempAnlage, key);
    final updatedAnlage = AnlageValidationService.setFieldValidated(tempAnlage, key, !isCurrentlyValidated);
    _params.addAll(updatedAnlage.params);
    setState(() {});
  }

  void _toggleFieldMissing(String key) {
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _nameController.text.trim(),
      params: Map<String, dynamic>.from(_params),
      floorId: widget.floorId,
      buildingId: widget.buildingId,
      isMarker: widget.existingAnlage?.isMarker ?? false,
      markerInfo: widget.existingAnlage?.markerInfo,
      markerType: _currentDiscipline.label,
      discipline: _currentDiscipline,
    );
    
    final isCurrentlyMissing = AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key);
    final updatedAnlage = AnlageValidationService.setFieldAsMissing(tempAnlage, key, !isCurrentlyMissing);
    _params.addAll(updatedAnlage.params);
    setState(() {});
  }

  List<Widget> _buildSchemaFields() {
    // Verwende nur die Felder aus dem Schema - keine extraKeys mehr hinzufügen
    // Das stellt sicher, dass nur die definierten Felder angezeigt werden
    final schema = List<Map<String, dynamic>>.from(_currentDiscipline.schema);
    final parameterKeyFromCsv = _params['__parameterKey']?.toString();
    
    final fields = <Widget>[];
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _nameController.text.trim(),
      params: Map<String, dynamic>.from(_params),
      floorId: widget.floorId,
      buildingId: widget.buildingId,
      isMarker: widget.existingAnlage?.isMarker ?? false,
      markerInfo: widget.existingAnlage?.markerInfo,
      markerType: _currentDiscipline.label,
      discipline: _currentDiscipline,
    );
    
    for (var fieldDef in schema) {
      final key = fieldDef['key'] as String;
      
      // EXPLIZIT: Falls der Key "Parameter" oder "Leistungsparameter" ist, oben nicht anzeigen!
      if (key == 'Leistungsparameter' || (parameterKeyFromCsv != null && key == parameterKeyFromCsv)) continue;

      final label = fieldDef['label'] as String;
      final type = (fieldDef['type'] ?? 'string').toString();
      final isEditable = fieldDef['editable'] ?? true;
      final dropdownColumn = (fieldDef['dropdownColumn'] ?? '').toString().trim();
      
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: _params[key]?.toString() ?? '');
        _controllers[key]!.addListener(_updateValidationStatus);
      }
      final controller = _controllers[key]!;
      final isEmpty = controller.text.trim().isEmpty;
      final isFieldValidated = AnlageValidationService.isFieldValidated(tempAnlage, key);
      final isFieldMissing = AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key);

      Widget actionButton;
      if (isEmpty) {
        actionButton = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEditable ? () => _toggleFieldMissing(key) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldMissing ? Colors.grey[200] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFieldMissing ? Colors.grey[400]! : Colors.red[300]!, width: 1.5),
              ),
              child: Icon(Icons.close, color: isFieldMissing ? Colors.grey[700] : Colors.red[600], size: 20),
            ),
          ),
        );
      } else {
        actionButton = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEditable ? () => _toggleFieldValidation(key) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldValidated ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFieldValidated ? Colors.green[400]! : Colors.grey[400]!, width: 1.5),
              ),
              child: Icon(Icons.check_circle, color: isFieldValidated ? Colors.green[600] : Colors.grey[500], size: 20),
            ),
          ),
        );
      }

      Future<void> pickDate() async {
        if (isEditable != true) return;
        DateTime initialDate = DateTime.now();
        final current = controller.text.trim();
        if (current.isNotEmpty) {
          final parsed = DateTime.tryParse(current);
          if (parsed != null) initialDate = parsed;
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        final iso = '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';

        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        controller.text = iso;
        _params[key] = iso;
        if (wasEmpty && iso.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlage, key, true).params);
        }
        _updateValidationStatus();
      }

      void applyTextValue(String val) {
        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        _params[key] = val;
        if (wasEmpty && val.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlage, key, true).params);
        }
        _updateValidationStatus();
      }

      void applyNumericValue(String val) {
        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        _params[key] = (num.tryParse(val) ?? val);
        if (wasEmpty && val.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlage, key, true).params);
        }
        _updateValidationStatus();
      }

      Widget inputWidget;
      if (type == 'dropdown') {
        final data = _dropdownCsvData;
        final options = (data != null && dropdownColumn.isNotEmpty)
            ? (data.valuesByHeader[dropdownColumn] ?? const <String>[])
            : const <String>[];

        String? currentValue = controller.text.trim().isEmpty ? null : controller.text.trim();
        if (currentValue != null && options.isNotEmpty && !options.contains(currentValue)) {
          currentValue = null;
        }

        inputWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: currentValue,
              isExpanded: true,
              items: options
                  .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                  .toList(),
              onChanged: (isEditable == true && options.isNotEmpty)
                  ? (v) {
                      controller.text = v ?? '';
                      applyTextValue(v ?? '');
                    }
                  : null,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                suffixIcon: isEditable == true
                    ? null
                    : Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
              ),
            ),
            if (_isLoadingDropdownCsv)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Dropdown-Werte werden geladen …',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )
            else if (data == null || data.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  data?.error ?? 'Keine Dropdown-CSV importiert',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              )
            else if (dropdownColumn.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Keine Dropdown-Spalte konfiguriert (im Feld bearbeiten).',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              )
            else if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Keine Werte in Spalte „$dropdownColumn“ gefunden.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
          ],
        );
      } else {
        inputWidget = TextField(
          controller: controller,
          readOnly: isEditable != true || type == 'date',
          onTap: (isEditable == true && type == 'date') ? pickDate : null,
          keyboardType:
              (type == 'number' || type == 'int') ? TextInputType.number : TextInputType.text,
          style: TextStyle(
            fontSize: 15,
            color: isEditable == true ? Colors.grey[900] : Colors.grey[600],
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
            border: InputBorder.none,
            suffixIcon: isEditable == true
                ? (type == 'date'
                    ? const Icon(Icons.calendar_today, size: 16)
                    : null)
                : Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
          ),
          onChanged: (val) {
            if (isEditable != true) return;
            if (type == 'number' || type == 'int') {
              applyNumericValue(val);
            } else {
              applyTextValue(val);
            }
          },
        );
      }

      fields.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: !isEditable ? Colors.grey[100] : (isFieldMissing ? Colors.grey[200] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFieldValidated ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
              width: isFieldValidated ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: inputWidget,
                ),
                actionButton,
              ],
            ),
          ),
        ),
      );
    }

    return fields;
  }

  Widget _buildLeistungsparameterSection() {
    // 1. Hole die Map der Leistungsparameter
    var leistungsparameter = _params['Leistungsparameter'];
    final parameterKeyFromCsv = _params['__parameterKey']?.toString();
    
    // 2. Falls ein konfiguriertes Parameter-Feld (Text aus CSV) existiert, aber noch nicht in die Map gewandelt wurde
    if (parameterKeyFromCsv != null && _params.containsKey(parameterKeyFromCsv) && (leistungsparameter == null || (leistungsparameter is Map && leistungsparameter.isEmpty))) {
      final String raw = _params[parameterKeyFromCsv].toString();
      if (raw.isNotEmpty) {
        final Map<String, String> lpMap = {};
        for (var label in raw.split(RegExp(r'[,;]'))) {
          final trimmed = label.trim();
          if (trimmed.isNotEmpty) lpMap[trimmed] = '';
        }
        _params['Leistungsparameter'] = lpMap;
        leistungsparameter = lpMap;
      }
    }

    Map<String, String> lpMap = {};
    if (leistungsparameter is Map) {
      lpMap = Map<String, String>.from(leistungsparameter);
    }
    
    final keys = lpMap.keys.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.settings_input_component, color: Colors.orange[700], size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Leistungsparameter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[900])),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
                  onPressed: () async {
                    String? newLabel = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String label = '';
                        return AlertDialog(
                          title: const Text('Neuer Parameter'),
                          content: TextField(
                            decoration: const InputDecoration(hintText: 'Bezeichnung'),
                            onChanged: (val) => label = val,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                            TextButton(onPressed: () => Navigator.pop(context, label), child: const Text('Hinzufügen')),
                          ],
                        );
                      },
                    );
                    if (newLabel != null && newLabel.trim().isNotEmpty) {
                      setState(() {
                        lpMap[newLabel.trim()] = '';
                        _params['Leistungsparameter'] = lpMap;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...keys.map((label) {
              final value = lpMap[label] ?? '';
              if (!_controllers.containsKey('lp_$label')) {
                _controllers['lp_$label'] = TextEditingController(text: value);
                _controllers['lp_$label']!.addListener(_updateValidationStatus);
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers['lp_$label'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[900]),
                        decoration: InputDecoration(
                          labelText: label,
                          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          lpMap[label] = val;
                          _params['Leistungsparameter'] = lpMap;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          lpMap.remove(label);
                          _controllers['lp_$label']?.dispose();
                          _controllers.remove('lp_$label');
                          _params['Leistungsparameter'] = lpMap;
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingAnlage != null;
    final isBauteilCreate = !isEdit && widget.parentId != null;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titel mit OCR-Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.discipline.color.withOpacity(0.1),
                      widget.discipline.color.withOpacity(0.05),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.discipline.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.discipline.icon,
                              color: widget.discipline.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEdit
                                      ? 'Anlage bearbeiten'
                                      : (isBauteilCreate ? 'Neues Bauteil erfassen' : 'Neue Anlage erfassen'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.discipline.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _takePhotoForOcr,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.document_scanner,
                                  color: Theme.of(context).primaryColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'OCR',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _nameController,
                            readOnly: !_isNameEditable,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _isNameEditable ? Colors.black87 : Colors.grey[600],
                            ),
                            decoration: InputDecoration(
                              labelText: (widget.parentId != null || widget.existingAnlage?.parentId != null) 
                                  ? 'Bauteilname' 
                                  : 'Anlagenname',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              suffixIcon: !_isNameEditable ? Icon(Icons.lock_outline, size: 18, color: Colors.grey[400]) : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),

                      // Normale Schema-Felder (aus CSV-Spalten)
                      // Spezielle Leistungsparameter (aus der Parameter-Zelle)
                      const SizedBox(height: 8),
                      _buildLeistungsparameterSection(),

                      const SizedBox(height: 8),
                      ..._buildSchemaFields(),

                      // Fotos
                      const SizedBox(height: 8),
                      _buildPhotoSection(),
                    ],
                  ),
                ),
              ),

              // Aktion-Buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 
                          MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Abbrechen',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;
                        _params['photoPaths'] = _photoManager.images.map((e) => e.path).toList();

                        // Erstelle Anlage
                        var anlage = Anlage(
                          id: widget.existingAnlage?.id ?? const Uuid().v4(),
                          parentId: widget.parentId ?? widget.existingAnlage?.parentId,
                          name: name,
                          params: _params,
                          floorId: widget.floorId,
                          buildingId: widget.buildingId,
                          isMarker: widget.existingAnlage?.isMarker ?? false,
                          markerInfo: widget.existingAnlage?.markerInfo,
                          markerType: _currentDiscipline.label,
                          discipline: _currentDiscipline,
                        );

                        // Prüfe Validierung und setze Status automatisch
                        final isValidated = AnlageValidationService.isAnlageValidated(anlage);
                        anlage = AnlageValidationService.setValidatedStatus(anlage, isValidated);

                        widget.onSave(anlage, widget.index);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Speichern',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
