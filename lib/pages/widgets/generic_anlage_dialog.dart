// lib/pages/widgets/generic_anlage_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/database_provider.dart';
import '../../providers/csv_settings_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/anlage_validation_service.dart';
import '../../services/ocr_service.dart';
import '../../services/qr_scan_service.dart';
import '../../theme/app_palette.dart';
import '../../services/template_service.dart';
import '../../utils/app_log.dart';
import 'photo_manager.dart';
import 'ocr_camera_page.dart';
import 'qr_camera_page.dart';
import 'speech_field_button.dart';
import '../../services/speech_service.dart';

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
  late final TextEditingController _qrCodeController;
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
  List<Template> _gewerkTemplates = [];
  /// Gesperrte Verortung: Hierarchie-Ebenen (Level-Nummer → Param-Key).
  final Map<int, String> _lockedHierarchyParamKeys = {};
  final Map<String, String> _lockedLocationParams = {};
  /// Feld mit Fokus – zeigt rechts den Mikrofon-Button.
  String? _speechActiveFieldKey;
  bool _speechListening = false;
  final Map<String, FocusNode> _fieldFocusNodes = {};

  // Listener für Validierungs-Updates
  void _updateValidationStatus() {
    setState(() {});
  }

  AnlageFormTheme get _ft => AnlageFormTheme.of(context);

  String _displayFieldLabel(String? raw, {String fallback = ''}) {
    final normalized = CsvSettings.normalizeFieldLabelForDisplay(raw);
    if (normalized.isNotEmpty) return normalized;
    return CsvSettings.normalizeFieldLabelForDisplay(fallback);
  }

  InputDecoration _schemaFieldDecoration({
    required String label,
    required AnlageFormTheme ft,
    Widget? suffixIcon,
  }) {
    final displayLabel = _displayFieldLabel(label);
    return InputDecoration(
      label: displayLabel.isEmpty
          ? null
          : Text(
              displayLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ft.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: InputBorder.none,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFieldActionButton({
    required bool isEmpty,
    required bool isValidated,
    required bool isMissing,
    required VoidCallback? onTap,
  }) {
    final ft = _ft;
    final Color bg;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    if (isEmpty) {
      icon = Icons.close;
      if (isMissing) {
        bg = ft.fieldBgMissing;
        borderColor = ft.checkNeutralBorder;
        iconColor = ft.missingNeutralIcon;
      } else {
        bg = ft.errorSurface;
        borderColor = ft.errorBorder;
        iconColor = ft.errorIcon;
      }
    } else {
      icon = Icons.check_circle;
      if (isValidated) {
        bg = ft.validationSurface;
        borderColor = ft.validationBorder;
        iconColor = ft.validationIcon;
      } else {
        bg = ft.checkNeutralBg;
        borderColor = ft.checkNeutralBorder;
        iconColor = ft.iconMuted;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _photoManager = PhotoManager();
    _qrCodeController = TextEditingController();
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
        // Schema wird nach dem Laden der Params auf das aktuelle RO reduziert
        // (_applyEffectiveSchemaFromParams), nicht das gesamte Flat-Schema anzeigen.
        effectiveDiscipline = updatedDiscipline;
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
            color: AppPalette.primary,
            schema: callerSchema.isNotEmpty ? callerSchema : updatedDiscipline.schema,
            groupingKey: widget.discipline.groupingKey,
            revisionsobjektSchemas: mergedRoSchemas,
          );
          effectiveDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
            discipline: baseForRo,
            revisionsobjekt: ro,
          );
        } else {
          effectiveDiscipline = Disziplin(
            label: updatedDiscipline.label,
            icon: updatedDiscipline.icon,
            color: AppPalette.primary,
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
      final existingQr =
          widget.existingAnlage!.params[CsvSettings.qrCodeNummerParamKey]?.toString() ?? '';
      _qrCodeController.text = existingQr;
    } else if (widget.initialParams != null && widget.initialParams!.isNotEmpty) {
      _params.addAll(widget.initialParams!);
      for (var entry in widget.initialParams!.entries) {
        final key = entry.key;
        final value = entry.value;
        if (!key.startsWith('_') && value != null && value.toString().trim().isNotEmpty) {
          _prefilledFields.add(key);
        }
      }
      final initialQr =
          widget.initialParams![CsvSettings.qrCodeNummerParamKey]?.toString() ?? '';
      _qrCodeController.text = initialQr;
    }

    await _loadSettingsAndPrefill();
    final isNewFromRevisionsobjekt = widget.existingAnlage == null &&
        widget.initialRevisionsobjekt?.trim().isNotEmpty == true;
    _establishLocationLocks();
    if (!isNewFromRevisionsobjekt) {
      _refreshDisciplineSchemaFromTemplates();
      if (widget.existingAnlage != null) {
        _establishLocationLocks();
      }
    }
    _applyRevisionsobjektPrefill();
    if (widget.existingAnlage == null) {
      _finalizeSchemaForRevisionsobjekt();
    } else {
      _refreshDisciplineSchemaFromTemplates();
    }
    _sanitizeAnlagenImportParamsAndSchema();
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

    _lockedHierarchyParamKeys.clear();
    for (var level = 1; level <= 3; level++) {
      final key = csv.resolveHierarchyLevelParamKey(level);
      if (key != null && key.isNotEmpty) {
        _lockedHierarchyParamKeys[level] = key;
      }
    }
    _schemaItemParamKey ??= csv.resolveSchemaItemParamKey();

    final hasFixedLocation = widget.initialRevisionsobjekt?.trim().isNotEmpty == true ||
        widget.parentId != null ||
        widget.existingAnlage != null;
    if (!hasFixedLocation) return;

    final sourceParams = widget.existingAnlage?.params ?? widget.initialParams ?? _params;

    for (var level = 1; level <= 3; level++) {
      if (level == 1 && csv.level1IsDiscipline) {
        final level1Value = _currentDiscipline.label;
        for (final key in csv.allParamKeysForHierarchyLevel(1)) {
          _lockedLocationParams[key] = level1Value;
        }
        continue;
      }
      final levelValue = csv.hierarchyLevelValueFromParams(sourceParams, level);
      if (levelValue == null || levelValue.isEmpty) continue;
      for (final key in csv.allParamKeysForHierarchyLevel(level)) {
        _lockedLocationParams[key] = levelValue;
      }
    }

    final schemaLevel = csv.schemaItemLevelNumber ?? 2;
    String? schemaValue = widget.initialRevisionsobjekt?.trim().isNotEmpty == true
        ? widget.initialRevisionsobjekt!.trim()
        : csv.hierarchyLevelValueFromParams(sourceParams, schemaLevel);

    if (schemaValue == null || schemaValue.isEmpty) return;

    final levelValues = <int, String>{schemaLevel: schemaValue};
    if (!csv.level1IsDiscipline) {
      final level1Value = csv.hierarchyLevelValueFromParams(sourceParams, 1);
      if (level1Value != null && level1Value.isNotEmpty) {
        levelValues[1] = level1Value;
      } else if (widget.initialParams != null) {
        for (final entry in widget.initialParams!.entries) {
          if (entry.key.startsWith('__')) continue;
          final v = entry.value?.toString().trim() ?? '';
          if (v.isNotEmpty && v != schemaValue) {
            levelValues[1] = v;
            _lockedHierarchyParamKeys[1] = entry.key;
            break;
          }
        }
      }
    }

    csv.writeHierarchyPathToParams(_params, levelValues: levelValues);

    for (final entry in levelValues.entries) {
      for (final key in csv.allParamKeysForHierarchyLevel(entry.key)) {
        _lockedLocationParams[key] = entry.value;
        _setParamAndController(key, entry.value);
      }
    }

    final schemaItemKey = csv.resolveSchemaItemParamKey()?.trim();
    if (schemaItemKey != null && schemaItemKey.isNotEmpty) {
      for (final field in _currentDiscipline.schema) {
        final key = (field['key'] ?? '').toString();
        if (key.isEmpty) continue;
        if (CsvSettings.paramKeysMatch(key, schemaItemKey)) {
          _lockedLocationParams[key] = schemaValue;
          _setParamAndController(key, schemaValue);
        }
      }
    }
  }

  bool _isHierarchyParamKey(String key) {
    final csv = _csvSettings;
    if (csv == null) return false;
    final k = key.trim();
    if (k.isEmpty) return false;
    if (csv.isLeafNameParamKey(k)) return false;

    final displayKey = csv.resolveDisplayNameParamKey()?.trim() ?? '';
    if (displayKey.isNotEmpty && CsvSettings.paramKeysMatch(k, displayKey)) {
      return false;
    }

    for (var level = 1; level <= 3; level++) {
      for (final hk in csv.allParamKeysForHierarchyLevel(level)) {
        if (CsvSettings.paramKeysMatch(k, hk)) return true;
      }
    }
    final schemaKey = csv.resolveSchemaItemParamKey()?.trim();
    if (schemaKey != null &&
        schemaKey.isNotEmpty &&
        CsvSettings.paramKeysMatch(k, schemaKey)) {
      return true;
    }
    return false;
  }

  /// Anzeigename-Feld, das fälschlich mit Schema-Ebenen-Label (z. B. Revisionsobjekt) beschriftet ist.
  bool _isMislabeledDisplayNameField(String key, String label) {
    final csv = _csvSettings;
    if (csv == null) return false;
    final normalizedLabel = CsvSettings.normalizeFieldLabelForDisplay(label);
    if (normalizedLabel.isEmpty) return false;

    final schemaItemLabel = csv.resolveSchemaItemLevelLabel();
    if (schemaItemLabel.isEmpty ||
        !CsvSettings.paramKeysMatch(normalizedLabel, schemaItemLabel)) {
      return false;
    }
    if (_isHierarchyParamKey(key)) return false;

    final displayKey = csv.resolveDisplayNameParamKey()?.trim() ?? '';
    return csv.isLeafNameParamKey(key) ||
        (displayKey.isNotEmpty && CsvSettings.paramKeysMatch(key, displayKey));
  }

  String _resolveSchemaFieldLabel(String key, Map<String, dynamic> fieldDef) {
    var label = _displayFieldLabel(
      fieldDef['label']?.toString(),
      fallback: key,
    );
    if (_isMislabeledDisplayNameField(key, label)) {
      final leafLabel = _csvSettings?.resolveLeafLevelLabel().trim() ?? '';
      if (leafLabel.isNotEmpty) label = leafLabel;
    }
    return label;
  }

  bool _isLocationLocked(String key) {
    if (_lockedLocationParams.containsKey(key)) return true;
    for (final lockedKey in _lockedLocationParams.keys) {
      if (CsvSettings.paramKeysMatch(key, lockedKey)) return true;
    }
    if (widget.existingAnlage != null && _isHierarchyParamKey(key)) {
      return true;
    }
    return false;
  }

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
      final levelValues = <int, String>{};
      for (var level = 1; level <= 3; level++) {
        final v = csv.hierarchyLevelValueFromParams(_lockedLocationParams, level);
        if (v != null && v.isNotEmpty) levelValues[level] = v;
      }
      if (levelValues.isNotEmpty) {
        csv.writeHierarchyPathToParams(_params, levelValues: levelValues);
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

    for (var level = 1; level <= 3; level++) {
      final key = csv.resolveHierarchyLevelParamKey(level);
      if (key == null || key.isEmpty || csv.isLeafNameParamKey(key)) continue;
      final value = csv.hierarchyLevelValueFromParams(_params, level);
      if (value != null && value.isNotEmpty) {
        _params[key] = value;
      } else if (level == 1 && csv.level1IsDiscipline) {
        _params[key] = _currentDiscipline.label;
      }
    }
  }

  List<Widget> _buildReadOnlyHierarchyFields() {
    final csv = _csvSettings;
    if (csv == null) return const [];

    final widgets = <Widget>[];

    Widget buildReadonlyField(String label, String value) {
      final ft = _ft;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: ft.fieldBgLocked,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ft.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            enableInteractiveSelection: false,
            style: TextStyle(color: ft.textPrimary),
            decoration: InputDecoration(
              labelText: _displayFieldLabel(label),
              labelStyle: TextStyle(color: ft.textSecondary),
              border: InputBorder.none,
              suffixIcon: Icon(Icons.lock_outline, size: 16, color: ft.iconMuted),
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < csv.enabledLevelsOrdered.length; i++) {
      final levelNum = csv.levelNumberAtEnabledIndex(i);
      if (levelNum == 1 && csv.level1IsDiscipline) continue;
      final schemaLevel = csv.schemaItemLevelNumber;
      if (schemaLevel != null && levelNum == schemaLevel) continue;
      final label = csv.hierarchyLevelHeaderLabel(levelNum);
      if (label.isEmpty) continue;
      var value = csv.hierarchyLevelValueFromParams(_params, levelNum) ?? '';
      if (value.isEmpty && levelNum == 1) {
        value = _currentDiscipline.label;
      }
      if (value.isNotEmpty) {
        widgets.add(buildReadonlyField(label, value));
      }
    }
    return widgets;
  }

  void _applyRevisionsobjektPrefill() {
    final ro = widget.initialRevisionsobjekt?.trim();
    if (ro == null || ro.isEmpty) return;

    final keys = <String>{
      if (_schemaItemParamKey != null && _schemaItemParamKey!.trim().isNotEmpty)
        _schemaItemParamKey!.trim(),
    };
    final schemaLevel = _csvSettings?.schemaItemLevelNumber;
    if (schemaLevel != null) {
      final schemaKey = _csvSettings!.resolveHierarchyLevelParamKey(schemaLevel);
      if (schemaKey != null && schemaKey.isNotEmpty) keys.add(schemaKey);
    }

    for (final field in _currentDiscipline.schema) {
      final key = (field['key'] ?? '').toString();
      if (key.isEmpty) continue;
      if (_isSchemaItemField(key)) {
        keys.add(key);
      }
    }

    final level1Key = _lockedHierarchyParamKeys[1];
    for (final key in keys) {
      if (level1Key != null && key == level1Key) continue;
      if (_isLeafNameField(key)) continue;
      _setParamAndController(key, ro);
    }
  }

  String? _resolveRevisionsobjektFromParams() {
    final initial = widget.initialRevisionsobjekt?.trim();
    if (initial != null && initial.isNotEmpty) return initial;

    final csv = _csvSettings;
    if (csv != null) {
      final schemaLevel = csv.schemaItemLevelNumber;
      if (schemaLevel != null) {
        final fromLocked =
            csv.hierarchyLevelValueFromParams(_lockedLocationParams, schemaLevel);
        if (fromLocked != null && fromLocked.isNotEmpty) return fromLocked;
        final fromParams = csv.hierarchyLevelValueFromParams(_params, schemaLevel);
        if (fromParams != null && fromParams.isNotEmpty) return fromParams;
      }
    }

    if (_schemaItemParamKey != null && _schemaItemParamKey!.trim().isNotEmpty) {
      for (final entry in _params.entries) {
        if (!CsvSettings.paramKeysMatch(
          entry.key.toString(),
          _schemaItemParamKey!.trim(),
        )) {
          continue;
        }
        final v = entry.value?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    if (_csvSettings != null) {
      final fromSettings = _csvSettings!.schemaItemValueFromParams(_params);
      if (fromSettings != null && fromSettings.isNotEmpty) return fromSettings;
    }
    return null;
  }

  bool _isSchemaItemField(String key) {
    if (_isLeafNameField(key)) return false;
    if (_isHierarchyParamKey(key)) return false;
    final schemaLevel = _csvSettings?.schemaItemLevelNumber;
    if (schemaLevel != null) {
      final levelKey = _csvSettings!.resolveHierarchyLevelParamKey(schemaLevel);
      if (levelKey != null && CsvSettings.paramKeysMatch(key, levelKey)) {
        return false;
      }
    }
    final paramKey = _schemaItemParamKey?.trim();
    if (paramKey == null || paramKey.isEmpty) return false;
    return CsvSettings.paramKeysMatch(key, paramKey);
  }

  void _onSchemaDrivingParamChanged(String key, String value) {
    if (!_isSchemaItemField(key)) return;
    if (value.trim().isEmpty) return;
    if (widget.existingAnlage != null) return;
    _refreshDisciplineSchemaFromTemplates();
  }

  Disziplin _disciplineWithSchemaForRevisionsobjekt(String revisionsobjekt) {
    final ro = revisionsobjekt.trim();
    if (ro.isEmpty) return _currentDiscipline;

    final matched = _gewerkTemplates.isNotEmpty
        ? TemplateService.findTemplateForRevisionsobjekt(_gewerkTemplates, ro)
        : null;

    return TemplateService.disciplineWithSchemaForRevisionsobjekt(
      discipline: _currentDiscipline,
      revisionsobjekt: ro,
      template: matched,
      templatesForLookup: _gewerkTemplates.isNotEmpty ? _gewerkTemplates : null,
    );
  }

  void _refreshDisciplineSchemaFromTemplates({String? revisionsobjekt}) {
    if (!mounted) return;
    if (widget.existingAnlage == null &&
        widget.initialRevisionsobjekt?.trim().isNotEmpty == true &&
        _currentDiscipline.schema.length >
            _currentDiscipline.globalSchemaFields.length) {
      return;
    }

    final ro = revisionsobjekt?.trim().isNotEmpty == true
        ? revisionsobjekt!.trim()
        : widget.initialRevisionsobjekt?.trim().isNotEmpty == true
            ? widget.initialRevisionsobjekt!.trim()
            : _resolveRevisionsobjektFromParams()?.trim() ?? '';
    if (ro.isEmpty) return;

    final nextDiscipline = _disciplineWithSchemaForRevisionsobjekt(ro);
    final hasTemplateSchema = _gewerkTemplates.isNotEmpty &&
        nextDiscipline.schema.length > nextDiscipline.globalSchemaFields.length;

    if (!hasTemplateSchema &&
        nextDiscipline.schema.length <= nextDiscipline.globalSchemaFields.length &&
        (_currentDiscipline.legacyIndividualSchemaFields.isNotEmpty ||
            _currentDiscipline.schema.length >
                _currentDiscipline.globalSchemaFields.length)) {
      return;
    }

    if (!hasTemplateSchema &&
        nextDiscipline.schema.length <= nextDiscipline.globalSchemaFields.length) {
      return;
    }

    setState(() {
      _currentDiscipline = nextDiscipline;
    });
  }

  void _finalizeSchemaForRevisionsobjekt() {
    _refreshDisciplineSchemaFromTemplates();
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

      _gewerkTemplates = await TemplateService.loadTemplatesFromDatabase(
        dbService,
        projectId,
        gewerk: _currentDiscipline.label,
      );

      if (mounted) setState(() {});

      // Vorbefüllung nur bei Neuanlage ohne festes Revisionsobjekt
      if (widget.existingAnlage == null &&
          (widget.initialRevisionsobjekt == null ||
              widget.initialRevisionsobjekt!.trim().isEmpty)) {
        final gewerkKey = csvSettings.resolveHierarchyLevelParamKey(1);
        for (var field in _currentDiscipline.schema) {
          final fieldKey = (field['key'] ?? '').toString();
          if (fieldKey.isEmpty) continue;

          if (gewerkKey != null &&
              csvSettings.level1IsDiscipline &&
              (fieldKey == gewerkKey ||
                  fieldKey.toLowerCase() == gewerkKey.toLowerCase())) {
            _setParamAndController(fieldKey, _currentDiscipline.label);
          }
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Einstellungen in GenericAnlageDialog: $e');
    }
  }

  @override
  void dispose() {
    SpeechService.instance.cancel();
    _qrCodeController.dispose();
    for (final node in _fieldFocusNodes.values) {
      node.dispose();
    }
    _fieldFocusNodes.clear();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isSpeechEligibleType(String type) {
    final t = type.toLowerCase();
    return t != 'date' && t != 'dropdown' && t != 'select';
  }

  FocusNode _focusNodeFor(String key) {
    return _fieldFocusNodes.putIfAbsent(key, () {
      final node = FocusNode();
      node.addListener(() => _onFieldFocusChanged(key, node.hasFocus));
      return node;
    });
  }

  void _onFieldFocusChanged(String key, bool hasFocus) {
    if (!mounted) return;
    setState(() {
      if (hasFocus) {
        _speechActiveFieldKey = key;
      } else if (_speechActiveFieldKey == key) {
        _speechActiveFieldKey = null;
      }
    });
  }

  Future<void> _toggleDictation({
    required String fieldLabel,
    required void Function(String text) onRecognized,
  }) async {
    if (_speechListening) {
      await SpeechService.instance.cancel();
      if (mounted) setState(() => _speechListening = false);
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final label = fieldLabel.trim();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          label.isNotEmpty
              ? 'Jetzt sprechen: $label (offline)'
              : 'Jetzt sprechen (offline)',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final available = await SpeechService.instance.ensureInitialized();
    if (!available) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Spracherkennung nicht verfügbar. '
            'Mikrofon erlauben und ggf. deutsches Offline-Sprachpaket installieren.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _speechListening = true);

    final result = await SpeechService.instance.dictate(
      onPartial: (partial) {
        if (partial.trim().isNotEmpty) onRecognized(partial);
      },
    );

    if (!mounted) return;
    setState(() => _speechListening = false);

    if (result != null && result.trim().isNotEmpty) {
      onRecognized(result.trim());
    }
  }

  Widget? _speechMicForField({
    required String key,
    required bool show,
    required String fieldLabel,
    required void Function(String text) onRecognized,
  }) {
    if (!show || _speechActiveFieldKey != key) return null;
    return SpeechMicFab(
      listening: _speechListening,
      onPressed: () => _toggleDictation(
        fieldLabel: fieldLabel,
        onRecognized: onRecognized,
      ),
    );
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

  Future<void> _scanQrCode() async {
    try {
      final image = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          builder: (context) => const QrCameraPage(),
          fullscreenDialog: true,
        ),
      );

      if (image == null || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final qrValue = await QrScanService.scanQrCodeFromImage(image);
        if (!mounted) return;
        Navigator.of(context).pop();

        if (qrValue == null || qrValue.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein QR-Code erkannt')),
          );
          return;
        }

        setState(() {
          _qrCodeController.text = qrValue;
          _params[CsvSettings.qrCodeNummerParamKey] = qrValue;
        });
      } catch (_) {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // Kamera abgebrochen oder nicht verfügbar
    }
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
      builder: (dialogContext) {
        final ft = AnlageFormTheme.of(dialogContext);
        return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: ft.scaffold,
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
                      color: ft.validationSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.document_scanner,
                      color: ft.validationIcon,
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
                        color: ft.textPrimary,
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
                  color: ft.textSecondary,
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
                          color: ft.sectionBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ft.borderSubtle,
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
                                      color: ft.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: ft.textPrimary,
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
                  color: ft.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Abbrechen',
                      style: TextStyle(
                        color: ft.cancelButtonText,
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
              Navigator.of(dialogContext).pop();
            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ft.validationIcon,
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
      );
      },
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

  Widget _buildQrCodeSection() {
    final ft = _ft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ft.sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ft.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ft.shadow,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'QR-Code Nummer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ft.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: ft.innerFieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ft.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qrCodeController,
                        keyboardType: TextInputType.text,
                        style: TextStyle(fontSize: 15, color: ft.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Nummer manuell eingeben oder scannen',
                          hintStyle: TextStyle(color: ft.textHint, fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          _params[CsvSettings.qrCodeNummerParamKey] = val.trim();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _scanQrCode,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final ft = _ft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ft.sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ft.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ft.shadow,
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
                            color: ft.textPrimary,
                          ),
                        ),
                        Text(
                          '${_photoManager.images.length}/${PhotoManager.maxPhotos}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ft.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _photoManager.canAddPhoto
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                        : ft.chipDisabledBg,
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
                                  : ft.iconMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hinzufügen',
                              style: TextStyle(
                                color: _photoManager.canAddPhoto
                                    ? Theme.of(context).primaryColor
                                    : ft.iconMuted,
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
                  color: ft.photoEmptyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ft.borderSubtle,
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
                        color: ft.iconMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Noch keine Fotos',
                        style: TextStyle(
                          color: ft.textSecondary,
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
                                    color: ft.scaffold,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: ft.shadow,
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
      if (_isLocationLocked(key)) continue;
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
    _params[CsvSettings.qrCodeNummerParamKey] = _qrCodeController.text.trim();
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

  void _sanitizeAnlagenImportParamsAndSchema() {
    final ro = _resolveRevisionsobjektFromParams();
    if (ro != null && ro.trim().isNotEmpty) {
      _currentDiscipline = _disciplineWithSchemaForRevisionsobjekt(ro.trim());
    }

    final schemaFields = ro != null && ro.trim().isNotEmpty
        ? _currentDiscipline.effectiveSchemaFor(revisionsobjekt: ro.trim())
        : _currentDiscipline.schema;

    CsvSettings.migrateParamsFromAnlagenColumnKeys(
      params: _params,
      schemaFields: schemaFields,
    );

    final filteredRoSchemas = <String, List<Map<String, dynamic>>>{};
    for (final entry in _currentDiscipline.revisionsobjektSchemas.entries) {
      filteredRoSchemas[entry.key] =
          CsvSettings.filterSchemaFieldsForDialog(entry.value);
    }

    _currentDiscipline = Disziplin(
      label: _currentDiscipline.label,
      icon: _currentDiscipline.icon,
      color: _currentDiscipline.color,
      schema: CsvSettings.filterSchemaFieldsForDialog(_currentDiscipline.schema),
      groupingKey: _currentDiscipline.groupingKey,
      revisionsobjektSchemas: filteredRoSchemas,
    );

    final keysToDrop = _controllers.keys
        .where((k) => CsvSettings.isAnlagenCsvColumnParamKey(k))
        .toList();
    for (final k in keysToDrop) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
  }

  /// Nur Felder für das aktuelle Revisionsobjekt (nicht alle RO-Schemata aus der DB).
  List<Map<String, dynamic>> _dialogSchemaFields() {
    final ro = _resolveRevisionsobjektFromParams();
    final roTrimmed = ro?.trim() ?? '';

    var discipline = _currentDiscipline;
    if (roTrimmed.isNotEmpty) {
      discipline = _disciplineWithSchemaForRevisionsobjekt(roTrimmed);
    }

    var fields = roTrimmed.isNotEmpty
        ? discipline.effectiveSchemaFor(revisionsobjekt: roTrimmed)
        : List<Map<String, dynamic>>.from(discipline.schema);
    fields = CsvSettings.filterSchemaFieldsForDialog(fields);
    fields = fields.where((f) {
      final key = (f['key'] ?? '').toString();
      if (key.isEmpty) return true;
      return !_isHierarchyParamKey(key);
    }).toList();

    final nonGlobal = fields.where((f) => f['isGlobal'] != true).toList();
    if (nonGlobal.isEmpty) {
      final fromParams = CsvSettings.schemaFieldsFromParams(
        _params,
        settings: _csvSettings,
      );
      if (fromParams.isNotEmpty) {
        final masterSchema = roTrimmed.isNotEmpty
            ? discipline.effectiveSchemaFor(revisionsobjekt: roTrimmed)
            : discipline.schema;
        final templateMaster = roTrimmed.isNotEmpty
            ? TemplateService.getSchemaFromTemplateParameter(
                TemplateService.findTemplateForRevisionsobjekt(
                      _gewerkTemplates,
                      roTrimmed,
                    )
                    ?.parameter,
              )
            : const <Map<String, dynamic>>[];
        final mergedMaster = TemplateService.mergeSchemaFieldLists(
          masterSchema,
          templateMaster,
        );
        return TemplateService.enrichSchemaFieldsFromMaster(
          fromParams,
          mergedMaster,
        );
      }
    }
    return fields;
  }

  String _textForSchemaField(String key, String label) {
    final csv = _csvSettings;
    if (csv != null) {
      final fromKey = csv.paramValueForKey(_params, key);
      if (fromKey != null && fromKey.isNotEmpty) return fromKey;
      if (label.trim().isNotEmpty) {
        final fromLabel = csv.paramValueForKey(_params, label);
        if (fromLabel != null && fromLabel.isNotEmpty) return fromLabel;
      }
    }
    return _params[key]?.toString() ?? '';
  }

  bool _schemaDefinesParamKey(List<Map<String, dynamic>> schema, String paramKey) {
    for (final f in schema) {
      final key = (f['key'] ?? '').toString();
      final label = (f['label'] ?? '').toString();
      if (CsvSettings.paramKeysMatch(key, paramKey) ||
          CsvSettings.paramKeysMatch(label, paramKey)) {
        return true;
      }
    }
    return false;
  }

  String? _schemaFieldArtGroup(Map<String, dynamic> fieldDef) {
    final art = CsvSettings.normalizeFieldLabelForDisplay(
      (fieldDef['art'] ?? '').toString(),
    );
    return art.isEmpty ? null : art;
  }

  Widget _buildArtGroupFrame(String groupTitle, List<Widget> children) {
    final ft = _ft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ft.groupFrameBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ft.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              groupTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ft.textPrimary,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  List<Widget> _buildSchemaFields() {
    final schema = _dialogSchemaFields();
    
    final fields = <Widget>[];
    String? currentArtGroup;
    final currentArtGroupFields = <Widget>[];

    void flushArtGroup() {
      if (currentArtGroupFields.isEmpty) return;
      if (currentArtGroup != null) {
        fields.add(_buildArtGroupFrame(currentArtGroup, currentArtGroupFields));
      } else {
        fields.addAll(currentArtGroupFields);
      }
      currentArtGroupFields.clear();
    }

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
      final artGroup = _schemaFieldArtGroup(fieldDef);
      if (artGroup != currentArtGroup) {
        flushArtGroup();
        currentArtGroup = artGroup;
      }
      final nestedInArtGroup = currentArtGroup != null;

      final key = fieldDef['key'] as String;

      final label = _resolveSchemaFieldLabel(key, fieldDef);
      final type = (fieldDef['type'] ?? 'string').toString();
      final isEditable = _isLocationLocked(key) || _isLeafNameField(key)
          ? false
          : (fieldDef['editable'] ?? true);
      
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: _textForSchemaField(key, label));
        _controllers[key]!.addListener(_updateValidationStatus);
      } else if (_isLocationLocked(key) || _isLeafNameField(key)) {
        final locked = _isLocationLocked(key)
            ? (_lockedLocationParams[key] ?? _textForSchemaField(key, label))
            : _textForSchemaField(key, label);
        if (_controllers[key]!.text != locked) {
          _controllers[key]!.text = locked;
        }
      }
      final controller = _controllers[key]!;
      final isEmpty = controller.text.trim().isEmpty;
      final isFieldValidated = AnlageValidationService.isFieldValidated(tempAnlage, key);
      final isFieldMissing = AnlageValidationService.isFieldMarkedAsMissing(tempAnlage, key);
      final ft = _ft;

      final actionButton = isEmpty
          ? _buildFieldActionButton(
              isEmpty: true,
              isValidated: false,
              isMissing: isFieldMissing,
              onTap: isEditable ? () => _toggleFieldMissing(key) : null,
            )
          : _buildFieldActionButton(
              isEmpty: false,
              isValidated: isFieldValidated,
              isMissing: false,
              onTap: isEditable ? () => _toggleFieldValidation(key) : null,
            );

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
        if (_isLocationLocked(key)) return;
        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        _params[key] = val;
        if (wasEmpty && val.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlage, key, true).params);
        }
        _onSchemaDrivingParamChanged(key, val);
        _updateValidationStatus();
      }

      void applyNumericValue(String val) {
        if (_isLocationLocked(key)) return;
        final wasEmpty = _params[key] == null || _params[key].toString().trim().isEmpty;
        _params[key] = (num.tryParse(val) ?? val);
        if (wasEmpty && val.trim().isNotEmpty) {
          _params.addAll(AnlageValidationService.setFieldValidated(tempAnlage, key, true).params);
        }
        _updateValidationStatus();
      }

      final speechEligible =
          isEditable == true && _isSpeechEligibleType(type);

      Widget inputWidget;
      if (type == 'dropdown' || type == 'select') {
        final inlineOptions = fieldDef['options'];
        List<String> options = const [];
        if (inlineOptions is List && inlineOptions.isNotEmpty) {
          options = inlineOptions.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
        if (options.isEmpty && _isSchemaItemField(key)) {
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
              decoration: _schemaFieldDecoration(
                label: label,
                ft: ft,
                suffixIcon: isEditable == true
                    ? null
                    : Icon(Icons.lock_outline, size: 16, color: ft.iconMuted),
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
        final isMultilineTextField =
            type == 'multiline' || label.toLowerCase().contains('bemerk');

        inputWidget = TextField(
          controller: controller,
          focusNode: speechEligible ? _focusNodeFor(key) : null,
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
            color: isEditable == true ? ft.textPrimary : ft.textDisabled,
          ),
          decoration: _schemaFieldDecoration(
            label: label,
            ft: ft,
            suffixIcon: isEditable != true
                ? Icon(Icons.lock_outline, size: 16, color: ft.iconMuted)
                : (type == 'date'
                    ? Icon(Icons.calendar_today, size: 16, color: ft.iconMuted)
                    : null),
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

      currentArtGroupFields.add(
        Container(
          margin: nestedInArtGroup
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: !isEditable
                ? ft.fieldBgLocked
                : (isFieldMissing ? ft.fieldBgMissing : ft.fieldBg),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFieldValidated ? ft.validationFieldBorder : ft.borderSubtle,
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
                _speechMicForField(
                      key: key,
                      show: speechEligible,
                      fieldLabel: label,
                      onRecognized: (text) {
                        controller.text = text;
                        if (type == 'number' || type == 'int') {
                          applyNumericValue(text);
                        } else {
                          applyTextValue(text);
                        }
                      },
                    ) ??
                    const SizedBox.shrink(),
                actionButton,
              ],
            ),
          ),
        ),
      );
    }
    flushArtGroup();

    // Zusätzliche Felder: Params ohne Schema-Definition (nicht per Key/Label doppelt anzeigen)
    for (final key in _params.keys) {
      if (_schemaDefinesParamKey(schema, key)) continue;
      if (_isLocationLocked(key)) continue;
      if (_isHierarchyParamKey(key)) continue;
      if (key.startsWith('__')) continue;
      if (key.startsWith('_')) continue; // interne/Validierungs-Felder nicht als Extra-Felder anzeigen
      if (_csvSettings?.matchesReservedDialogParamKey(key) == true) continue;
      if (CsvSettings.isAnlagenCsvColumnParamKey(key)) continue;
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
      final ftExtra = _ft;

      final actionButtonExtra = isEmpty
          ? _buildFieldActionButton(
              isEmpty: true,
              isValidated: false,
              isMissing: isFieldMissingExtra,
              onTap: () => _toggleFieldMissing(key),
            )
          : _buildFieldActionButton(
              isEmpty: false,
              isValidated: isFieldValidatedExtra,
              isMissing: false,
              onTap: () => _toggleFieldValidation(key),
            );

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
            color: isFieldMissingExtra ? ftExtra.fieldBgMissing : ftExtra.fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFieldValidatedExtra ? ftExtra.validationFieldBorder : ftExtra.borderSubtle,
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
                    focusNode: _focusNodeFor(key),
                    style: TextStyle(fontSize: 15, color: ftExtra.textPrimary),
                    decoration: _schemaFieldDecoration(
                      label: _displayFieldLabel(key),
                      ft: ftExtra,
                    ),
                    onChanged: (val) => applyTextValueExtra(val),
                  ),
                ),
                _speechMicForField(
                      key: key,
                      show: true,
                      fieldLabel: key,
                      onRecognized: (text) {
                        controller.text = text;
                        applyTextValueExtra(text);
                      },
                    ) ??
                    const SizedBox.shrink(),
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
    final ft = _ft;
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
          color: ft.scaffold,
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
                      widget.discipline.uiBackground.withValues(
                        alpha: ft.isDark ? 0.35 : 1.0,
                      ),
                      widget.discipline.uiBackground.withValues(
                        alpha: ft.isDark ? 0.15 : 0.5,
                      ),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: ft.divider,
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
                              color: widget.discipline.uiBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.discipline.icon,
                              color: widget.discipline.uiColor,
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
                                    color: ft.textPrimary,
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
                                      color: ft.textPrimary.withValues(alpha: 0.85),
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
                                        color: ft.textSecondary,
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
                                      color: ft.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ref.watch(settingsProvider).typenschildOcrEnabled)
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

                      // QR-Code Nummer
                      const SizedBox(height: 8),
                      _buildQrCodeSection(),

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
                  color: ft.scaffold,
                  border: Border(
                    top: BorderSide(
                      color: ft.divider,
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
                          color: ft.cancelButtonBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close,
                            size: 20,
                            color: ft.cancelButtonText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Abbrechen',
                            style: TextStyle(
                              color: ft.cancelButtonText,
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
                        _sanitizeAnlagenImportParamsAndSchema();
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
                              !CsvSettings.paramKeysMatch(leafKey, displayKey) &&
                              !csv.mustNotReceiveDisplayName(leafKey)) {
                            _params[leafKey] = name;
                          }
                        }
                        _applyLockedLocationParams();

                        final saveParams = Map<String, dynamic>.from(_params);
                        CsvSettings.migrateParamsFromAnlagenColumnKeys(
                          params: saveParams,
                          schemaFields: _dialogSchemaFields(),
                        );

                        // Erstelle Anlage
                        var anlage = Anlage(
                          id: widget.existingAnlage?.id ?? const Uuid().v4(),
                          parentId: widget.parentId ?? widget.existingAnlage?.parentId,
                          name: name,
                          params: saveParams,
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
