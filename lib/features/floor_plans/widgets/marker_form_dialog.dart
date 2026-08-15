/// Marker auf dem PDF-Grundriss anlegen oder bearbeiten (inkl. Fotos).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/models/marker.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/core/utils/photo_file_utils.dart';
import 'package:bestandsaufnahme_01/features/media/widgets/photo_manager.dart';

/// Bottom-Sheet zum Hinzufügen oder Bearbeiten eines Markers auf dem PDF-Grundriss.
class MarkerFormDialog extends StatefulWidget {
  final DatabaseService dbService;
  final Marker? existing;
  final int pageNumber;
  final double x;
  final double y;
  final String buildingId;
  final Future<void> Function(Marker) onSave;
  final Future<void> Function(Marker)? onDelete;
  final Future<void> Function()? onRemoveFromFloorPlan;

  /// Optional: bestehende Anlagen auswählen (statt neu anlegen).
  /// Wenn gesetzt, wird im "Neu"-Dialog ein zusätzlicher Tab "Bestehend" angezeigt.
  final List<Anlage>? selectableExistingAnlagen;
  final Future<void> Function(Anlage)? onSelectExistingAnlage;

  const MarkerFormDialog({
    Key? key,
    required this.dbService,
    required this.pageNumber,
    required this.x,
    required this.y,
    required this.buildingId,
    required this.onSave,
    this.onDelete,
    this.onRemoveFromFloorPlan,
    this.existing,
    this.selectableExistingAnlagen,
    this.onSelectExistingAnlage,
  }) : super(key: key);

  @override
  State<MarkerFormDialog> createState() => _MarkerFormDialogState();
}

/// Formular-State inkl. optionalem Tab „Bestehende Anlage wählen“.
class _MarkerFormDialogState extends State<MarkerFormDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  final PhotoManager _photoManager = PhotoManager();

  List<Disziplin> _availableDisciplines = [];
  bool _isLoadingDisciplines = true;
  late Disziplin _discipline;
  final Map<String, dynamic> _params = {};
  final Map<String, TextEditingController> _controllers = {};

  TabController? _tabController;
  final TextEditingController _existingSearchController = TextEditingController();
  String _existingQuery = '';
  final Set<String> _expandedExistingDisciplines = <String>{};
  bool _isSelectingExisting = false;

  bool get _supportsExistingSelection =>
      widget.existing == null && widget.onSelectExistingAnlage != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _loadAvailableDisciplines();

    if (_supportsExistingSelection) {
      _tabController = TabController(length: 2, vsync: this, initialIndex: 0)
        ..addListener(() {
          if (!mounted) return;
          setState(() {});
        });

      _existingSearchController.addListener(() {
        final next = _existingSearchController.text.trim();
        if (next == _existingQuery) return;
        setState(() => _existingQuery = next);
      });

      // Erste Disziplin (falls vorhanden) initial aufklappen, um Scroll zu sparen.
      final candidates = widget.selectableExistingAnlagen ?? const <Anlage>[];
      final labels = candidates
          .map((a) => a.discipline.label)
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (labels.isNotEmpty) {
        _expandedExistingDisciplines.add(labels.first);
      }
    }

    // vorhandene Fotos laden
    _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    if (widget.existing?.params?['photoPaths'] is! List) return;
    final paths = List<dynamic>.from(widget.existing!.params!['photoPaths']);
    final files = await filterExistingPhotoFiles(paths);
    if (files.isNotEmpty && mounted) {
      setState(() => _photoManager.updateImageFiles(files));
    }
  }

  Future<void> _loadAvailableDisciplines() async {
    setState(() => _isLoadingDisciplines = true);

    final list = await widget.dbService.getDisciplinesByBuildingId(widget.buildingId);

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
    _existingSearchController.dispose();
    _tabController?.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (!_photoManager.canAddPhoto) {
      return;
    }

    await _photoManager.takePhoto();
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
                        color: AppPalette.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.photo_library,
                        color: AppPalette.primaryDark,
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
                                    color: AppPalette.error,
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
      final type = (fieldDef['type'] ?? 'string').toString();
      final editable = (fieldDef['editable'] ?? true) == true;
      if (!_controllers.containsKey(key)) {
        final initial = widget.existing?.params?[key]?.toString() ?? '';
        _controllers[key] = TextEditingController(text: initial);
      }
      final controller = _controllers[key]!;

      Future<void> pickDate() async {
        if (!editable) return;
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
        controller.text = iso;
        _params[key] = iso;
        setState(() {});
      }

      Widget input;
      if (type == 'int' || type == 'number') {
        input = TextField(
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
        );
      } else if (type == 'date') {
        input = TextField(
          controller: controller,
          readOnly: true,
          onTap: editable ? pickDate : null,
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
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
        );
      } else if (type == 'dropdown') {
        final inlineOptions = fieldDef['options'];
        List<String> options = const [];
        if (inlineOptions is List && inlineOptions.isNotEmpty) {
          options = inlineOptions.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }

        String? currentValue;
        if (_params.containsKey(key)) {
          currentValue = _params[key]?.toString();
        } else {
          final v = widget.existing?.params?[key]?.toString();
          currentValue = v;
        }
        if (currentValue != null && options.isNotEmpty && !options.contains(currentValue)) {
          currentValue = null;
        }

        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: currentValue,
              isExpanded: true,
              items: options
                  .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                  .toList(),
              onChanged: (!editable || options.isEmpty) ? null : (v) {
                setState(() {
                  _params[key] = v;
                  controller.text = v ?? '';
                });
              },
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Keine Dropdown-Optionen definiert.',
                  style: TextStyle(fontSize: 12, color: AppPalette.warningText),
                ),
              ),
          ],
        );
      } else {
        input = TextField(
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
        );
      }

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
            child: input,
          ),
        ),
      );
    }

    return fields;
  }

  String _existingSubtitle(Anlage a) {
    final lfd = a.params['lfdNummer']?.toString().trim() ?? '';
    final hersteller = a.params.entries
        .where((e) => e.key.toLowerCase() == 'hersteller')
        .map((e) => e.value?.toString().trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final parts = <String>[
      a.discipline.label.trim(),
      if (lfd.isNotEmpty) 'lfd: $lfd',
      if (hersteller.isNotEmpty) hersteller,
    ].where((s) => s.isNotEmpty).toList();

    return parts.join(' · ');
  }

  List<Anlage> _filteredExisting() {
    final list = widget.selectableExistingAnlagen ?? const <Anlage>[];
    if (_existingQuery.isEmpty) return list;
    final q = _existingQuery.toLowerCase();
    return list.where((a) {
      final name = a.name.toLowerCase();
      final lfd = (a.params['lfdNummer']?.toString() ?? '').toLowerCase();
      final hersteller = a.params.entries
          .where((e) => e.key.toLowerCase() == 'hersteller')
          .map((e) => e.value?.toString() ?? '')
          .join(' ')
          .toLowerCase();
      return name.contains(q) || lfd.contains(q) || hersteller.contains(q);
    }).toList();
  }

  Map<String, List<Anlage>> _groupByDiscipline(List<Anlage> list) {
    final grouped = <String, List<Anlage>>{};
    for (final a in list) {
      grouped.putIfAbsent(a.discipline.label, () => <Anlage>[]).add(a);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));
    }
    return grouped;
  }

  Widget _buildExistingSelector() {
    final filtered = _filteredExisting();

    if ((widget.selectableExistingAnlagen ?? const <Anlage>[]).isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Keine bestehenden Anlagen für diesen Grundriss verfügbar.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
            ),
            child: TextField(
              controller: _existingSearchController,
              decoration: InputDecoration(
                hintText: 'Suche (Name, lfdNummer, Hersteller)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _existingQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _existingSearchController.clear(),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _existingQuery.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final a = filtered[i];
                    return ListTile(
                      enabled: !_isSelectingExisting,
                      leading: Icon(a.discipline.icon, color: a.discipline.uiColor),
                      title: Text(a.name),
                      subtitle: Text(_existingSubtitle(a)),
                      onTap: _isSelectingExisting
                          ? null
                          : () async {
                              setState(() => _isSelectingExisting = true);
                              try {
                                await widget.onSelectExistingAnlage?.call(a);
                                if (mounted) Navigator.of(context).pop();
                              } finally {
                                if (mounted) setState(() => _isSelectingExisting = false);
                              }
                            },
                    );
                  },
                )
              : _buildExistingGroupedList(filtered),
        ),
        if (_isSelectingExisting)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
      ],
    );
  }

  Widget _buildExistingGroupedList(List<Anlage> list) {
    final grouped = _groupByDiscipline(list);
    final keys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      children: [
        for (final label in keys)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              initiallyExpanded: _expandedExistingDisciplines.contains(label),
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedExistingDisciplines.add(label);
                  } else {
                    _expandedExistingDisciplines.remove(label);
                  }
                });
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${grouped[label]!.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                for (final a in grouped[label]!)
                  ListTile(
                    enabled: !_isSelectingExisting,
                    leading: Icon(a.discipline.icon, color: a.discipline.uiColor),
                    title: Text(a.name),
                    subtitle: Text(_existingSubtitle(a)),
                    onTap: _isSelectingExisting
                        ? null
                        : () async {
                            setState(() => _isSelectingExisting = true);
                            try {
                              await widget.onSelectExistingAnlage?.call(a);
                              if (mounted) Navigator.of(context).pop();
                            } finally {
                              if (mounted) setState(() => _isSelectingExisting = false);
                            }
                          },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    final isEdit = widget.existing != null;
    final showTabs = _supportsExistingSelection;
    final tabIndex = _tabController?.index ?? 1;
    final isExistingTab = showTabs && tabIndex == 0;

    final headerAccent = isExistingTab
        ? AppPalette.iconMuted
        : (_isLoadingDisciplines ? Theme.of(context).primaryColor : _discipline.uiColor);
    final headerIcon = isExistingTab
        ? Icons.playlist_add
        : (_isLoadingDisciplines ? Icons.build : _discipline.icon);

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
                      headerAccent.withOpacity(0.10),
                      headerAccent.withOpacity(0.05),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: headerAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            headerIcon,
                            color: headerAccent,
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
                                    ? 'Marker bearbeiten'
                                    : (showTabs && tabIndex == 0
                                        ? 'Bestehende Anlage wählen'
                                        : 'Neuen Marker hinzufügen'),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (!isExistingTab && !_isLoadingDisciplines)
                                Text(
                                  _discipline.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                )
                              else if (isExistingTab)
                                Text(
                                  'Alle Gewerke',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                )
                              else
                                Text(
                                  'Gewerke werden geladen…',
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
                    if (showTabs) ...[
                      const SizedBox(height: 12),
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Theme.of(context).primaryColor,
                        tabs: const [
                          Tab(text: 'Bestehend'),
                          Tab(text: 'Neu'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Flexible(
                child: showTabs
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildExistingSelector(),
                          SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoadingDisciplines)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 28),
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
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
                                        errorText: _titleController.text.trim().isEmpty
                                            ? 'Titel darf nicht leer sein'
                                            : null,
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
                                        value: _isLoadingDisciplines ? null : _discipline,
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
                                            .map((d) =>
                                                DropdownMenuItem(value: d, child: Text(d.label)))
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
                        ],
                      )
                    : SingleChildScrollView(
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
                                    errorText: _titleController.text.trim().isEmpty
                                        ? 'Titel darf nicht leer sein'
                                        : null,
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
                      Tooltip(
                        message: 'Löschen',
                        child: OutlinedButton(
                          onPressed: () async {
                            await widget.onDelete!(widget.existing!);
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppPalette.errorBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.delete,
                            size: 24,
                            color: AppPalette.error,
                          ),
                        ),
                      ),
                    if (isEdit && widget.onDelete != null) const SizedBox(width: 12),
                    if (isEdit && widget.onRemoveFromFloorPlan != null)
                      Tooltip(
                        message: 'Vom Grundriss entfernen',
                        child: OutlinedButton(
                          onPressed: () async {
                            await widget.onRemoveFromFloorPlan!();
                            if (mounted) Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppPalette.iconMuted.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.remove_circle_outline,
                            size: 24,
                            color: AppPalette.primaryDark,
                          ),
                        ),
                      ),
                    if (isEdit && widget.onRemoveFromFloorPlan != null)
                      const SizedBox(width: 12),
                    Tooltip(
                      message: 'Abbrechen',
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
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
                        child: Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!showTabs || (_tabController?.index ?? 1) == 1)
                      Tooltip(
                        message: 'Speichern',
                        child: ElevatedButton(
                          onPressed: () {
                            if (_isLoadingDisciplines) return;
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
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 24,
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
    );
  }
}
