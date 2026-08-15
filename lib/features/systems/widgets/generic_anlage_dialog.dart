/// Anlagen erfassen/bearbeiten (Formulardialog).
///
/// Media: `anlage_dialog/anlage_media_sections.dart`, OCR/Speech-Helfer
/// unter `anlage_dialog/`, Prefill über `open_add_anlage_with_template_prefill.dart`.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/settings_provider.dart';
import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/features/systems/services/anlage_validation_service.dart';
import 'package:bestandsaufnahme_01/features/media/services/ocr_service.dart';
import 'package:bestandsaufnahme_01/features/media/services/qr_scan_service.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/core/utils/photo_file_utils.dart';
import 'package:bestandsaufnahme_01/features/media/widgets/photo_manager.dart';
import 'package:bestandsaufnahme_01/features/media/pages/ocr_camera_page.dart';
import 'package:bestandsaufnahme_01/features/media/pages/qr_camera_page.dart';
import 'package:bestandsaufnahme_01/features/media/widgets/speech_field_button.dart';
import 'package:bestandsaufnahme_01/features/media/services/speech_service.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/anlage_dialog/anlage_media_sections.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/anlage_dialog/anlage_ocr_helpers.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/anlage_dialog/anlage_ocr_result_dialog.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/anlage_dialog/anlage_speech_helpers.dart';

/// Modal-Dialog zum Anlegen oder Bearbeiten einer Anlage/Bauteil.
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
  ConsumerState<GenericAnlageDialog> createState() =>
      _GenericAnlageDialogState();
}

/// Formular-State: Schema-Felder, Media, OCR und Validierung.
class _GenericAnlageDialogState extends ConsumerState<GenericAnlageDialog> {
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

      var mergedRoSchemas = Map<String, List<Map<String, dynamic>>>.from(
        widget.discipline.revisionsobjektSchemas,
      );
      updatedDiscipline.revisionsobjektSchemas.forEach((key, fields) {
        mergedRoSchemas[key] = TemplateService.mergeSchemaFieldLists(
          mergedRoSchemas[key] ?? const [],
          fields,
        );
      });

      final ro = widget.initialRevisionsobjekt?.trim() ?? '';
      final Disziplin effectiveDiscipline;
      if (ro.isNotEmpty) {
        // Create und Edit: vorbereitetes/gespeichertes Schema hat Vorrang vor DB-Flat-Schema.
        final callerSchema = widget.discipline.schema;
        final baseForRo = Disziplin(
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
          importHeaders: _csvSettings?.importHeaderRow ?? const [],
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

      if (mounted) {
        setState(() {
          _currentDiscipline = effectiveDiscipline;
        });
      }
    } catch (e) {
      appLog('Fehler beim Laden der Disziplin in GenericAnlageDialog: $e');
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
        final files = await filterExistingPhotoFiles(existingPaths);
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
    final hasPreparedRoSchema = widget.initialRevisionsobjekt?.trim().isNotEmpty == true &&
        _currentDiscipline.schema.length > _currentDiscipline.globalSchemaFields.length;
    _establishLocationLocks();
    if (!hasPreparedRoSchema) {
      _applyEffectiveSchemaFromParams();
      if (widget.existingAnlage != null) {
        _establishLocationLocks();
      }
    }
    _applyRevisionsobjektPrefill();
    _applyEffectiveSchemaFromParams();
    _sanitizeAnlagenImportParamsAndSchema();
    _restoreListTitleIntoTitleField();
    } finally {
      if (mounted) {
        setState(() => _isDataReady = true);
      }
    }
  }

  /// Wenn Eingabefeld N (Listen-Titel) leer ist, aber `__listTitle` einen Wert
  /// hat (z. B. nach früherem Clear beim Speichern), Wert zurückschreiben –
  /// bevor Controller in `_buildSchemaFields` erzeugt werden.
  void _restoreListTitleIntoTitleField() {
    final csv = _csvSettings;
    if (csv == null) return;
    csv.restoreListTitleIntoInputField(
      _params,
      schemaFields: _dialogSchemaFields(),
    );
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

    // „Ebene 1/2/3“-Header nie als Eingabefeld
    if (CsvSettings.isEbeneHierarchyHeader(k)) return true;

    // CSV-Blattspalte (Ebene 3) nie als Eingabefeld – Name bleibt Anlage.name
    final leaf = csv.leafNameParamKey?.trim() ?? '';
    if (leaf.isNotEmpty && CsvSettings.paramKeysMatch(k, leaf)) return true;

    // Anzeige-Param aus Gewerkevorlage (z. B. „Name“) bleibt editierbar,
    // sofern er nicht dieselbe Spalte wie die CSV-Blattspalte ist.
    final displayKey = csv.resolveDisplayNameParamKey()?.trim() ?? '';
    if (displayKey.isNotEmpty &&
        CsvSettings.paramKeysMatch(k, displayKey) &&
        (leaf.isEmpty || !CsvSettings.paramKeysMatch(displayKey, leaf))) {
      return false;
    }

    // Blatt-Ebenen-Label (z. B. Bauteil), wenn Header leer war
    final leafLabel = csv.resolveLeafLevelLabel().trim();
    if (leafLabel.isNotEmpty &&
        CsvSettings.paramKeysMatch(k, leafLabel) &&
        (displayKey.isEmpty || !CsvSettings.paramKeysMatch(displayKey, leafLabel))) {
      return true;
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

  /// Anzeigename = Wert von Eingabefeld N (gleiche Reihenfolge wie im Dialog,
  /// nur editierbare Felder – gesperrte Hierarchie zählt nicht mit).
  String _resolvePersistedName() {
    final csv = _csvSettings;
    if (csv == null) return '';
    final fields = _dialogSchemaFields().where((f) {
      final key = (f['key'] ?? '').toString();
      if (key.isEmpty) return false;
      if (_isLocationLocked(key) || _isLeafNameField(key)) return false;
      if (_isHierarchyParamKey(key)) return false;
      final editable = f['editable'];
      if (editable == false) return false;
      return true;
    }).toList();

    final index =
        csv.listTitleInputFieldIndex < 1 ? 1 : csv.listTitleInputFieldIndex;
    if (fields.isEmpty) {
      return csv.valueAtListInputFieldIndex(
            _params,
            fieldIndex1Based: index,
            schemaFields: const [],
          ) ??
          '';
    }
    for (final field in fields) {
      final slot = CsvSettings.attSlotFromSchemaField(field);
      if (slot != index) continue;
      final key = (field['key'] ?? '').toString();
      if (key.isEmpty) continue;
      return csv.paramValueForKey(_params, key)?.trim() ?? '';
    }
    if (index > fields.length) return '';
    final key = (fields[index - 1]['key'] ?? '').toString();
    if (key.isEmpty) return '';
    return csv.paramValueForKey(_params, key)?.trim() ?? '';
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
      importHeaders: _csvSettings?.importHeaderRow ?? const [],
    );
  }

  void _refreshDisciplineSchemaFromTemplates({String? revisionsobjekt}) {
    if (!mounted) return;
    // Vorbereitetes RO-Schema (Create oder Edit) nicht durch leeres DB-Schema überschreiben.
    if (widget.initialRevisionsobjekt?.trim().isNotEmpty == true &&
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

  /// Reduziert das Schema auf das aktuelle Revisionsobjekt (Templates + RO-Map).
  /// Für Edit essenziell, wenn beim Öffnen noch kein initialRevisionsobjekt gesetzt war.
  void _applyEffectiveSchemaFromParams({String? revisionsobjekt}) {
    final ro = revisionsobjekt?.trim().isNotEmpty == true
        ? revisionsobjekt!.trim()
        : _resolveRevisionsobjektFromParams()?.trim() ?? '';
    if (ro.isEmpty) return;

    final nextDiscipline = _disciplineWithSchemaForRevisionsobjekt(ro);
    final nextHasFields =
        nextDiscipline.schema.length > nextDiscipline.globalSchemaFields.length;
    final currentHasFields = _currentDiscipline.schema.length >
        _currentDiscipline.globalSchemaFields.length;

    // Besseres Schema behalten: Template/RO-Auflösung oder vorhandenes Caller-/Anlagen-Schema.
    if (nextHasFields) {
      _currentDiscipline = nextDiscipline;
      return;
    }
    if (currentHasFields) {
      // Flat-Schema der Anlage in RO-Map spiegeln, damit effectiveSchemaFor greift.
      final resolvedKey = TemplateService.resolveRevisionsobjektKeyForValue(
            _currentDiscipline,
            ro,
            templates: _gewerkTemplates.isNotEmpty ? _gewerkTemplates : null,
          ) ??
          ro;
      final roFields = _currentDiscipline.legacyIndividualSchemaFields;
      if (roFields.isEmpty) return;
      final mergedRo = Map<String, List<Map<String, dynamic>>>.from(
        _currentDiscipline.revisionsobjektSchemas,
      );
      mergedRo[resolvedKey] = TemplateService.mergeSchemaFieldLists(
        mergedRo[resolvedKey] ?? const [],
        roFields,
      );
      _currentDiscipline = Disziplin(
        label: _currentDiscipline.label,
        icon: _currentDiscipline.icon,
        color: _currentDiscipline.color,
        schema: _currentDiscipline.schema,
        groupingKey: _currentDiscipline.groupingKey,
        revisionsobjektSchemas: mergedRo,
      );
    }
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

      // Nach Laden der Vorlagen Schema für festes RO neu anwenden
      // (in _initData waren Templates/Header oft noch nicht verfügbar).
      final roInitAfterLoad = widget.initialRevisionsobjekt?.trim();
      if (roInitAfterLoad != null && roInitAfterLoad.isNotEmpty) {
        // Wenn Gewerk-Filter keine passende Vorlage liefert: projektweit nach RO suchen
        if (TemplateService.findTemplateForRevisionsobjekt(
              _gewerkTemplates,
              roInitAfterLoad,
            ) ==
            null) {
          final allTemplates = await TemplateService.loadTemplatesFromDatabase(
            dbService,
            projectId,
          );
          final matched = TemplateService.findTemplateForRevisionsobjekt(
            allTemplates,
            roInitAfterLoad,
          );
          if (matched != null) {
            _gewerkTemplates = [
              matched,
              ..._gewerkTemplates.where(
                (t) =>
                    t.anlagentyp.trim().toLowerCase() !=
                        matched.anlagentyp.trim().toLowerCase() ||
                    t.gewerk.trim().toLowerCase() !=
                        matched.gewerk.trim().toLowerCase(),
              ),
            ];
          } else if (allTemplates.isNotEmpty && _gewerkTemplates.isEmpty) {
            _gewerkTemplates = allTemplates;
          }
        }

        _applyEffectiveSchemaFromParams(revisionsobjekt: roInitAfterLoad);
        await _ensureSchemaFromTemplateOrSiblings(
          dbService: dbService,
          revisionsobjekt: roInitAfterLoad,
          importHeaders: csvSettings.importHeaderRow,
        );
      }

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
      appLog('Fehler beim Laden der Einstellungen in GenericAnlageDialog: $e');
    }
  }

  /// Stellt sicher, dass Eingabefelder aus Gewerkevorlage oder Geschwister-Anlagen kommen.
  Future<void> _ensureSchemaFromTemplateOrSiblings({
    required DatabaseService dbService,
    required String revisionsobjekt,
    required List<String> importHeaders,
  }) async {
    final ro = revisionsobjekt.trim();
    if (ro.isEmpty) return;

    var fromTemplate = TemplateService.getSchemaFromTemplateParameter(
      TemplateService.findTemplateForRevisionsobjekt(
        _gewerkTemplates,
        ro,
      )?.parameter,
      importHeaders: importHeaders,
    );

    // Gebäude-Disziplin aus DB (RO-Schema vom Anlagen-Import)
    if (fromTemplate.isEmpty) {
      try {
        final disciplines =
            await dbService.getDisciplinesByBuildingId(widget.buildingId);
        Disziplin? buildingDisc;
        for (final d in disciplines) {
          if (d.label.trim().toLowerCase() ==
              _currentDiscipline.label.trim().toLowerCase()) {
            buildingDisc = d;
            break;
          }
        }
        if (buildingDisc != null) {
          final resolved = buildingDisc.resolveRevisionsobjektKey(ro) ?? ro;
          final roFields = buildingDisc.revisionsobjektSchemas[resolved];
          if (roFields != null && roFields.isNotEmpty) {
            fromTemplate =
                roFields.map((f) => Map<String, dynamic>.from(f)).toList();
          }
        }
      } catch (e) {
        appLog('Gebäude-Disziplin-Schema nicht ladbar: $e');
      }
    }

    // Vorlage-Parameter (inkl. __csvRowCells) in Params übernehmen – für Neuaufnahme
    if (widget.existingAnlage == null) {
      final matched = TemplateService.findTemplateForRevisionsobjekt(
        _gewerkTemplates,
        ro,
      );
      if (matched?.parameter != null && matched!.parameter!.trim().isNotEmpty) {
        final fromTplParams =
            TemplateService.buildEmptyParamsFromTemplate(matched.parameter);
        for (final e in fromTplParams.entries) {
          _params.putIfAbsent(e.key, () => e.value);
        }
        if (fromTemplate.isEmpty) {
          fromTemplate = TemplateService.getSchemaFromTemplateParameter(
            matched.parameter,
            importHeaders: importHeaders,
          );
        }
      }
    }

    // Fallback: Schema aus importierten Geschwister-Anlagen gleichen Typs
    if (fromTemplate.isEmpty) {
      try {
        final siblings = await dbService.getAnlagenByBuildingIdAndDiscipline(
          widget.buildingId,
          _currentDiscipline.label,
        );
        final csv = _csvSettings;
        for (final sibling in siblings) {
          final siblingRo =
              csv?.schemaItemValueFromParams(sibling.params)?.trim() ??
                  csv?.revisionsobjektValueFromParams(sibling.params)?.trim() ??
                  '';
          if (siblingRo.isEmpty ||
              siblingRo.toLowerCase() != ro.toLowerCase()) {
            continue;
          }
          final cells = sibling.params[CsvSettings.csvRowCellsParamKey];
          if (cells is Map && cells.isNotEmpty) {
            final cellHeaders =
                cells.keys.map((k) => k.toString()).toList(growable: false);
            fromTemplate = CsvSettings.schemaFieldsFromCsvAttRowCells(
              {
                CsvSettings.csvRowCellsParamKey: cells,
              },
              importHeaders: cellHeaders,
            );
            if (fromTemplate.isEmpty && importHeaders.isNotEmpty) {
              fromTemplate = CsvSettings.schemaFieldsFromCsvAttRowCells(
                {
                  CsvSettings.csvRowCellsParamKey: cells,
                },
                importHeaders: importHeaders,
              );
            }
            if (fromTemplate.isNotEmpty) break;
          }

          List<Map<String, dynamic>>? siblingRoFields =
              sibling.discipline.revisionsobjektSchemas[ro];
          if (siblingRoFields == null || siblingRoFields.isEmpty) {
            for (final entry
                in sibling.discipline.revisionsobjektSchemas.entries) {
              if (entry.key.toLowerCase() == ro.toLowerCase() &&
                  entry.value.isNotEmpty) {
                siblingRoFields = entry.value;
                break;
              }
            }
          }
          if (siblingRoFields != null && siblingRoFields.isNotEmpty) {
            fromTemplate = siblingRoFields
                .map((f) => Map<String, dynamic>.from(f))
                .toList();
            break;
          }
          final legacy = sibling.discipline.legacyIndividualSchemaFields;
          if (legacy.isNotEmpty) {
            fromTemplate =
                legacy.map((f) => Map<String, dynamic>.from(f)).toList();
            break;
          }
        }
      } catch (e) {
        appLog('Schema aus Geschwister-Anlagen nicht ladbar: $e');
      }
    }

    if (fromTemplate.isEmpty) return;

    final resolvedKey = TemplateService.resolveRevisionsobjektKeyForValue(
          _currentDiscipline,
          ro,
          templates: _gewerkTemplates,
        ) ??
        ro;
    final mergedRo = Map<String, List<Map<String, dynamic>>>.from(
      _currentDiscipline.revisionsobjektSchemas,
    );
    mergedRo[resolvedKey] = TemplateService.mergeSchemaFieldLists(
      mergedRo[resolvedKey] ?? const [],
      fromTemplate,
    );
    final flat = TemplateService.mergeSchemaFieldLists(
      _currentDiscipline.globalSchemaFields,
      fromTemplate,
    );
    _currentDiscipline = Disziplin(
      label: _currentDiscipline.label,
      icon: _currentDiscipline.icon,
      color: _currentDiscipline.color,
      schema: CsvSettings.filterSchemaFieldsForDialog(flat),
      groupingKey: _currentDiscipline.groupingKey,
      revisionsobjektSchemas: mergedRo.map(
        (k, v) => MapEntry(k, CsvSettings.filterSchemaFieldsForDialog(v)),
      ),
    );
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

  bool _isSpeechEligibleType(String type) => isSpeechEligibleFieldType(type);

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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!_speechListening) {
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
    }

    final ok = await runFieldDictation(
      onRecognized: onRecognized,
      onListeningChanged: (listening) {
        if (mounted) setState(() => _speechListening = listening);
      },
    );

    if (!ok && mounted) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Spracherkennung nicht verfügbar. '
            'Mikrofon erlauben und ggf. deutsches Offline-Sprachpaket installieren.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        appLog('QR-Scan fehlgeschlagen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('QR-Scan fehlgeschlagen: $e')),
          );
        }
      }
    } catch (e) {
      appLog('Kamera für QR-Scan nicht verfügbar oder abgebrochen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera nicht verfügbar')),
        );
      }
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
      appLog('OCR-Kamera fehlgeschlagen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera-Fehler: $e')),
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

      if (!ocrResultsLookUseful(results)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Typenschild-Daten erkannt')),
        );
        return;
      }

      await _showOcrResultDialog(results);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Dialog schließen
      appLog('OCR fehlgeschlagen', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _showOcrResultDialog(Map<String, String> results) async {
    final confirmed = await showOcrResultConfirmDialog(
      context: context,
      results: results,
      labelForKey: (ocrKey) =>
          labelForOcrKey(_currentDiscipline.schema, ocrKey),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      final matched = matchOcrResultsToSchema(
        ocrResults: results,
        schema: _currentDiscipline.schema,
      );

      for (final field in matched) {
        _params[field.schemaKey] = field.paramValue;

        if (!_controllers.containsKey(field.schemaKey)) {
          _controllers[field.schemaKey] = TextEditingController();
          _controllers[field.schemaKey]!
              .addListener(_updateValidationStatus);
        }
        _controllers[field.schemaKey]!.text = field.displayValue;
      }

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

      tempAnlage = markOcrFieldsValidated(
        tempAnlage,
        matched.map((f) => f.schemaKey),
      );

      _params.addAll(tempAnlage.params);
      _updateValidationStatus();
    });
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

    final csv = _csvSettings;
    AnlageParamsCleanup.applyForDialogOpen(
      params: _params,
      schemaFields: schemaFields,
      importHeaders: csv?.importHeaderRow ?? const [],
      csvSettings: csv,
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

    // Nach Repair: sichtbare Controller an bereinigte Params anpassen
    // (fuzzy Key-Match wie bei der Feldanzeige – nicht nur exakter Map-Key).
    for (final entry in _controllers.entries) {
      final key = entry.key;
      var label = key;
      for (final f in _currentDiscipline.schema) {
        if ((f['key'] ?? '').toString() == key) {
          label = (f['label'] ?? key).toString();
          break;
        }
      }
      final desired = _textForSchemaField(key, label);
      if (entry.value.text != desired) {
        entry.value.text = desired;
      }
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

    // Wenn RO gesetzt ist, aber revisionsobjektSchemas keinen Eintrag hat,
    // effectiveSchemaFor liefert nur Globals – Flat-Schema der Anlage nutzen.
    final nonGlobalAfterRo = fields.where((f) => f['isGlobal'] != true).toList();
    if (roTrimmed.isNotEmpty && nonGlobalAfterRo.isEmpty) {
      final flatNonGlobal = discipline.legacyIndividualSchemaFields;
      if (flatNonGlobal.isNotEmpty) {
        fields = [
          ...discipline.globalSchemaFields,
          ...flatNonGlobal,
        ];
      }
    }

    fields = CsvSettings.filterSchemaFieldsForDialog(fields);
    fields = fields.where((f) {
      final key = (f['key'] ?? '').toString();
      if (key.isEmpty) return true;
      return !_isHierarchyParamKey(key) && !_isLeafNameField(key);
    }).toList();

    // ATT-Namen aus Import-CSV / Vorlagen-Zellen ergänzen (auch leere ART-Werte).
    var fromCsvCells = const <Map<String, dynamic>>[];
    final cellsRaw = _params[CsvSettings.csvRowCellsParamKey];
    if (cellsRaw is Map && cellsRaw.isNotEmpty) {
      final cellHeaders = cellsRaw.keys.map((k) => k.toString()).toList();
      fromCsvCells = CsvSettings.schemaFieldsFromCsvAttRowCells(
        _params,
        importHeaders: cellHeaders,
      );
      if (fromCsvCells.isEmpty &&
          _csvSettings != null &&
          _csvSettings!.importHeaderRow.isNotEmpty) {
        fromCsvCells = CsvSettings.schemaFieldsFromCsvAttRowCells(
          _params,
          importHeaders: _csvSettings!.importHeaderRow,
        );
      }
    } else if (_csvSettings != null &&
        _csvSettings!.importHeaderRow.isNotEmpty) {
      fromCsvCells = CsvSettings.schemaFieldsFromCsvAttRowCells(
        _params,
        importHeaders: _csvSettings!.importHeaderRow,
      );
    }
    if (fromCsvCells.isNotEmpty) {
      // CSV zuerst, bestehendes Schema überschreibt Metadaten gleicher Keys.
      fields = TemplateService.mergeSchemaFieldLists(fromCsvCells, fields);
      fields = CsvSettings.filterSchemaFieldsForDialog(fields);
      fields = fields.where((f) {
        final key = (f['key'] ?? '').toString();
        if (key.isEmpty) return true;
        return !_isHierarchyParamKey(key) && !_isLeafNameField(key);
      }).toList();
    }

    final nonGlobal = fields.where((f) => f['isGlobal'] != true).toList();
    if (nonGlobal.isEmpty) {
      // Vorlage als Feldquelle (nicht nur Enrichment) – auch wenn _schema leer war
      // und nur __csvRowCells in der Vorlage stehen.
      final template = roTrimmed.isNotEmpty
          ? TemplateService.findTemplateForRevisionsobjekt(
              _gewerkTemplates,
              roTrimmed,
            )
          : null;
      final fromTemplate = TemplateService.getSchemaFromTemplateParameter(
        template?.parameter,
        importHeaders: _csvSettings?.importHeaderRow ?? const [],
      );
      if (fromTemplate.isNotEmpty) {
        var recovered = CsvSettings.filterSchemaFieldsForDialog(fromTemplate);
        recovered = recovered.where((f) {
          final key = (f['key'] ?? '').toString();
          if (key.isEmpty) return true;
          return !_isHierarchyParamKey(key) && !_isLeafNameField(key);
        }).toList();
        if (recovered.where((f) => f['isGlobal'] != true).isNotEmpty) {
          return [
            ...discipline.globalSchemaFields,
            ...recovered.where((f) => f['isGlobal'] != true),
          ];
        }
      }

      final fromParams = CsvSettings.schemaFieldsFromParams(
        _params,
        settings: _csvSettings,
      );
      final combined = TemplateService.mergeSchemaFieldLists(
        fromCsvCells,
        fromParams,
      );
      if (combined.isNotEmpty) {
        final masterSchema = roTrimmed.isNotEmpty
            ? discipline.effectiveSchemaFor(revisionsobjekt: roTrimmed)
            : discipline.schema;
        final templateMaster = fromTemplate;
        final mergedMaster = TemplateService.mergeSchemaFieldLists(
          masterSchema,
          templateMaster,
        );
        // Auch Flat-Schema der Anlage als Master (Dropdowns/art).
        final withFlat = TemplateService.mergeSchemaFieldLists(
          mergedMaster,
          discipline.legacyIndividualSchemaFields,
        );
        final enriched = TemplateService.enrichSchemaFieldsFromMaster(
          combined,
          withFlat,
        );
        return enriched.where((f) {
          final key = (f['key'] ?? '').toString();
          if (key.isEmpty) return true;
          return !_isHierarchyParamKey(key) && !_isLeafNameField(key);
        }).toList();
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
    return CsvSettings.effectiveSchemaArtGroup(fieldDef);
  }

  Widget _buildArtGroupFrame(String groupTitle, List<Widget> children) {
    final ft = _ft;
    // Einzelnes Feld: kein äußerer Rahmen (sonst wirkt Label „doppelt“).
    if (children.length <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
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
      // Blatt-/Hierarchie-Spalten nie als Eingabefeld rendern
      if (_isHierarchyParamKey(key) || _isLeafNameField(key)) continue;

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
      } else if (_controllers[key]!.text.trim().isEmpty) {
        // Nach asynchronem Prefill/Restore: leeren Controller einmalig befüllen,
        // ohne laufende Nutzereingaben zu überschreiben.
        final desired = _textForSchemaField(key, label);
        if (desired.isNotEmpty) {
          _controllers[key]!.text = desired;
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
                      AnlageQrCodeSection(
                        theme: _ft,
                        controller: _qrCodeController,
                        onChanged: (val) {
                          _params[CsvSettings.qrCodeNummerParamKey] = val.trim();
                        },
                        onScan: _scanQrCode,
                      ),

                      // Fotos
                      const SizedBox(height: 8),
                      AnlagePhotoSection(
                        theme: _ft,
                        photoManager: _photoManager,
                        onAddPhoto: _takePhoto,
                        onViewImage: _viewImage,
                        onRemoveImage: _removeImage,
                      ),
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
                        if (csv != null) {
                          csv.clearPlaceholderDisplayNameFromParams(_params);
                        }
                        final hasRealName = name.trim().isNotEmpty;
                        if (!hasRealName) {
                          name = CsvSettings.unknownAnlageListLabel;
                          _params[CsvSettings.listNamePlaceholderParamKey] =
                              true;
                          _params[CsvSettings.listTitleParamKey] = '';
                        } else {
                          _params.remove(
                              CsvSettings.listNamePlaceholderParamKey);
                          // Explizit speichern – Liste liest das zuverlässig,
                          // unabhängig von Schema-Abweichungen beim Laden.
                          _params[CsvSettings.listTitleParamKey] = name.trim();
                        }
                        _applyLockedLocationParams();

                        final saveParams = Map<String, dynamic>.from(_params);
                        final schemaForSave = _dialogSchemaFields();
                        AnlageParamsCleanup.applyForDialogSave(
                          params: saveParams,
                          schemaFields: schemaForSave,
                          importHeaders: csv?.importHeaderRow ?? const [],
                          csvSettings: csv,
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
