// Schema-Tab-Hilfen: Vorlagen ↔ Disziplinen mergen, Schema auflösen, Speichern filtern.

import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';

/// Logik für den Tab „Eingabefelder“ (ohne UI).
abstract final class CsvSettingsSchemaHelpers {
  /// DB-Disziplinen + optionale virtuelle Gewerke aus Vorlagen (nur Anzeige).
  static Future<List<Disziplin>> loadDisciplinesForSchemaEditor({
    required DatabaseService dbService,
    required String buildingId,
    required String projectId,
  }) async {
    var loaded = await dbService.getDisciplinesByBuildingId(buildingId);
    if (loaded.isNotEmpty) {
      loaded = await TemplateService.ensureDisciplinesFromTemplates(
        dbService,
        buildingId,
        projectId,
      );
    }

    final templateRows = await dbService.getTemplatesByProjectId(projectId);
    if (templateRows.isEmpty) return loaded;

    final virtual =
        TemplateService.buildVirtualDisciplinesFromTemplateRows(templateRows);
    final byLabel = {
      for (final d in loaded) d.label.trim().toLowerCase(): d,
    };
    for (final v in virtual) {
      final key = v.label.trim().toLowerCase();
      if (!byLabel.containsKey(key)) {
        loaded = [...loaded, v];
        byLabel[key] = v;
      }
    }
    return loaded;
  }

  /// Persistiert nur echte Disziplinen – keine reinen Vorlagen-Shells.
  static Future<void> savePersistedDisciplines({
    required DatabaseService dbService,
    required String buildingId,
    required List<Disziplin> disciplines,
    String? forceMaterializeLabel,
  }) async {
    final existing = await dbService.getDisciplinesByBuildingId(buildingId);
    final existingLabels = {
      for (final d in existing) d.label.trim().toLowerCase(),
    };
    final anlagen = await dbService.getAnlagenByBuildingId(buildingId);
    final labelsWithAnlagen = {
      for (final a in anlagen) a.discipline.label.trim().toLowerCase(),
    };

    final forceKey = forceMaterializeLabel?.trim().toLowerCase() ?? '';
    final toSave = <Disziplin>[];
    final savedKeys = <String>{};

    for (final d in disciplines) {
      final key = d.label.trim().toLowerCase();
      final keep = existingLabels.contains(key) ||
          labelsWithAnlagen.contains(key) ||
          (forceKey.isNotEmpty && forceKey == key);
      if (keep && savedKeys.add(key)) {
        toSave.add(d);
      }
    }

    if (forceKey.isNotEmpty) {
      for (final d in disciplines) {
        if (d.label.trim().toLowerCase() != forceKey) continue;
        if (savedKeys.add(forceKey)) toSave.add(d);
        break;
      }
    }

    await dbService.replaceDisciplines(buildingId, toSave);
  }

  static List<String> revisionsobjekteForDiscipline(
    Disziplin d,
    List<Template> templates,
  ) {
    final names = <String>{};
    for (final t in templates) {
      if (t.gewerk.trim() == d.label.trim()) {
        final typ = t.anlagentyp.trim();
        if (typ.isNotEmpty) names.add(typ);
      }
    }
    names.addAll(d.revisionsobjektSchemas.keys);
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<Map<String, dynamic>> schemaForRevisionsobjekt(
    Disziplin d,
    String ro,
    List<Template> templates,
  ) {
    final roFields = d.revisionsobjektSchemas[ro];
    if (roFields != null && roFields.isNotEmpty) {
      return roFields.map((f) => Map<String, dynamic>.from(f)).toList();
    }
    for (final t in templates) {
      if (t.gewerk.trim() == d.label.trim() &&
          t.anlagentyp.trim() == ro.trim()) {
        final fromTemplate =
            TemplateService.getSchemaFromTemplateParameter(t.parameter);
        if (fromTemplate.isNotEmpty) return fromTemplate;
      }
    }
    if (d.revisionsobjektSchemas.isEmpty) {
      return d.legacyIndividualSchemaFields;
    }
    return const [];
  }

  static Disziplin withUpdatedRevisionsobjektSchema(
    Disziplin d,
    String ro,
    List<Map<String, dynamic>> newSchema,
  ) {
    final updatedRoSchemas = Map<String, List<Map<String, dynamic>>>.from(
      d.revisionsobjektSchemas,
    );
    updatedRoSchemas[ro] =
        newSchema.map((f) => Map<String, dynamic>.from(f)).toList();

    return Disziplin(
      label: d.label,
      icon: d.icon,
      color: d.color,
      schema: d.globalSchemaFields,
      groupingKey: d.groupingKey,
      revisionsobjektSchemas: updatedRoSchemas,
    );
  }
}
