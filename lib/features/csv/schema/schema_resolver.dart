/// Kanonische Schema-Auflösung für Dialog, Validation und Export.
///
/// Eine Quelle statt Waterfall-Duplikaten in UI/Services:
/// 1) RO-Map + Globals (optional Template-Merge)
/// 2) Flat-Legacy → optional Promote in RO
/// 3) Last-Resort nur wenn keine Non-Globals: Template → __csvRowCells → Params

import 'package:bestandsaufnahme_01/features/csv/csv_settings.dart';
import 'package:bestandsaufnahme_01/features/csv/models/schema_field.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';

/// Woher die Non-Global-Felder kamen.
enum SchemaResolveSource {
  /// revisionsobjektSchemas[ro] (+ Globals).
  roMap,

  /// Flat-Schema ohne isGlobal (ältere Daten).
  legacyFlat,

  /// Template-Parameter (_schema / Zellen).
  template,

  /// Anlage.__csvRowCells.
  csvRowCells,

  /// Param-Keys als Text-Felder abgeleitet.
  paramsInference,

  /// Nur Globals / leeres Schema.
  globalsOnly,
}

/// Verwendungszweck steuert Filter (Hierarchie-/Blatt-Keys).
enum SchemaResolvePurpose { dialog, validation, export }

/// Eingabe für [SchemaResolver.resolve].
class SchemaResolveInput {
  final Disziplin discipline;
  final String? revisionsobjekt;
  final Map<String, dynamic> params;
  final CsvSettings? csvSettings;
  final List<Template>? templates;
  final List<String> importHeaders;
  final SchemaResolvePurpose purpose;

  /// false = kein Template/Cells/Params-Inference (nur RO/Flat).
  final bool allowLastResortInference;

  const SchemaResolveInput({
    required this.discipline,
    this.revisionsobjekt,
    this.params = const {},
    this.csvSettings,
    this.templates,
    this.importHeaders = const [],
    this.purpose = SchemaResolvePurpose.dialog,
    this.allowLastResortInference = true,
  });
}

/// Ergebnis inkl. optional promoteter Disziplin (Flat → RO).
class SchemaResolveResult {
  final List<SchemaField> fields;
  final SchemaResolveSource source;
  final Disziplin? promotedDiscipline;

  const SchemaResolveResult({
    required this.fields,
    required this.source,
    this.promotedDiscipline,
  });

  List<Map<String, dynamic>> get asMaps => SchemaField.listToMaps(fields);
}

/// Zentrale Schema-Auflösung.
class SchemaResolver {
  SchemaResolver._();

  /// Kanonische Auflösung (typed).
  static SchemaResolveResult resolve(SchemaResolveInput input) {
    final ro = input.revisionsobjekt?.trim() ?? '';
    var discipline = input.discipline;
    Disziplin? promoted;
    var source = SchemaResolveSource.globalsOnly;

    if (ro.isNotEmpty) {
      discipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
        discipline: discipline,
        revisionsobjekt: ro,
        templatesForLookup: input.templates,
        importHeaders: input.importHeaders,
      );
    }

    final resolvedKey = ro.isEmpty
        ? ''
        : (TemplateService.resolveRevisionsobjektKeyForValue(
              discipline,
              ro,
              templates: input.templates,
            ) ??
            ro);
    final hasRoMapFields = resolvedKey.isNotEmpty &&
        (discipline.revisionsobjektSchemas[resolvedKey]?.isNotEmpty ?? false);

    var maps = ro.isNotEmpty
        ? discipline.effectiveSchemaFor(revisionsobjekt: ro)
        : List<Map<String, dynamic>>.from(discipline.schema);

    // Flat → RO promoten, wenn RO gewählt aber noch kein Map-Eintrag existiert.
    if (ro.isNotEmpty && !hasRoMapFields) {
      final legacy = discipline.legacyIndividualSchemaFields;
      if (legacy.isNotEmpty) {
        promoted = promoteLegacyFlatIntoRo(
          discipline: discipline,
          revisionsobjekt: ro,
          templates: input.templates,
        );
        discipline = promoted;
        maps = discipline.effectiveSchemaFor(revisionsobjekt: ro);
        source = SchemaResolveSource.legacyFlat;
      }
    } else if (maps.any((f) => f['isGlobal'] != true)) {
      source = ro.isNotEmpty
          ? SchemaResolveSource.roMap
          : SchemaResolveSource.legacyFlat;
    }

    maps = _filterMaps(
      maps,
      purpose: input.purpose,
      csvSettings: input.csvSettings,
    );

    var fields = SchemaField.listFromMaps(maps);
    if (fields.any((f) => !f.isGlobal)) {
      return SchemaResolveResult(
        fields: fields,
        source: source == SchemaResolveSource.globalsOnly
            ? (ro.isNotEmpty
                ? SchemaResolveSource.roMap
                : SchemaResolveSource.legacyFlat)
            : source,
        promotedDiscipline: promoted,
      );
    }

    if (!input.allowLastResortInference) {
      return SchemaResolveResult(
        fields: fields,
        source: SchemaResolveSource.globalsOnly,
        promotedDiscipline: promoted,
      );
    }

    // Last resort: Template → Cells → Params (nur wenn keine Non-Globals).
    final fromTemplate = _schemaFromTemplate(
      ro: ro,
      templates: input.templates,
      importHeaders: input.importHeaders,
    );
    if (fromTemplate.isNotEmpty) {
      final recovered = _filterMaps(
        fromTemplate,
        purpose: input.purpose,
        csvSettings: input.csvSettings,
      );
      if (recovered.any((f) => f['isGlobal'] != true)) {
        final merged = [
          ...discipline.globalSchemaFields,
          ...recovered.where((f) => f['isGlobal'] != true),
        ];
        return SchemaResolveResult(
          fields: SchemaField.listFromMaps(merged),
          source: SchemaResolveSource.template,
          promotedDiscipline: promoted,
        );
      }
    }

    final fromCells = _schemaFromCsvRowCells(
      params: input.params,
      importHeaders: input.importHeaders,
      csvSettings: input.csvSettings,
    );
    final fromParams = CsvSettings.schemaFieldsFromParams(
      input.params,
      settings: input.csvSettings,
    );
    final combined = TemplateService.mergeSchemaFieldLists(
      fromCells,
      fromParams,
    );
    if (combined.isEmpty) {
      return SchemaResolveResult(
        fields: fields,
        source: SchemaResolveSource.globalsOnly,
        promotedDiscipline: promoted,
      );
    }

    final master = TemplateService.mergeSchemaFieldLists(
      TemplateService.mergeSchemaFieldLists(
        ro.isNotEmpty
            ? discipline.effectiveSchemaFor(revisionsobjekt: ro)
            : discipline.schema,
        fromTemplate,
      ),
      discipline.legacyIndividualSchemaFields,
    );
    final enriched = TemplateService.enrichSchemaFieldsFromMaster(
      combined,
      master,
    );
    final filtered = _filterMaps(
      enriched,
      purpose: input.purpose,
      csvSettings: input.csvSettings,
    );
    return SchemaResolveResult(
      fields: SchemaField.listFromMaps(filtered),
      source: fromCells.isNotEmpty
          ? SchemaResolveSource.csvRowCells
          : SchemaResolveSource.paramsInference,
      promotedDiscipline: promoted,
    );
  }

  /// Bridge für bestehenden Map-Code.
  static List<Map<String, dynamic>> resolveAsMaps(SchemaResolveInput input) =>
      resolve(input).asMaps;

  /// Flat-Non-Globals einmalig in revisionsobjektSchemas[ro] spiegeln.
  static Disziplin promoteLegacyFlatIntoRo({
    required Disziplin discipline,
    required String revisionsobjekt,
    List<Template>? templates,
  }) {
    final ro = revisionsobjekt.trim();
    if (ro.isEmpty) return discipline;

    final resolvedKey = TemplateService.resolveRevisionsobjektKeyForValue(
          discipline,
          ro,
          templates: templates,
        ) ??
        ro;
    final roFields = discipline.legacyIndividualSchemaFields;
    if (roFields.isEmpty) return discipline;

    final mergedRo = Map<String, List<Map<String, dynamic>>>.from(
      discipline.revisionsobjektSchemas,
    );
    mergedRo[resolvedKey] = TemplateService.mergeSchemaFieldLists(
      mergedRo[resolvedKey] ?? const [],
      roFields,
    );
    return Disziplin(
      label: discipline.label,
      icon: discipline.icon,
      color: discipline.color,
      schema: discipline.schema,
      groupingKey: discipline.groupingKey,
      revisionsobjektSchemas: mergedRo,
    );
  }

  static List<Map<String, dynamic>> _schemaFromTemplate({
    required String ro,
    required List<Template>? templates,
    required List<String> importHeaders,
  }) {
    if (ro.isEmpty || templates == null || templates.isEmpty) {
      return const [];
    }
    final template = TemplateService.findTemplateForRevisionsobjekt(
      templates,
      ro,
    );
    return TemplateService.getSchemaFromTemplateParameter(
      template?.parameter,
      importHeaders: importHeaders,
    );
  }

  static List<Map<String, dynamic>> _schemaFromCsvRowCells({
    required Map<String, dynamic> params,
    required List<String> importHeaders,
    required CsvSettings? csvSettings,
  }) {
    final cellsRaw = params[CsvSettings.csvRowCellsParamKey];
    if (cellsRaw is Map && cellsRaw.isNotEmpty) {
      final cellHeaders = cellsRaw.keys.map((k) => k.toString()).toList();
      var fromCsv = CsvSettings.schemaFieldsFromCsvAttRowCells(
        params,
        importHeaders: cellHeaders,
      );
      if (fromCsv.isEmpty && importHeaders.isNotEmpty) {
        fromCsv = CsvSettings.schemaFieldsFromCsvAttRowCells(
          params,
          importHeaders: importHeaders,
        );
      }
      if (fromCsv.isEmpty &&
          csvSettings != null &&
          csvSettings.importHeaderRow.isNotEmpty) {
        fromCsv = CsvSettings.schemaFieldsFromCsvAttRowCells(
          params,
          importHeaders: csvSettings.importHeaderRow,
        );
      }
      return fromCsv;
    }
    if (importHeaders.isNotEmpty) {
      return CsvSettings.schemaFieldsFromCsvAttRowCells(
        params,
        importHeaders: importHeaders,
      );
    }
    if (csvSettings != null && csvSettings.importHeaderRow.isNotEmpty) {
      return CsvSettings.schemaFieldsFromCsvAttRowCells(
        params,
        importHeaders: csvSettings.importHeaderRow,
      );
    }
    return const [];
  }

  static List<Map<String, dynamic>> _filterMaps(
    List<Map<String, dynamic>> fields, {
    required SchemaResolvePurpose purpose,
    required CsvSettings? csvSettings,
  }) {
    var result = CsvSettings.filterSchemaFieldsForDialog(fields);
    if (csvSettings == null) return result;
    if (purpose == SchemaResolvePurpose.export) {
      return result.where((f) {
        final key = (f['key'] ?? '').toString();
        if (key.isEmpty) return true;
        if (csvSettings.isUpperHierarchyParamKey(key)) return false;
        if (csvSettings.isLeafNameParamKey(key)) return false;
        return true;
      }).toList();
    }
    return result.where((f) {
      final key = (f['key'] ?? '').toString();
      if (key.isEmpty) return true;
      return !csvSettings.isHierarchyParamKey(key) &&
          !csvSettings.isLeafNameParamKey(key);
    }).toList();
  }
}
