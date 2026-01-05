import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/marker.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../database/database_service.dart';
import 'photo_manager.dart';

/// Bottom-Sheet zum Hinzufügen oder Bearbeiten eines Markers auf dem PDF-Grundriss.
class MarkerFormDialog extends StatefulWidget {
  final Marker? existing;
  final int pageNumber;
  final double x;
  final double y;
  final String buildingId;
  final Future<void> Function(Marker) onSave;
  final Future<void> Function(Marker)? onDelete;

  const MarkerFormDialog({
    Key? key,
    required this.pageNumber,
    required this.x,
    required this.y,
    required this.buildingId,
    required this.onSave,
    this.onDelete,
    this.existing,
  }) : super(key: key);

  @override
  State<MarkerFormDialog> createState() => _MarkerFormDialogState();
}

class _MarkerFormDialogState extends State<MarkerFormDialog> {
  late TextEditingController _titleController;
  final PhotoManager _photoManager = PhotoManager();

  List<Disziplin> _availableDisciplines = [];
  bool _isLoadingDisciplines = true;
  late Disziplin _discipline;
  final Map<String, dynamic> _params = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _loadAvailableDisciplines();

    // vorhandene Fotos laden
    if (widget.existing?.params?['photoPaths'] is List) {
      final paths = List<dynamic>.from(widget.existing!.params!['photoPaths']);
      final files = paths
          .map((p) => File(p.toString()))
          .where((f) => f.existsSync())
          .toList();
      if (files.isNotEmpty) {
        _photoManager.updateImageFiles(files);
      }
    }
  }

  Future<void> _loadAvailableDisciplines() async {
    setState(() => _isLoadingDisciplines = true);

    List<Disziplin> list = [];
    final dbService = DatabaseService.instance;
    if (dbService != null) {
      list = await dbService.getDisciplinesByBuildingId(widget.buildingId);
    } else {
      // Fallback (z.B. wenn DatabaseService noch nicht initialisiert ist)
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('disziplinen_${widget.buildingId}') ?? '[]';
      final data = json.decode(jsonStr) as List<dynamic>;
      list = data
          .map((e) => Disziplin.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    setState(() {
      _availableDisciplines = list;
      if (widget.existing != null) {
        _discipline = widget.existing!.discipline;
      } else if (list.isNotEmpty) {
        _discipline = list.first;
      } else {
        _discipline = Disziplin(
          label: '',
          icon: Icons.build,
          color: Colors.grey,
          schema: [],
        );
      }
      _isLoadingDisciplines = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  void _removeImage(int index) {
    _photoManager.removeImage(index);
    setState(() {});
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

  List<Widget> _buildSchemaFields() {
    final schema = _discipline.schema;
    final fields = <Widget>[];

    for (var fieldDef in schema) {
      final key = fieldDef['key'] as String;
      final label = fieldDef['label'] as String;
      final type = fieldDef['type'] as String;

      if (!_controllers.containsKey(key)) {
        final initial = widget.existing?.params?[key]?.toString() ?? '';
        _controllers[key] = TextEditingController(text: initial);
      }
      final controller = _controllers[key]!;

      if (type == 'int') {
        fields.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
              onChanged: (val) => _params[key] = int.tryParse(val) ?? double.tryParse(val) ?? val,
            ),
          ),
        );
      } else {
        fields.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              onChanged: (val) => _params[key] = val,
            ),
          ),
        );
      }
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    // 1) Lade-Zustand abfangen
    if (_isLoadingDisciplines) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final isEdit = widget.existing != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: Colors.white, // Material-Ancestor für alle TextFields, Dropdowns etc.
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
                      isEdit ? 'Marker bearbeiten' : 'Neuen Marker hinzufügen',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Titel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Titel des Markers',
                        errorText: _titleController.text.trim().isEmpty ? 'Titel darf nicht leer sein' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Disziplin-Auswahl
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Gewerk auswählen', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<Disziplin>(
                      value: _discipline,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      isExpanded: true,
                      items: _availableDisciplines
                          .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                          .toList(),
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() {
                          _discipline = d;
                          _params.clear(); // Parameter zurücksetzen
                          _controllers.clear();
                        });
                      },
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
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                                    cacheWidth: 160, // Thumbnail-Auflösung für bessere Performance
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
                        if (isEdit && widget.onDelete != null)
                          TextButton(
                            onPressed: () async {
                              await widget.onDelete!(widget.existing!);
                              Navigator.of(context).pop();
                            },
                            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                          ),
                        ElevatedButton(
                          onPressed: () {
                            final name = _titleController.text.trim();
                            if (name.isEmpty) {
                              setState(() {}); // um ErrorText zu aktualisieren
                              return;
                            }
                            // Pfade und Schema-Parameter zusammenführen
                            final params = widget.existing?.params != null
                                ? Map<String, dynamic>.from(widget.existing!.params!)
                                : <String, dynamic>{};
                            params['photoPaths'] = _photoManager.images.map((e) => e.path).toList();
                            params.addAll(_params);

                            final marker = Marker(
                              id: widget.existing?.id ?? const Uuid().v4(),
                              discipline: _discipline,
                              title: name,
                              x: widget.x,
                              y: widget.y,
                              pageNumber: widget.pageNumber,
                              params: params,
                            );
                            widget.onSave(marker);
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
