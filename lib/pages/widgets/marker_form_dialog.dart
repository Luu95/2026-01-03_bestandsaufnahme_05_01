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

      fields.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
            child: type == 'int'
                ? TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (val) => _params[key] = int.tryParse(val) ?? double.tryParse(val) ?? val,
                  )
                : TextField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (val) => _params[key] = val,
                  ),
          ),
        ),
      );
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
        color: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titel mit Icon
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _discipline.color.withOpacity(0.1),
                      _discipline.color.withOpacity(0.05),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _discipline.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _discipline.icon,
                        color: _discipline.color,
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
                            isEdit ? 'Marker bearbeiten' : 'Neuen Marker hinzufügen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _discipline.label,
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

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titel
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
                            controller: _titleController,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Titel des Markers',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              errorText: _titleController.text.trim().isEmpty ? 'Titel darf nicht leer sein' : null,
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

                      // Disziplin-Auswahl
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: DropdownButtonFormField<Disziplin>(
                              value: _discipline,
                              decoration: InputDecoration(
                                labelText: 'Gewerk auswählen',
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
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
                        ),
                      ),

                      // Schema-Felder
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
                    if (isEdit && widget.onDelete != null)
                      OutlinedButton(
                        onPressed: () async {
                          await widget.onDelete!(widget.existing!);
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.red[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Löschen',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isEdit && widget.onDelete != null) const SizedBox(width: 12),
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
                          const Text(
                            'Speichern',
                            style: TextStyle(
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
