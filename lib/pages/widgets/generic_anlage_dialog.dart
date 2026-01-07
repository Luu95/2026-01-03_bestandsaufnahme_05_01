// lib/pages/widgets/generic_anlage_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../services/anlage_validation_service.dart';
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

class GenericAnlageDialog extends StatefulWidget {
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
  State<GenericAnlageDialog> createState() => _GenericGewerkDialogState();
}

class _GenericGewerkDialogState extends State<GenericAnlageDialog> {
  late TextEditingController _nameController;
  final Map<String, dynamic> _params = {};
  final Map<String, TextEditingController> _controllers = {};
  late PhotoManager _photoManager;
  // Trackt Felder, die beim Initialisieren bereits befüllt waren (aus CSV)
  final Set<String> _prefilledFields = {};
  
  // Listener für Validierungs-Updates
  void _updateValidationStatus() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _photoManager = PhotoManager();
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
    _nameController = TextEditingController(text: widget.existingAnlage?.name ?? '');
    _nameController.addListener(_updateValidationStatus);
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
                      final fieldDef = widget.discipline.schema.firstWhere(
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
                  var fieldDef = widget.discipline.schema.firstWhere(
                    (f) => f['key'] == ocrKey,
                    orElse: () => <String, String>{},
                  );
                  
                  // Falls kein exakter Match: Suche über Label oder Key-Präfix
                  if (fieldDef.isEmpty) {
                    fieldDef = widget.discipline.schema.firstWhere(
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
                      orElse: () => <String, String>{},
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
                  markerType: widget.discipline.label,
                  discipline: widget.discipline,
                );

                // Setze Validierungsstatus für alle erkannten Felder, die im Schema sind
                results.forEach((ocrKey, ocrValue) {
                  // Normalisiere für Vergleich
                  String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
                  
                  // Finde das passende Feld (gleiche Logik wie oben)
                  var fieldDef = widget.discipline.schema.firstWhere(
                    (f) => f['key'] == ocrKey,
                    orElse: () => <String, String>{},
                  );
                  
                  if (fieldDef.isEmpty) {
                    fieldDef = widget.discipline.schema.firstWhere(
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
                      orElse: () => <String, String>{},
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
      markerType: widget.discipline.label,
      discipline: widget.discipline,
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
      markerType: widget.discipline.label,
      discipline: widget.discipline,
    );
    
    final isCurrentlyMissing = AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key);
    final updatedAnlage = AnlageValidationService.setFieldAsMissing(tempAnlage, key, !isCurrentlyMissing);
    _params.addAll(updatedAnlage.params);
    setState(() {});
  }

  List<Widget> _buildSchemaFields() {
    // Schema-Felder aus der Disziplin + zusätzliche Keys aus den Params,
    // damit automatisch gesetzte/aus CSV kommende Felder immer angezeigt werden.
    final schema = List<Map<String, dynamic>>.from(widget.discipline.schema);
    final schemaKeys = schema
        .map((e) => (e['key'] ?? '').toString())
        .where((k) => k.trim().isNotEmpty)
        .toSet();

    final extraKeys = _params.keys
        .where((k) =>
            !schemaKeys.contains(k) &&
            !k.startsWith('_') &&
            !k.startsWith('__') &&
            k != 'photoPaths')
        .toList()
      ..sort();

    for (final k in extraKeys) {
      schema.add({
        'key': k,
        'label': k,
        'type': 'text',
      });
    }
    final fields = <Widget>[];
    
    // Erstelle temporäre Anlage für Status-Prüfung
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _nameController.text.trim(),
      params: Map<String, dynamic>.from(_params),
      floorId: widget.floorId,
      buildingId: widget.buildingId,
      isMarker: widget.existingAnlage?.isMarker ?? false,
      markerInfo: widget.existingAnlage?.markerInfo,
      markerType: widget.discipline.label,
      discipline: widget.discipline,
    );
    
    for (var fieldDef in schema) {
      final key = fieldDef['key'] as String;
      final label = fieldDef['label'] as String;
      final type = fieldDef['type'] as String;
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: _params[key]?.toString() ?? '');
        _controllers[key]!.addListener(_updateValidationStatus);
      }
      final controller = _controllers[key]!;
      final isEmpty = controller.text.trim().isEmpty;
      final isFieldValidated = AnlageValidationService.isFieldValidated(tempAnlage, key);
      final isFieldMissing = AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key);
      
      // Bestimme Icon-Button für grobmotorische Bedienung
      Widget actionButton;
      if (isEmpty) {
        // Leeres Feld: Rotes Kreuz
        actionButton = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleFieldMissing(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldMissing
                    ? Colors.grey[200]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFieldMissing
                      ? Colors.grey[400]!
                      : Colors.red[300]!,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.close,
                color: isFieldMissing ? Colors.grey[700] : Colors.red[600],
                size: 20,
              ),
            ),
          ),
        );
      } else {
        // Befülltes Feld: 
        // - Wenn bereits beim Laden befüllt war (aus CSV): Zunächst grau, wird grün wenn manuell validiert
        // - Wenn neu eingegeben wurde: Grün (automatisch validiert)
        // Der Button wird grün, sobald das Feld validiert ist (egal ob vorausgefüllt oder neu)
        actionButton = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleFieldValidation(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldValidated
                    ? Colors.green[50]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFieldValidated
                      ? Colors.green[400]!
                      : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.check_circle,
                color: isFieldValidated ? Colors.green[600] : Colors.grey[500],
                size: 20,
              ),
            ),
          ),
        );
      }
      
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: type == 'int'
                    ? TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: label,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
                          _params[key] = int.tryParse(val) ?? double.tryParse(val) ?? val;
                          
                          // Wenn Feld geändert wird und als fehlend markiert war, Status entfernen
                          if (AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key)) {
                            final updatedAnlage = AnlageValidationService.setFieldAsMissing(tempAnlage, key, false);
                            _params.addAll(updatedAnlage.params);
                          }
                          
                          // Wenn ein leeres Feld neu befüllt wird, automatisch validieren
                          if (wasEmpty && val.trim().isNotEmpty) {
                            final updatedTempAnlage = Anlage(
                              id: widget.existingAnlage?.id ?? '',
                              parentId: widget.parentId ?? widget.existingAnlage?.parentId,
                              name: _nameController.text.trim(),
                              params: Map<String, dynamic>.from(_params),
                              floorId: widget.floorId,
                              buildingId: widget.buildingId,
                              isMarker: widget.existingAnlage?.isMarker ?? false,
                              markerInfo: widget.existingAnlage?.markerInfo,
                              markerType: widget.discipline.label,
                              discipline: widget.discipline,
                            );
                            final updatedAnlage = AnlageValidationService.setFieldValidated(updatedTempAnlage, key, true);
                            _params.addAll(updatedAnlage.params);
                          }
                          
                          _updateValidationStatus();
                        },
                      )
                    : TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: label,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
                          _params[key] = val;
                          
                          // Wenn Feld geändert wird und als fehlend markiert war, Status entfernen
                          if (AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key)) {
                            final updatedAnlage = AnlageValidationService.setFieldAsMissing(tempAnlage, key, false);
                            _params.addAll(updatedAnlage.params);
                          }
                          
                          // Wenn ein leeres Feld neu befüllt wird, automatisch validieren
                          if (wasEmpty && val.trim().isNotEmpty) {
                            final updatedTempAnlage = Anlage(
                              id: widget.existingAnlage?.id ?? '',
                              parentId: widget.parentId ?? widget.existingAnlage?.parentId,
                              name: _nameController.text.trim(),
                              params: Map<String, dynamic>.from(_params),
                              floorId: widget.floorId,
                              buildingId: widget.buildingId,
                              isMarker: widget.existingAnlage?.isMarker ?? false,
                              markerInfo: widget.existingAnlage?.markerInfo,
                              markerType: widget.discipline.label,
                              discipline: widget.discipline,
                            );
                            final updatedAnlage = AnlageValidationService.setFieldValidated(updatedTempAnlage, key, true);
                            _params.addAll(updatedAnlage.params);
                          }
                          
                          _updateValidationStatus();
                        },
                      ),
              ),
              const SizedBox(width: 8),
              actionButton,
            ],
          ),
        ),
      );
    }
    return fields;
  }
  

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingAnlage != null;
    final isBauteilCreate = !isEdit && widget.parentId != null;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isEdit
                          ? 'Anlage bearbeiten'
                          : (isBauteilCreate ? 'Neues Bauteil hinzufügen' : 'Neue Anlage hinzufügen'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // OCR-Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Typenschild scannen (OCR)'),
                      onPressed: _takePhotoForOcr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: (widget.parentId != null || widget.existingAnlage?.parentId != null) 
                            ? 'Bauteilname' 
                            : 'Anlagenname',
                        errorText: _nameController.text.trim().isEmpty ? 'Name darf nicht leer sein' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamische Felder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: _buildSchemaFields()),
                  ),
                  const SizedBox(height: 24),

                  // Fotos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Fotos (${_photoManager.images.length}/${PhotoManager.maxPhotos})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _photoManager.images.isNotEmpty
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_photoManager.images.length, (i) {
                              final f = _photoManager.images[i];
                              return RepaintBoundary(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _viewImage(f),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          f,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          cacheWidth: 160,
                                          cacheHeight: 160,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                        onPressed: () => _removeImage(i),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          )
                        : Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.photo_camera, size: 40, color: Colors.grey),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Foto aufnehmen'),
                      onPressed: _photoManager.canAddPhoto ? _takePhoto : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action-Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final name = _nameController.text.trim();
                            if (name.isEmpty) {
                              setState(() {}); // um ErrorText zu aktualisieren
                              return;
                            }
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
                              markerType: widget.discipline.label,
                              discipline: widget.discipline,
                            );

                            // Prüfe Validierung und setze Status automatisch
                            final isValidated = AnlageValidationService.isAnlageValidated(anlage);
                            anlage = AnlageValidationService.setValidatedStatus(anlage, isValidated);

                            widget.onSave(anlage, widget.index);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Speichern'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}