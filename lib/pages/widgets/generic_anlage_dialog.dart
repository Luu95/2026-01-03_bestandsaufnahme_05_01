// lib/pages/widgets/generic_anlage_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/database_provider.dart';
import '../../providers/csv_settings_provider.dart';
import '../../services/anlage_validation_service.dart';
import '../../services/ocr_service.dart';
import '../../services/template_service.dart';
import '../../utils/app_log.dart';
import 'photo_manager.dart';
import 'ocr_camera_page.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

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
  /// Optionale Vorbefüllung für neue Anlagen (z.B. Gruppierungsattribut aus Long-Press auf Gruppe).
  final Map<String, dynamic>? initialParams;
  final String? initialName;
  /// Revisionsobjekt (Ebene 2), dessen Eingabefelder-Schema verwendet werden soll.
  final String? initialRevisionsobjekt;

  const GenericAnlageDialog({
    Key? key,
    required this.discipline,
    required this.buildingId,
    required this.floorId,
    this.parentId,
    this.existingAnlage,
    this.index,
    required this.onSave,
    this.initialParams,
    this.initialName,
    this.initialRevisionsobjekt,
  }) : super(key: key);

  @override
  ConsumerState<GenericAnlageDialog> createState() => _GenericGewerkDialogState();
}

class _GenericGewerkDialogState extends ConsumerState<GenericAnlageDialog> {
  final Map<String, dynamic> _params = {};
  final Map<String, TextEditingController> _controllers = {};
  late PhotoManager _photoManager;
  // Trackt Felder, die beim Initialisieren bereits befüllt waren (aus CSV)
  final Set<String> _prefilledFields = {};
  bool _isDataReady = false;
  late Disziplin _currentDiscipline;
  String? _schemaItemParamKey;
  CsvSettings? _csvSettings;
  String _leafLevelLabel = '';
  String _childLevelLabel = '';
  String? _dialogSubtitle;
  String? _dialogContextLine;
  /// Gesperrte Verortung: Revisionsfeld und Revisionsobjekt (getrennte Werte).
  final Map<String, String> _lockedLocationParams = {};
  String? _revisionsfeldParamKey;
  String? _revisionsobjektParamKey;

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

      // Gemeinsames Schema: DB + vom Aufrufer übergeben (z. B. Revisionsobjekt-Felder)
      final mergedKeys = <String>{};
      final mergedSchema = <Map<String, dynamic>>[];

      for (final f in updatedDiscipline.schema) {
        final key = (f['key'] ?? '').toString();
        if (key.isNotEmpty && !mergedKeys.contains(key)) {
          mergedKeys.add(key);
          mergedSchema.add(Map<String, dynamic>.from(f));
        }
      }

      for (final f in widget.discipline.schema) {
        final key = (f['key'] ?? '').toString();
        if (key.isNotEmpty && !mergedKeys.contains(key)) {
          mergedKeys.add(key);
          mergedSchema.add(Map<String, dynamic>.from(f));
        }
      }

      Disziplin effectiveDiscipline = updatedDiscipline;

      if (widget.existingAnlage != null) {
        final existingDisc = widget.existingAnlage!.discipline;
        for (final f in existingDisc.schema) {
          final key = (f['key'] ?? '').toString();
          if (key.isNotEmpty && !mergedKeys.contains(key)) {
            mergedKeys.add(key);
            mergedSchema.add(Map<String, dynamic>.from(f));
          }
        }

        effectiveDiscipline = Disziplin(
          label: updatedDiscipline.label,
          icon: updatedDiscipline.icon,
          color: updatedDiscipline.color,
          schema: mergedSchema,
          groupingKey: updatedDiscipline.groupingKey,
          revisionsobjektSchemas: updatedDiscipline.revisionsobjektSchemas,
        );
      } else {
        final ro = widget.initialRevisionsobjekt?.trim() ?? '';
        var mergedRoSchemas = Map<String, List<Map<String, dynamic>>>.from(
          widget.discipline.revisionsobjektSchemas,
        );
        updatedDiscipline.revisionsobjektSchemas.forEach((key, fields) {
          mergedRoSchemas[key] = TemplateService.mergeSchemaFieldLists(
            mergedRoSchemas[key] ?? const [],
            fields,
          );
        });

        if (ro.isNotEmpty) {
          // Vom Aufrufer (z. B. Gruppen-Plus) vorbereitetes Schema hat Vorrang vor DB-Flat-Schema.
          final callerSchema = widget.discipline.schema;
          var baseForRo = Disziplin(
            label: widget.discipline.label,
            icon: widget.discipline.icon,
            color: widget.discipline.color,
            schema: callerSchema.isNotEmpty ? callerSchema : updatedDiscipline.schema,
            groupingKey: widget.discipline.groupingKey,
            revisionsobjektSchemas: mergedRoSchemas,
          );
          effectiveDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
            discipline: baseForRo,
            revisionsobjekt: ro,
          );
          final finalSchema = TemplateService.mergeSchemaFieldLists(
            effectiveDiscipline.schema,
            mergedSchema,
          );
          effectiveDiscipline = Disziplin(
            label: effectiveDiscipline.label,
            icon: effectiveDiscipline.icon,
            color: effectiveDiscipline.color,
            schema: finalSchema,
            groupingKey: effectiveDiscipline.groupingKey,
            revisionsobjektSchemas: mergedRoSchemas,
          );
        } else {
          effectiveDiscipline = Disziplin(
            label: updatedDiscipline.label,
            icon: updatedDiscipline.icon,
            color: updatedDiscipline.color,
            schema: mergedSchema,
            groupingKey: updatedDiscipline.groupingKey,
            revisionsobjektSchemas: mergedRoSchemas,
          );
        }
      }

      if (mounted) {
        setState(() {
          _currentDiscipline = effectiveDiscipline;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Disziplin in GenericAnlageDialog: $e');
      _currentDiscipline = widget.discipline;
    }

    try {
    if (widget.existingAnlage != null) {
      _params.addAll(widget.existingAnlage!.params);
      for (var entry in widget.existingAnlage!.params.entries) {
        final key = entry.key;
        final value = entry.value;
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
    } else if (widget.initialParams != null && widget.initialParams!.isNotEmpty) {
      _params.addAll(widget.initialParams!);
      for (var entry in widget.initialParams!.entries) {
        final key = entry.key;
        final value = entry.value;
        if (!key.startsWith('_') && value != null && value.toString().trim().isNotEmpty) {
          _prefilledFields.add(key);
        }
      }
    }

    await _loadSettingsAndPrefill();
    final isNewFromRevisionsobjekt = widget.existingAnlage == null &&
        widget.initialRevisionsobjekt?.trim().isNotEmpty == true;
    _establishLocationLocks();
    if (!isNewFromRevisionsobjekt) {
      _applyEffectiveSchemaFromParams();
      if (widget.existingAnlage != null) {
        _establishLocationLocks();
      }
    }
    _applyRevisionsobjektPrefill();
    if (widget.existingAnlage == null) {
      _finalizeSchemaForRevisionsobjekt();
    }
    } finally {
      if (mounted) {
        setState(() => _isDataReady = true);
      }
    }
  }

  void _setParamAndController(String key, String value) {
    if (key.isEmpty || value.isEmpty) return;
    _params[key] = value;
    _prefilledFields.add(key);
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: value);
      _controllers[key]!.addListener(_updateValidationStatus);
    } else {
      _controllers[key]!.text = value;
    }
  }

  void _establishLocationLocks() {
    final csv = _csvSettings;
    if (csv == null) return;

    _revisionsfeldParamKey = csv.resolveRevisionsfeldListGroupingParamKey();
    _revisionsobjektParamKey = csv.resolveRevisionsobjektParamKey();

    final hasFixedLocation = widget.initialRevisionsobjekt?.trim().isNotEmpty == true ||
        widget.parentId != null ||
        widget.existingAnlage != null;
    if (!hasFixedLocation) return;

    final sourceParams = widget.existingAnlage?.params ?? widget.initialParams ?? _params;

    String? roValue = widget.initialRevisionsobjekt?.trim().isNotEmpty == true
        ? widget.initialRevisionsobjekt!.trim()
        : csv.revisionsobjektValueFromParams(sourceParams);

    String? rfValue;
    if (_revisionsfeldParamKey != null && _revisionsfeldParamKey!.isNotEmpty) {
      rfValue = widget.initialParams?[_revisionsfeldParamKey!]?.toString().trim();
      rfValue ??= csv.revisionsfeldValueFromParams(sourceParams);
    }
    if ((rfValue == null || rfValue.isEmpty) && widget.initialParams != null) {
      for (final entry in widget.initialParams!.entries) {
        if (entry.key.startsWith('__')) continue;
        final v = entry.value?.toString().trim() ?? '';
        if (v.isNotEmpty && v != roValue) {
          _revisionsfeldParamKey = entry.key;
          rfValue = v;
          break;
        }
      }
    }

    if (roValue == null || roValue.isEmpty) return;

    csv.writeHierarchyLocationToParams(
      _params,
      revisionsfeld: rfValue,
      revisionsobjekt: roValue,
    );

    for (final key in csv.allRevisionsobjektParamKeys()) {
      if (csv.isLeafNameParamKey(key)) continue;
      _lockedLocationParams[key] = roValue;
      _setParamAndController(key, roValue);
    }

    if (rfValue != null && rfValue.isNotEmpty) {
      for (final key in csv.allRevisionsfeldParamKeys()) {
        _lockedLocationParams[key] = rfValue;
        _setParamAndController(key, rfValue);
      }
      final rfKeys = csv.allRevisionsfeldParamKeys();
      if ((_revisionsfeldParamKey == null || _revisionsfeldParamKey!.isEmpty) &&
          rfKeys.isNotEmpty) {
        _revisionsfeldParamKey = rfKeys.first;
      }
    }

    for (final field in _currentDiscipline.schema) {
      final key = (field['key'] ?? '').toString();
      final label = (field['label'] ?? '').toString();
      if (key.isEmpty) continue;
      if (_isSchemaItemField(key, label)) {
        _lockedLocationParams[key] = roValue;
        _setParamAndController(key, roValue);
      } else if (rfValue != null &&
          rfValue.isNotEmpty &&
          _revisionsfeldParamKey != null &&
          (key == _revisionsfeldParamKey ||
              label.trim().toLowerCase() ==
                  _revisionsfeldParamKey!.trim().toLowerCase())) {
        _lockedLocationParams[key] = rfValue;
        _setParamAndController(key, rfValue);
      }
    }
  }

  bool _isLocationLocked(String key) => _lockedLocationParams.containsKey(key);

  /// Nur importierte Blatt-Name-Spalte schreibgeschützt – Anzeige-Param aus Gewerkevorlage bleibt editierbar.
  bool _isLeafNameField(String key) {
    final csv = _csvSettings;
    if (csv == null) return false;
    final leaf = csv.leafNameParamKey?.trim();
    if (leaf == null || leaf.isEmpty) return false;
    return CsvSettings.paramKeysMatch(key, leaf);
  }

  /// Anzeigename der Anlage (Schema-Feld / CSV-Blattspalte).
  String _resolvePersistedName() {
    final csv = _csvSettings;
    if (csv != null) {
      final fromDisplay = csv.displayNameValueFromParams(_params)?.trim();
      if (fromDisplay != null && fromDisplay.isNotEmpty) {
        return fromDisplay;
      }
      final leafKey = csv.leafNameParamKey;
      if (leafKey != null && leafKey.isNotEmpty) {
        final fromParams = csv.paramValueForKey(_params, leafKey);
        if (fromParams != null && fromParams.isNotEmpty) return fromParams;
      }
    }
    if (widget.existingAnlage != null &&
        widget.existingAnlage!.name.trim().isNotEmpty) {
      return widget.existingAnlage!.name.trim();
    }
    final initial = widget.initialName?.trim();
    if (initial != null && initial.isNotEmpty) return initial;
    return '';
  }

  void _applyLockedLocationParams() {
    final csv = _csvSettings;
    if (csv != null && _lockedLocationParams.isNotEmpty) {
      final ro = (csv.revisionsobjektValueFromParams(_lockedLocationParams) ??
              _lockedLocationParams.values.first)
          .trim();
      final rf = csv.revisionsfeldValueFromParams(_lockedLocationParams);
      if (ro.isNotEmpty) {
        csv.writeHierarchyLocationToParams(
          _params,
          revisionsfeld: rf,
          revisionsobjekt: ro,
        );
      }
    }
    for (final entry in _lockedLocationParams.entries) {
      _params[entry.key] = entry.value;
      if (_controllers.containsKey(entry.key)) {
        _controllers[entry.key]!.text = entry.value;
      }
    }
  }

  void _ensureLevelLabelParams() {
    final csv = _csvSettings;
    if (csv == null) return;

    final level1Key = csv.labelGewerk.trim();
    final level2Key = csv.labelAnlage.trim();

    final level1Value = (csv.revisionsfeldValueFromParams(_params) ??
            _currentDiscipline.label)
        .trim();
    final level2Value =
        (csv.revisionsobjektValueFromParams(_params) ?? '').trim();

    if (level1Key.isNotEmpty &&
        level1Value.isNotEmpty &&
        !csv.isLeafNameParamKey(level1Key)) {
      _params[level1Key] = level1Value;
    }
    if (level2Key.isNotEmpty &&
        level2Value.isNotEmpty &&
        !csv.isLeafNameParamKey(level2Key)) {
      _params[level2Key] = level2Value;
    }
  }

  List<Widget> _buildReadOnlyHierarchyFields() {
    final csv = _csvSettings;
    if (csv == null) return const [];

    final widgets = <Widget>[];
    final level1Key = csv.labelGewerk.trim();
    final level2Key = csv.labelAnlage.trim();

    String readValue(String key, String fallback) {
      final fromParams = _params[key]?.toString().trim() ?? '';
      if (fromParams.isNotEmpty) return fromParams;
      return fallback;
    }

    final level1Value = readValue(
      level1Key,
      (csv.revisionsfeldValueFromParams(_params) ?? _currentDiscipline.label).trim(),
    );
    final level2Value = readValue(
      level2Key,
      (csv.revisionsobjektValueFromParams(_params) ?? '').trim(),
    );

    Widget buildReadonlyField(String label, String value) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              labelText: label,
              border: InputBorder.none,
              suffixIcon: Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    if (level1Key.isNotEmpty && level1Value.isNotEmpty) {
      widgets.add(buildReadonlyField(level1Key, level1Value));
    }
    if (level2Key.isNotEmpty && level2Value.isNotEmpty) {
      widgets.add(buildReadonlyField(level2Key, level2Value));
    }
    return widgets;
  }

  void _applyRevisionsobjektPrefill() {
    final ro = widget.initialRevisionsobjekt?.trim();
    if (ro == null || ro.isEmpty) return;

    final keys = <String>{
      if (_schemaItemParamKey != null && _schemaItemParamKey!.trim().isNotEmpty)
        _schemaItemParamKey!.trim(),
      if (_revisionsobjektParamKey != null && _revisionsobjektParamKey!.trim().isNotEmpty)
        _revisionsobjektParamKey!.trim(),
    };

    for (final field in _currentDiscipline.schema) {
      final key = (field['key'] ?? '').toString();
      final label = (field['label'] ?? '').toString();
      if (key.isEmpty) continue;
      if (_isSchemaItemField(key, label)) {
        keys.add(key);
      }
    }

    for (final key in keys) {
      if (_revisionsfeldParamKey != null && key == _revisionsfeldParamKey) continue;
      if (_isLeafNameField(key)) continue;
      _setParamAndController(key, ro);
    }

    // Neue Blatt-Zeile (kein Kind): optional A/B-Kennung setzen
    if (widget.parentId == null && _csvSettings?.anlageBauteilSpalte != null) {
      final abKey = _csvSettings!.resolveAnlageBauteilParamKey();
      if (abKey != null && abKey.isNotEmpty) {
        _setParamAndController(
          abKey,
          _csvSettings!.defaultAnlageKuerzelToken(),
        );
      }
    }
  }

  String? _resolveRevisionsobjektFromParams() {
    if (_schemaItemParamKey != null && _schemaItemParamKey!.trim().isNotEmpty) {
      final v = _params[_schemaItemParamKey]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    if (_csvSettings != null) {
      final fromSettings = _csvSettings!.schemaItemValueFromParams(_params);
      if (fromSettings != null && fromSettings.isNotEmpty) return fromSettings;
    }
    for (final ro in _currentDiscipline.revisionsobjektNames) {
      for (final entry in _params.entries) {
        if (entry.value?.toString().trim() == ro) return ro;
      }
    }
    return null;
  }

  bool _isSchemaItemField(String key, String label) {
    if (_isLeafNameField(key)) return false;
    if (_revisionsfeldParamKey != null && key == _revisionsfeldParamKey) return false;
    final paramKey = _revisionsobjektParamKey ?? _schemaItemParamKey?.trim();
    if (paramKey == null || paramKey.isEmpty) return false;
    if (key == paramKey) return true;
    return label.trim().toLowerCase() == paramKey.toLowerCase();
  }

  void _onSchemaDrivingParamChanged(String key, String label, String value) {
    if (!_isSchemaItemField(key, label)) return;
    if (value.trim().isEmpty) return;
    _applyEffectiveSchemaFromParams();
  }

  void _finalizeSchemaForRevisionsobjekt() {
    if (!mounted) return;
    final ro = widget.initialRevisionsobjekt?.trim().isNotEmpty == true
        ? widget.initialRevisionsobjekt!.trim()
        : _resolveRevisionsobjektFromParams();
    if (ro == null || ro.isEmpty) return;

    final nextDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
      discipline: _currentDiscipline,
      revisionsobjekt: ro,
    );
    if (nextDiscipline.schema.length <= _currentDiscipline.globalSchemaFields.length) {
      return;
    }
    _currentDiscipline = nextDiscipline;
  }

  void _applyEffectiveSchemaFromParams() {
    if (!mounted) return;
    if (widget.existingAnlage == null &&
        widget.initialRevisionsobjekt?.trim().isNotEmpty == true &&
        _currentDiscipline.schema.length >
            _currentDiscipline.globalSchemaFields.length) {
      return;
    }
    final ro =
        widget.initialRevisionsobjekt?.trim().isNotEmpty == true
            ? widget.initialRevisionsobjekt!.trim()
            : _resolveRevisionsobjektFromParams();
    if (ro == null || ro.trim().isEmpty) return;

    final nextDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
      discipline: _currentDiscipline,
      revisionsobjekt: ro,
    );

    // Vererbtes/übergebenes Schema nicht durch leeres DB-RO-Schema ersetzen.
    if (nextDiscipline.schema.length <= nextDiscipline.globalSchemaFields.length &&
        (_currentDiscipline.legacyIndividualSchemaFields.isNotEmpty ||
            _currentDiscipline.schema.length >
                _currentDiscipline.globalSchemaFields.length)) {
      return;
    }

    setState(() {
      _currentDiscipline = nextDiscipline;
    });
  }

  Future<void> _loadSettingsAndPrefill() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final projectId = await dbService.getProjectIdByBuildingId(widget.buildingId);
      if (projectId == null) return;

      await ref.read(csvSettingsProvider(projectId).notifier).load();
      final csvSettings = ref.read(csvSettingsProvider(projectId));
      _csvSettings = csvSettings;
      _childLevelLabel = csvSettings.labelBauteil;
      final roInit = widget.initialRevisionsobjekt?.trim();
      if (roInit != null && roInit.isNotEmpty) {
        _leafLevelLabel = csvSettings.resolveDatensatzUnderRevisionsobjektLabel();
        _dialogSubtitle = roInit;
        _dialogContextLine = widget.discipline.label;
      } else {
        _leafLevelLabel = csvSettings.resolveLeafLevelLabel();
        _dialogSubtitle = null;
        _dialogContextLine = null;
      }
      _schemaItemParamKey = (roInit != null && roInit.isNotEmpty)
          ? (csvSettings.resolveRevisionsobjektGroupingParamKey() ??
              csvSettings.resolveSchemaItemParamKey())
          : csvSettings.resolveSchemaItemParamKey();
      if (mounted) setState(() {});

      // Vorbefüllung nur bei Neuanlage ohne festes Revisionsobjekt
      if (widget.existingAnlage == null &&
          (widget.initialRevisionsobjekt == null ||
              widget.initialRevisionsobjekt!.trim().isEmpty)) {
        final gewerkKey = csvSettings.resolveGewerkGroupingParamKey();
        final abKey = csvSettings.resolveAnlageBauteilParamKey();
        for (var field in _currentDiscipline.schema) {
          final fieldKey = (field['key'] ?? '').toString();
          if (fieldKey.isEmpty) continue;

          if (fieldKey == gewerkKey ||
              fieldKey.toLowerCase() == gewerkKey.toLowerCase()) {
            _setParamAndController(fieldKey, _currentDiscipline.label);
          }

          if (abKey != null &&
              abKey.isNotEmpty &&
              (fieldKey == abKey ||
                  fieldKey.toLowerCase() == abKey.toLowerCase())) {
            final value = widget.parentId != null
                ? csvSettings.defaultBauteilKuerzelToken()
                : csvSettings.defaultAnlageKuerzelToken();
            _setParamAndController(fieldKey, value);
          }
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Einstellungen in GenericAnlageDialog: $e');
    }
  }

  @override
  void dispose() {
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

  void _removeImage(int idx) {
    _photoManager.removeImage(idx);
    setState(() {});
  }

  Future<void> _takePhotoForOcr() async {
    if (!_photoManager.canAddPhoto) {
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
      // Kamera-Fehler ignorieren
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
        return;
      }

      await _showOcrResultDialog(results);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
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
                  name: _resolvePersistedName(),
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
      name: _resolvePersistedName(),
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

  /// Synchronisiert alle Controller-Werte in _params. Sollte vor dem Speichern
  /// aufgerufen werden, damit keine Eingaben verloren gehen.
  void _syncControllersToParams() {
    final schema = _currentDiscipline.schema;
    final schemaByKey = <String, Map<String, dynamic>>{};
    for (final f in schema) {
      final k = (f['key'] ?? '').toString();
      if (k.isNotEmpty) schemaByKey[k] = f;
    }
    for (final entry in _controllers.entries) {
      final key = entry.key;
      final controller = entry.value;
      final text = controller.text.trim();
      final fieldDef = schemaByKey[key];
      final type = (fieldDef?['type'] ?? 'text').toString().toLowerCase();
      if (type == 'number' || type == 'int') {
        _params[key] = text.isEmpty ? '' : (num.tryParse(text) ?? text);
      } else {
        _params[key] = text;
      }
    }
  }

  void _toggleFieldMissing(String key) {
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _resolvePersistedName(),
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
    
    final fields = <Widget>[];
    final tempAnlage = Anlage(
      id: widget.existingAnlage?.id ?? '',
      parentId: widget.parentId ?? widget.existingAnlage?.parentId,
      name: _resolvePersistedName(),
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

      final label = fieldDef['label'] as String;
      final type = (fieldDef['type'] ?? 'string').toString();
      final isEditable = _isLocationLocked(key) || _isLeafNameField(key)
          ? false
          : (fieldDef['editable'] ?? true);
      
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: _params[key]?.toString() ?? '');
        _controllers[key]!.addListener(_updateValidationStatus);
      } else if (_isLocationLocked(key) || _isLeafNameField(key)) {
        final locked = _isLocationLocked(key)
            ? (_lockedLocationParams[key] ?? _params[key]?.toString() ?? '')
            : (_params[key]?.toString() ?? '');
        if (_controllers[key]!.text != locked) {
          _controllers[key]!.text = locked;
        }
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
        _onSchemaDrivingParamChanged(key, label, val);
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
      if (type == 'dropdown' || type == 'select') {
        final inlineOptions = fieldDef['options'];
        List<String> options = const [];
        if (inlineOptions is List && inlineOptions.isNotEmpty) {
          options = inlineOptions.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
        if (options.isEmpty && _isSchemaItemField(key, label)) {
          options = _currentDiscipline.revisionsobjektNames;
        }

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
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Keine Dropdown-Optionen definiert.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
          ],
        );
      } else {
        final isMultilineTextField =
            type == 'multiline' || label.toLowerCase().contains('bemerk');

        inputWidget = TextField(
          controller: controller,
          readOnly: isEditable != true || type == 'date',
          onTap: (isEditable == true && type == 'date') ? pickDate : null,
          keyboardType: (type == 'number' || type == 'int')
              ? TextInputType.number
              : (isMultilineTextField ? TextInputType.multiline : TextInputType.text),
          minLines: isMultilineTextField ? 1 : null,
          maxLines: isMultilineTextField ? null : 1,
          textInputAction: isMultilineTextField ? TextInputAction.newline : TextInputAction.next,
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

    // Zusätzliche Felder: Params, die nicht im Schema sind (z. B. aus CSV-Attribut-Spaltenpaaren)
    final schemaKeys = schema.map((f) => (f['key'] as String?).toString()).where((k) => k.isNotEmpty).toSet();
    final reservedKeys = _csvSettings?.reservedParamKeysForDialog() ??
        const {'lfdNummer', 'photoPaths'};
    for (final key in _params.keys) {
      if (schemaKeys.contains(key)) continue;
      if (_isLocationLocked(key)) continue;
      if (key.startsWith('__')) continue;
      if (key.startsWith('_')) continue; // interne/Validierungs-Felder nicht als Extra-Felder anzeigen
      if (reservedKeys.contains(key)) continue;
      final value = _params[key];
      if (value is Map || value is List) continue; // keine komplexen Typen als einfaches Textfeld

      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
        _controllers[key]!.addListener(_updateValidationStatus);
      }
      final controller = _controllers[key]!;
      final isEmpty = controller.text.trim().isEmpty;
      final tempAnlageForExtra = Anlage(
        id: widget.existingAnlage?.id ?? '',
        parentId: widget.parentId ?? widget.existingAnlage?.parentId,
        name: _resolvePersistedName(),
        params: Map<String, dynamic>.from(_params),
        floorId: widget.floorId,
        buildingId: widget.buildingId,
        isMarker: widget.existingAnlage?.isMarker ?? false,
        markerInfo: widget.existingAnlage?.markerInfo,
        markerType: _currentDiscipline.label,
        discipline: _currentDiscipline,
      );
      final isFieldValidatedExtra = AnlageValidationService.isFieldValidated(tempAnlageForExtra, key);
      final isFieldMissingExtra = AnlageValidationService.isFieldMarkedAsMissing(tempAnlageForExtra, key);

      Widget actionButtonExtra;
      if (isEmpty) {
        actionButtonExtra = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleFieldMissing(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldMissingExtra ? Colors.grey[200] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFieldMissingExtra ? Colors.grey[400]! : Colors.red[300]!, width: 1.5),
              ),
              child: Icon(Icons.close, color: isFieldMissingExtra ? Colors.grey[700] : Colors.red[600], size: 20),
            ),
          ),
        );
      } else {
        actionButtonExtra = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleFieldValidation(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFieldValidatedExtra ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFieldValidatedExtra ? Colors.green[400]! : Colors.grey[400]!, width: 1.5),
              ),
              child: Icon(Icons.check_circle, color: isFieldValidatedExtra ? Colors.green[600] : Colors.grey[500], size: 20),
            ),
          ),
        );
      }

      void applyTextValueExtra(String val) {
        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        _params[key] = val;
        if (wasEmpty && val.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlageForExtra, key, true).params);
        }
        _updateValidationStatus();
      }

      fields.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isFieldMissingExtra ? Colors.grey[200] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFieldValidatedExtra ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
              width: isFieldValidatedExtra ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(fontSize: 15, color: Colors.grey[900]),
                    decoration: InputDecoration(
                      labelText: key,
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => applyTextValueExtra(val),
                  ),
                ),
                actionButtonExtra,
              ],
            ),
          ),
        ),
      );
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataReady) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.25,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isEdit = widget.existingAnlage != null;
    final isChildCreate = !isEdit && widget.parentId != null;
    final leafLabel =
        _leafLevelLabel.isNotEmpty ? _leafLevelLabel : 'Eintrag';
    final childLabel =
        _childLevelLabel.isNotEmpty ? _childLevelLabel : leafLabel;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final dialogTitle = isEdit
        ? '$leafLabel bearbeiten'
        : (isChildCreate
            ? 'Neues $childLabel erfassen'
            : 'Neues $leafLabel erfassen');
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
                                  dialogTitle,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (_dialogSubtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _dialogSubtitle!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_dialogContextLine != null &&
                                      _dialogContextLine!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _dialogContextLine!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ] else ...[
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
                      // Schema-Felder (Anlagenbezeichnung = Blatt-Spalte aus CSV, gesperrt)
                      const SizedBox(height: 8),
                      ..._buildReadOnlyHierarchyFields(),
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
                        _params['photoPaths'] = _photoManager.images.map((e) => e.path).toList();

                        // Wichtig: Alle Controller-Werte vor dem Speichern in _params übernehmen.
                        // Verhindert, dass Eingaben verloren gehen (z.B. bei Fokus-Wechsel ohne onChanged).
                        _syncControllersToParams();
                        _applyLockedLocationParams();
                        _ensureLevelLabelParams();

                        var name = _resolvePersistedName();
                        final csv = _csvSettings;
                        if (name.isEmpty) {
                          name = _leafLevelLabel.isNotEmpty ? _leafLevelLabel : 'Eintrag';
                        }
                        if (csv != null) {
                          csv.writeDisplayNameToParams(_params, name);
                          final leafKey = csv.leafNameParamKey?.trim();
                          final displayKey = csv.resolveDisplayNameParamKey()?.trim();
                          if (leafKey != null &&
                              leafKey.isNotEmpty &&
                              displayKey != null &&
                              !CsvSettings.paramKeysMatch(leafKey, displayKey)) {
                            _params[leafKey] = name;
                          }
                        }

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
