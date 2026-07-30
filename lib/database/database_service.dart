// lib/services/database_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import '../models/project.dart' as models;
import '../models/building.dart' as models;
import '../models/floor_plan.dart' as models;
import '../models/anlage.dart' as models;
import '../models/disziplin_schnittstelle.dart';
import '../services/template_service.dart';
import '../theme/app_palette.dart';
import '../utils/app_log.dart';

//

class _BuildingAnlagenListCache {
  List<models.Anlage>? all;
  final Map<String, List<models.Anlage>> byDiscipline = {};
}

/// Persistenz über Drift ([AppDatabase]). SharedPreferences nur für Flags/Settings.
class DatabaseService {
  final AppDatabase _db;
  final Map<String, Map<String, Disziplin>> _disciplinesCache = {};
  final Map<String, _BuildingAnlagenListCache> _anlagenListCache = {};

  void _invalidateAnlagenListCache(String buildingId) {
    _anlagenListCache.remove(buildingId);
  }
  
  Future<void> _markDisciplinesInitialized(String buildingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disciplines_initialized_$buildingId', true);
  }

  Future<bool> isDisciplinesInitialized(String buildingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disciplines_initialized_$buildingId') ?? false;
  }

  DatabaseService(this._db);

  // ========== PROJECTS ==========

  Future<List<models.Project>> getAllProjects() async {
    final projectRows = await _db.getAllProjects();
    if (projectRows.isEmpty) return [];

    final buildingRows = await _db.getAllActiveBuildings();
    final floorPlanRows = await _db.getAllFloorPlans();

    final floorsByBuildingId = <String, List<models.FloorPlan>>{};
    for (final f in floorPlanRows) {
      floorsByBuildingId.putIfAbsent(f.buildingId, () => []).add(
            models.FloorPlan(
              id: f.id,
              name: f.name,
              pdfPath: f.pdfPath,
              pdfName: f.pdfName,
            ),
          );
    }

    final buildingsByProjectId = <String, List<models.Building>>{};
    for (final row in buildingRows) {
      buildingsByProjectId.putIfAbsent(row.projectId, () => []).add(
            _buildingRowToModelSync(row, floorsByBuildingId[row.id] ?? const []),
          );
    }

    return projectRows
        .map(
          (row) => models.Project(
            id: row.id,
            name: row.name,
            description: row.description,
            customer: row.customer,
            buildings: buildingsByProjectId[row.id] ?? [],
          ),
        )
        .toList();
  }

  Future<models.Project?> getProjectById(String id) async {
    final row = await _db.getProjectById(id);
    if (row == null) return null;

    final buildings = await getBuildingsByProjectId(id);
    return models.Project(
      id: row.id,
      name: row.name,
      description: row.description,
      customer: row.customer,
      buildings: buildings,
    );
  }

  Future<void> insertProject(models.Project project) async {
    await _db.insertProject(ProjectsCompanion.insert(
      id: project.id,
      name: project.name,
      description: project.description,
      customer: project.customer,
    ));

    // Gebäude einfügen
    for (final building in project.buildings) {
      await insertBuilding(building, project.id);
    }
  }

  Future<void> updateProject(models.Project project) async {
    await _db.updateProject(
      project.id,
      ProjectsCompanion(
        name: Value(project.name),
        description: Value(project.description),
        customer: Value(project.customer),
      ),
    );

    // Gebäude aktualisieren
    final existingBuildings = await getBuildingsByProjectId(project.id);
    final existingIds = existingBuildings.map((b) => b.id).toSet();
    final newIds = project.buildings.map((b) => b.id).toSet();

    // Lösche entfernte Gebäude (Soft-Delete)
    for (final existing in existingBuildings) {
      if (!newIds.contains(existing.id)) {
        await softDeleteBuilding(existing.id);
      }
    }

    // Füge neue/aktualisierte Gebäude ein
    for (final building in project.buildings) {
      if (existingIds.contains(building.id)) {
        await updateBuilding(building);
      } else {
        await insertBuilding(building, project.id);
      }
    }
  }

  Future<void> softDeleteProject(String id) async {
    final buildings = await _db.getBuildingsByProjectId(id);
    for (final building in buildings) {
      await softDeleteBuilding(building.id);
    }
    await _db.softDeleteProject(id);
  }

  Future<void> restoreProject(String id) async {
    await _db.restoreProject(id);
    final deletedBuildings = await _db.getDeletedBuildingsByProjectId(id);
    for (final building in deletedBuildings) {
      await restoreBuilding(building.id);
    }
  }

  Future<void> permanentlyDeleteProject(String id) async {
    await _db.deleteProject(id);
  }

  Future<List<models.Project>> getDeletedProjects() async {
    final projectRows = await _db.getDeletedProjects();
    final projects = <models.Project>[];

    for (final row in projectRows) {
      final buildings = await getDeletedBuildingsByProjectId(row.id);
      projects.add(models.Project(
        id: row.id,
        name: row.name,
        description: row.description,
        customer: row.customer,
        buildings: buildings,
      ));
    }

    return projects;
  }

  // ========== BUILDINGS ==========

  Future<List<models.Building>> getBuildingsByProjectId(String projectId) async {
    final buildingRows = await _db.getBuildingsByProjectId(projectId);
    final buildings = <models.Building>[];

    for (final row in buildingRows) {
      final building = await _buildingRowToModel(row);
      buildings.add(building);
    }

    return buildings;
  }

  Future<models.Building?> getBuildingById(String id) async {
    final row = await _db.getBuildingById(id);
    if (row == null) return null;
    return await _buildingRowToModel(row);
  }

  Future<models.Building> _buildingRowToModel(BuildingDb row) async {
    // Anlagen werden bei Bedarf über getAnlagenBy* geladen – nicht hier,
    // sonst werden bei jedem Projekt-/Gebäude-Laden alle Anlagen des Gebäudes
    // mit vollem JSON-Parsing in den Speicher geholt (sehr langsam bei Importen).

    // FloorPlans laden
    final floorPlanRows = await _db.getFloorPlansByBuildingId(row.id);
    final floors = floorPlanRows
        .map((f) => models.FloorPlan(
              id: f.id,
              name: f.name,
              pdfPath: f.pdfPath,
              pdfName: f.pdfName,
            ))
        .toList();

    return _buildingRowToModelSync(row, floors);
  }

  models.Building _buildingRowToModelSync(
    BuildingDb row,
    List<models.FloorPlan> floors,
  ) {
    final renovationYears = row.renovationYears.isNotEmpty
        ? (json.decode(row.renovationYears) as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList()
        : <int>[];

    return models.Building(
      id: row.id,
      name: row.name,
      address: row.address,
      postalCode: row.postalCode,
      city: row.city,
      type: row.type,
      bgf: row.bgf,
      constructionYear: row.constructionYear,
      renovationYears: renovationYears,
      protectedMonument: row.protectedMonument,
      units: row.units,
      floorArea: row.floorArea,
      // Legacy-Feld: Anlagen liegen in der Anlagen-Tabelle, nicht mehr in Building.systems.
      systems: models.BuildingSystems(),
      floors: floors,
    );
  }

  Future<void> insertBuilding(models.Building building, String projectId) async {
    await _db.insertBuilding(BuildingsCompanion.insert(
      id: building.id,
      projectId: projectId,
      name: building.name,
      address: building.address,
      postalCode: building.postalCode,
      city: building.city,
      type: building.type,
      bgf: building.bgf,
      constructionYear: building.constructionYear,
      renovationYears: json.encode(building.renovationYears),
      protectedMonument: building.protectedMonument,
      units: building.units,
      floorArea: building.floorArea,
    ));

    // Systems einfügen
    for (final entry in building.systems.systemsMap.entries) {
      for (final anlage in entry.value) {
        await insertAnlage(anlage);
      }
    }

    // FloorPlans einfügen
    for (final floor in building.floors) {
      await insertFloorPlan(floor, building.id);
    }
  }

  Future<void> updateBuilding(models.Building building) async {
    await _db.updateBuilding(
      building.id,
      BuildingsCompanion(
        name: Value(building.name),
        address: Value(building.address),
        postalCode: Value(building.postalCode),
        city: Value(building.city),
        type: Value(building.type),
        bgf: Value(building.bgf),
        constructionYear: Value(building.constructionYear),
        renovationYears: Value(json.encode(building.renovationYears)),
        protectedMonument: Value(building.protectedMonument),
        units: Value(building.units),
        floorArea: Value(building.floorArea),
      ),
    );

    // Systems (Anlagen/Marker) werden NICHT mehr über updateBuilding synchronisiert.
    //
    // Hintergrund: Anlagen werden in der App an vielen Stellen direkt über
    // insertAnlage/updateAnlage/deleteAnlage gepflegt (z.B. Marker im PDF).
    // Das Building-Objekt im UI ist dabei häufig "stale" und enthält nicht alle
    // aktuellen Anlagen. Ein Sync hier würde dann Marker/Anlagen fälschlich löschen.
    //
    // Systems werden daher ausschließlich über die dedizierten Anlagen-Methoden
    // gepflegt, nicht über updateBuilding().

    // FloorPlans aktualisieren
    final existingFloors = await _db.getFloorPlansByBuildingId(building.id);
    final existingFloorIds = existingFloors.map((f) => f.id).toSet();
    final newFloorIds = building.floors.map((f) => f.id).toSet();

    // Lösche entfernte FloorPlans
    for (final existing in existingFloors) {
      if (!newFloorIds.contains(existing.id)) {
        await _db.deleteFloorPlan(existing.id);
      }
    }

    // Füge neue/aktualisierte FloorPlans ein
    for (final floor in building.floors) {
      if (existingFloorIds.contains(floor.id)) {
        await updateFloorPlan(floor);
      } else {
        await insertFloorPlan(floor, building.id);
      }
    }
  }

  Future<void> softDeleteBuilding(String id) async {
    final anlagen = await _db.getAnlagenByBuildingId(id);
    for (final anlage in anlagen) {
      await softDeleteAnlage(anlage.id);
    }
    await _db.softDeleteBuilding(id);
    _invalidateAnlagenListCache(id);
    _disciplinesCache.remove(id);
  }

  Future<void> restoreBuilding(String id) async {
    await _db.restoreBuilding(id);
    final deletedAnlagen = await _db.getDeletedAnlagenByBuildingId(id);
    for (final anlage in deletedAnlagen) {
      await _db.restoreAnlage(anlage.id);
    }
    _invalidateAnlagenListCache(id);
  }

  Future<void> permanentlyDeleteBuilding(String id) async {
    await _db.deleteBuilding(id);
    _invalidateAnlagenListCache(id);
    _disciplinesCache.remove(id);
  }

  Future<List<models.Building>> getDeletedBuildingsByProjectId(String projectId) async {
    final buildingRows = await _db.getDeletedBuildingsByProjectId(projectId);
    final buildings = <models.Building>[];

    for (final row in buildingRows) {
      buildings.add(await _buildingRowToModel(row));
    }

    return buildings;
  }

  Future<List<models.Building>> getDeletedBuildings() async {
    final buildingRows = await _db.getDeletedBuildings();
    final buildings = <models.Building>[];

    for (final row in buildingRows) {
      buildings.add(await _buildingRowToModel(row));
    }

    return buildings;
  }

  // ========== FLOOR PLANS ==========

  Future<void> insertFloorPlan(models.FloorPlan floorPlan, String buildingId) async {
    await _db.insertFloorPlan(FloorPlansCompanion.insert(
      id: floorPlan.id,
      buildingId: buildingId,
      name: floorPlan.name,
      pdfPath: Value(floorPlan.pdfPath),
      pdfName: Value(floorPlan.pdfName),
    ));
  }

  Future<void> updateFloorPlan(models.FloorPlan floorPlan) async {
    await _db.updateFloorPlan(
      floorPlan.id,
      FloorPlansCompanion(
        name: Value(floorPlan.name),
        pdfPath: floorPlan.pdfPath != null ? Value(floorPlan.pdfPath) : const Value.absent(),
        pdfName: floorPlan.pdfName != null ? Value(floorPlan.pdfName) : const Value.absent(),
      ),
    );
  }

  // ========== ANLAGEN ==========

  Future<Map<String, Disziplin>> _getDisciplinesMap(String buildingId) async {
    final cached = _disciplinesCache[buildingId];
    if (cached != null) return cached;

    final rows = await _db.getDisziplinenByBuildingId(buildingId);
    final map = <String, Disziplin>{};
    for (final row in rows) {
      try {
        final disc = Disziplin.fromJson(json.decode(row.data) as Map<String, dynamic>);
        map[disc.label.toLowerCase()] = disc;
      } catch (e) {
        appLog('Kaputter Disziplin-JSON für Gebäude $buildingId', error: e);
      }
    }
    _disciplinesCache[buildingId] = map;
    return map;
  }

  /// Merged die Schema-Felder aus der gespeicherten Anlagen-Disziplin in die Gebäude-Disziplin,
  /// damit ATT1, ATT2 usw. aus der Gewerkevorlage in der Parameterliste erscheinen.
  Disziplin _mergeDisciplineSchema({required Disziplin? base, required Disziplin fromAnlage}) {
    if (base == null) return fromAnlage;
    final baseKeys = base.schema
        .map((f) => (f['key'] ?? '').toString())
        .where((k) => k.isNotEmpty)
        .toSet();
    final additional = fromAnlage.schema
        .where((f) {
          final k = (f['key'] ?? '').toString();
          return k.isNotEmpty && !baseKeys.contains(k);
        })
        .map((f) => Map<String, dynamic>.from(f))
        .toList();

    final mergedRo = Map<String, List<Map<String, dynamic>>>.from(
      base.revisionsobjektSchemas,
    );
    fromAnlage.revisionsobjektSchemas.forEach((key, fields) {
      mergedRo[key] = TemplateService.mergeSchemaFieldLists(
        mergedRo[key] ?? const [],
        fields,
      );
    });

    return Disziplin(
      label: base.label,
      icon: base.icon,
      color: base.color,
      schema: [...base.schema, ...additional],
      groupingKey: base.groupingKey,
      revisionsobjektSchemas: mergedRo,
    );
  }

  /// Listen/Übersicht: Gebäude-Disziplin + gespeichertes Anlagen-Schema (für Export/Dialog).
  models.Anlage _anlageRowToModelLight(AnlageDb row, Disziplin? currentDiscipline) {
    Disziplin discipline;
    try {
      final storedDiscipline = Disziplin.fromJson(
        json.decode(row.discipline) as Map<String, dynamic>,
      );
      discipline = _mergeDisciplineSchema(
        base: currentDiscipline ?? storedDiscipline,
        fromAnlage: storedDiscipline,
      );
    } catch (e) {
      appLog('Anlage-Disziplin JSON ungültig', error: e);
      discipline = currentDiscipline ??
          Disziplin(
            label: row.markerType,
            icon: Icons.build,
            color: AppPalette.primary,
            schema: const <Map<String, dynamic>>[],
          );
    }

    final rawParams = json.decode(row.params);
    final baseParams = rawParams is Map
        ? Map<String, dynamic>.from(rawParams.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
    baseParams.remove('_validated');
    baseParams.remove('_validatedAt');

    Map<String, dynamic>? markerInfo;
    if (row.isMarker && row.markerInfo != null) {
      final decoded = json.decode(row.markerInfo!);
      markerInfo = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : {'data': decoded};
    }

    return models.Anlage(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      params: baseParams,
      floorId: row.floorId ?? '',
      buildingId: row.buildingId,
      isMarker: row.isMarker,
      markerInfo: markerInfo,
      markerType: row.markerType,
      discipline: discipline,
    );
  }

  Future<List<models.Anlage>> _rowsToAnlagenList(
    List<AnlageDb> rows,
    String buildingId,
  ) async {
    if (rows.isEmpty) return [];
    final disciplinesMap = await _getDisciplinesMap(buildingId);
    return [
      for (final row in rows)
        _anlageRowToModelLight(
          row,
          disciplinesMap[row.markerType.toLowerCase()],
        ),
    ];
  }

  models.Anlage _anlageRowToModelWithCurrentDiscipline(AnlageDb row, Disziplin? currentDiscipline) {
    // Gespeicherte Disziplin der Anlage (enthält ggf. Schema aus Gewerkevorlage: ATT1, ATT2, …)
    final storedDiscipline = Disziplin.fromJson(json.decode(row.discipline) as Map<String, dynamic>);

    // Disziplin für die Anlage: Gebäude-Disziplin als Basis, Schema aus gespeicherter Anlage übernehmen,
    // damit die individuellen Attribute aus der Gewerke-CSV (Brennstoff, Wasserart, Leistung etc.) erhalten bleiben.
    final discipline = _mergeDisciplineSchema(
      base: currentDiscipline ?? storedDiscipline,
      fromAnlage: storedDiscipline,
    );

    // Params als vollständige Map mit String-Keys (inkl. aller Attribut-Spalten aus dem Import)
    final rawParams = json.decode(row.params);
    final baseParams = rawParams is Map
        ? Map<String, dynamic>.from(rawParams.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};

    // Alte Validierungs-Meta-Felder bereinigen, da sie nicht mehr verwendet werden
    baseParams.remove('_validated');
    baseParams.remove('_validatedAt');

    return models.Anlage(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      params: baseParams,
      floorId: row.floorId ?? '',
      buildingId: row.buildingId,
      isMarker: row.isMarker,
      markerInfo: row.markerInfo != null
          ? (json.decode(row.markerInfo!) is Map
              ? json.decode(row.markerInfo!) as Map<String, dynamic>
              : {'data': json.decode(row.markerInfo!)})
          : null,
      markerType: row.markerType,
      discipline: discipline,
    );
  }

  AnlagenCompanion _anlageCompanion(models.Anlage anlage) {
    return AnlagenCompanion.insert(
      id: anlage.id,
      parentId: Value(anlage.parentId),
      name: anlage.name,
      params: json.encode(anlage.params),
      floorId: Value(anlage.floorId.isEmpty ? null : anlage.floorId),
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo != null ? Value(json.encode(anlage.markerInfo)) : const Value.absent(),
      markerType: anlage.markerType,
      discipline: json.encode(anlage.discipline.toJson()),
    );
  }

  Future<void> insertAnlage(models.Anlage anlage) async {
    await _db.insertAnlage(_anlageCompanion(anlage));
    _invalidateAnlagenListCache(anlage.buildingId);
  }

  /// Fügt viele Anlagen in einer Transaktion ein (deutlich schneller bei CSV-Import).
  Future<void> insertAnlagenBatch(List<models.Anlage> anlagen) async {
    if (anlagen.isEmpty) return;
    final buildingId = anlagen.first.buildingId;
    await _db.transaction(() async {
      for (final anlage in anlagen) {
        await _db.insertAnlage(_anlageCompanion(anlage));
      }
    });
    _invalidateAnlagenListCache(buildingId);
  }

  /// LfdNummer → Anlagen-ID für ein Gebäude (ein DB-Lauf, nur Params-JSON).
  Future<Map<String, String>> getLfdNummerToIdMap(String buildingId) async {
    final rows = await _db.getAnlagenByBuildingId(buildingId);
    final map = <String, String>{};
    for (final row in rows) {
      final rawParams = json.decode(row.params);
      if (rawParams is! Map) continue;
      final lfd = rawParams['lfdNummer']?.toString().trim();
      if (lfd != null && lfd.isNotEmpty) {
        map[lfd] = row.id;
      }
    }
    return map;
  }

  Future<void> updateAnlage(models.Anlage anlage) async {
    await _db.updateAnlage(
      anlage.id,
      AnlagenCompanion(
        parentId: Value(anlage.parentId),
        name: Value(anlage.name),
        params: Value(json.encode(anlage.params)),
        floorId: Value(anlage.floorId.isEmpty ? null : anlage.floorId),
        isMarker: Value(anlage.isMarker),
        markerInfo: anlage.markerInfo != null ? Value(json.encode(anlage.markerInfo)) : const Value.absent(),
        markerType: Value(anlage.markerType),
        discipline: Value(json.encode(anlage.discipline.toJson())),
      ),
    );
    _invalidateAnlagenListCache(anlage.buildingId);
  }

  /// Upsert vieler Anlagen in einer Transaktion (vermeidet N+1 bei Speichern).
  Future<void> upsertAnlagenBatch(List<models.Anlage> anlagen) async {
    if (anlagen.isEmpty) return;
    final buildingIds = <String>{};
    await _db.transaction(() async {
      for (final anlage in anlagen) {
        buildingIds.add(anlage.buildingId);
        final existing = await _db.getAnlageById(anlage.id);
        if (existing != null) {
          await _db.updateAnlage(
            anlage.id,
            AnlagenCompanion(
              parentId: Value(anlage.parentId),
              name: Value(anlage.name),
              params: Value(json.encode(anlage.params)),
              floorId: Value(anlage.floorId.isEmpty ? null : anlage.floorId),
              isMarker: Value(anlage.isMarker),
              markerInfo: anlage.markerInfo != null
                  ? Value(json.encode(anlage.markerInfo))
                  : const Value.absent(),
              markerType: Value(anlage.markerType),
              discipline: Value(json.encode(anlage.discipline.toJson())),
            ),
          );
        } else {
          await _db.insertAnlage(_anlageCompanion(anlage));
        }
      }
    });
    for (final id in buildingIds) {
      _invalidateAnlagenListCache(id);
    }
  }

  /// Aktualisiert alle Anlagen einer Disziplin, wenn diese umbenannt wurde.
  Future<void> updateAnlagenDiscipline(String buildingId, String oldLabel, String newLabel, Disziplin newDiscipline) async {
    await _db.updateAnlagenDiscipline(
      buildingId,
      oldLabel,
      newLabel,
      json.encode(newDiscipline.toJson()),
    );
    _invalidateAnlagenListCache(buildingId);
  }

  /// Verschiebt eine oder mehrere Anlagen (inkl. aller Kinder rekursiv).
  /// Aktualisiert floorId, parentId, buildingId, discipline und optional params.
  Future<void> moveAnlagen(
    List<String> anlageIds, {
    String? newFloorId,
    String? newParentId,
    String? newBuildingId,
    Disziplin? newDiscipline,
    Map<String, dynamic>? paramsToUpdate,
    void Function(Map<String, dynamic> params)? patchParams,
  }) async {
    for (final anlageId in anlageIds) {
      // Lade aktuelle Anlage
      final currentAnlage = await getAnlageById(anlageId);
      if (currentAnlage == null) continue;

      final params = Map<String, dynamic>.from(currentAnlage.params);
      if (paramsToUpdate != null && paramsToUpdate.isNotEmpty) {
        params.addAll(paramsToUpdate);
      }
      patchParams?.call(params);

      // Erstelle aktualisierte Anlage
      final updatedAnlage = models.Anlage(
        id: currentAnlage.id,
        parentId: newParentId ?? currentAnlage.parentId,
        name: currentAnlage.name,
        params: params,
        floorId: newFloorId ?? currentAnlage.floorId,
        buildingId: newBuildingId ?? currentAnlage.buildingId,
        isMarker: currentAnlage.isMarker,
        markerInfo: currentAnlage.markerInfo,
        markerType: newDiscipline?.label ?? currentAnlage.markerType,
        discipline: newDiscipline ?? currentAnlage.discipline,
      );

      await updateAnlage(updatedAnlage);

      // WICHTIG: Verschiebe auch alle Kinder rekursiv
      final children = await getAnlagenByParentId(anlageId);
      if (children.isNotEmpty) {
        await moveAnlagen(
          children.map((c) => c.id).toList(),
          newFloorId: newFloorId,
          newParentId: anlageId, // Parent bleibt gleich (die verschobene Anlage)
          newBuildingId: newBuildingId,
          newDiscipline: newDiscipline,
          paramsToUpdate: paramsToUpdate,
          patchParams: patchParams,
        );
      }
    }
  }

  Future<List<models.Anlage>> getAnlagenForProject(
    String projectId, {
    String? includeBuildingId,
  }) async {
    final buildingRows = await _db.getBuildingsByProjectId(projectId);
    final allAnlagen = <models.Anlage>[];
    final seenIds = <String>{};

    for (final row in buildingRows) {
      for (final anlage in await getAnlagenByBuildingId(row.id)) {
        if (seenIds.add(anlage.id)) {
          allAnlagen.add(anlage);
        }
      }
    }

    if (includeBuildingId != null && includeBuildingId.isNotEmpty) {
      for (final anlage in await getAnlagenByBuildingId(includeBuildingId)) {
        if (seenIds.add(anlage.id)) {
          allAnlagen.add(anlage);
        }
      }
    }

    return allAnlagen;
  }

  Future<List<models.Anlage>> getAnlagenByBuildingId(String buildingId) async {
    final cache = _anlagenListCache[buildingId];
    if (cache?.all != null) return cache!.all!;

    final rows = await _db.getAnlagenByBuildingId(buildingId);
    final anlagen = await _rowsToAnlagenList(rows, buildingId);
    _anlagenListCache.putIfAbsent(buildingId, () => _BuildingAnlagenListCache()).all = anlagen;
    return anlagen;
  }

  Future<List<models.Anlage>> getAnlagenByBuildingIdAndDiscipline(
    String buildingId,
    String disciplineLabel,
  ) async {
    final cache = _anlagenListCache[buildingId];
    final cached = cache?.byDiscipline[disciplineLabel];
    if (cached != null) return cached;

    final rows = await _db.getAnlagenByBuildingIdAndDiscipline(buildingId, disciplineLabel);
    final anlagen = await _rowsToAnlagenList(rows, buildingId);
    _anlagenListCache.putIfAbsent(buildingId, () => _BuildingAnlagenListCache())
        .byDiscipline[disciplineLabel] = anlagen;
    return anlagen;
  }

  Future<models.Anlage?> getAnlageById(String id) async {
    final row = await _db.getAnlageById(id);
    if (row == null) return null;
    final disciplinesMap = await _getDisciplinesMap(row.buildingId);
    final currentDiscipline = disciplinesMap[row.markerType.toLowerCase()];
    return _anlageRowToModelWithCurrentDiscipline(row, currentDiscipline);
  }

  Future<List<models.Anlage>> getAnlagenByParentId(String parentId) async {
    final rows = await _db.getAnlagenByParentId(parentId);
    if (rows.isEmpty) return [];
    return _rowsToAnlagenList(rows, rows.first.buildingId);
  }

  /// Findet eine Anlage anhand der laufenden Nummer (lfdNummer) und buildingId.
  /// Die lfdNummer wird in den Params als "lfdNummer" gespeichert.
  Future<models.Anlage?> getAnlageByLfdNummer(String lfdNummer, String buildingId) async {
    final id = (await getLfdNummerToIdMap(buildingId))[lfdNummer.trim()];
    if (id == null) return null;
    return getAnlageById(id);
  }

  Future<void> softDeleteAnlage(String id) async {
    final children = await getAnlagenByParentId(id);
    for (final child in children) {
      await softDeleteAnlage(child.id);
    }
    await _db.softDeleteAnlage(id);
    final row = await _db.getAnlageByIdIncludingDeleted(id);
    if (row != null) _invalidateAnlagenListCache(row.buildingId);
  }

  Future<void> restoreAnlage(String id) async {
    await _db.restoreAnlage(id);
    final row = await _db.getAnlageByIdIncludingDeleted(id);
    if (row != null) _invalidateAnlagenListCache(row.buildingId);
  }

  Future<void> permanentlyDeleteAnlage(String id) async {
    final row = await _db.getAnlageByIdIncludingDeleted(id);
    final buildingId = row?.buildingId;

    final childrenRows = await _db.getAnlagenByParentIdIncludingDeleted(id);
    for (final childRow in childrenRows) {
      await permanentlyDeleteAnlage(childRow.id);
    }

    await _db.deleteAnlage(id);
    if (buildingId != null) _invalidateAnlagenListCache(buildingId);
  }

  Future<List<models.Anlage>> getDeletedAnlagen() async {
    final rows = await _db.getDeletedAnlagen();
    if (rows.isEmpty) return [];

    final byBuilding = <String, List<AnlageDb>>{};
    for (final row in rows) {
      byBuilding.putIfAbsent(row.buildingId, () => []).add(row);
    }

    final result = <models.Anlage>[];
    for (final entry in byBuilding.entries) {
      result.addAll(await _rowsToAnlagenList(entry.value, entry.key));
    }
    return result;
  }

  /// Löscht eine Anlage und rekursiv alle ihre Kinder (Bauteile) – Soft-Delete.
  Future<void> deleteAnlage(String id) async {
    await softDeleteAnlage(id);
  }

  /// Hartes Löschen einer Anlage inkl. Kinder (nur Papierkorb / endgültig löschen).
  Future<void> hardDeleteAnlage(String id) async {
    await permanentlyDeleteAnlage(id);
  }

  Future<void> _deletePhotoFilesFromParamsJson(String? paramsJson) async {
    if (paramsJson == null || paramsJson.trim().isEmpty) return;
    try {
      final params = json.decode(paramsJson) as Map<String, dynamic>;
      final photoPaths = params['photoPaths'];
      if (photoPaths is! List) return;

      Directory? docsDir;
      Directory? supportDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
        supportDir = await getApplicationSupportDirectory();
      } catch (e) {
        appLog('App-Verzeichnisse für Foto-Löschung nicht ermittelbar', error: e);
        return;
      }

      final allowedRoots = <String>[
        p.normalize(docsDir.path),
        p.normalize(supportDir.path),
      ];

      for (final raw in photoPaths) {
        final path = raw?.toString().trim() ?? '';
        if (path.isEmpty) continue;
        final normalized = p.normalize(path);
        final allowed = allowedRoots.any(
          (root) => normalized == root || p.isWithin(root, normalized),
        );
        if (!allowed) {
          appLog('Foto-Löschung übersprungen (außerhalb App-Sandbox): $normalized');
          continue;
        }
        final file = File(normalized);
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          appLog('Foto-Datei konnte nicht gelöscht werden: $normalized', error: e);
        }
      }
    } catch (e) {
      appLog('Params-JSON für Foto-Löschung ungültig', error: e);
    }
  }

  /// Löscht alle Anlagen-Zeilen eines Gebäudes (aktiv + Papierkorb/soft-deleted).
  Future<int> countAllAnlagenRowsForBuilding(String buildingId) async {
    final active = await _db.getAnlagenByBuildingId(buildingId);
    final deleted = await _db.getDeletedAnlagenByBuildingId(buildingId);
    return active.length + deleted.length;
  }

  /// Endgültiges Löschen aller gebäudebezogenen Betriebsdaten (kein Soft-Delete).
  ///
  /// Entfernt: alle Anlagen (inkl. Bauteile/Marker), Gewerke/Disziplinen,
  /// Grundrisse (DB), Anhänge, zugehörige Fotodateien.
  Future<void> permanentlyDeleteAllBuildingOperationalData(
    String buildingId, {
    List<models.FloorPlan>? floorPlansForFileCleanup,
  }) async {
    final activeRows = await _db.getAnlagenByBuildingId(buildingId);
    final deletedRows = await _db.getDeletedAnlagenByBuildingId(buildingId);
    for (final row in [...activeRows, ...deletedRows]) {
      await _deletePhotoFilesFromParamsJson(row.params);
    }

    if (floorPlansForFileCleanup != null) {
      Directory? docsDir;
      Directory? supportDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
        supportDir = await getApplicationSupportDirectory();
      } catch (e) {
        appLog('App-Verzeichnisse für Grundriss-Löschung nicht ermittelbar', error: e);
      }
      final allowedRoots = <String>[
        if (docsDir != null) p.normalize(docsDir.path),
        if (supportDir != null) p.normalize(supportDir.path),
      ];

      for (final floor in floorPlansForFileCleanup) {
        final path = floor.pdfPath?.trim();
        if (path == null || path.isEmpty) continue;
        final normalized = p.normalize(path);
        final allowed = allowedRoots.isEmpty ||
            allowedRoots.any(
              (root) => normalized == root || p.isWithin(root, normalized),
            );
        if (!allowed) {
          appLog('Grundriss-Löschung übersprungen (außerhalb App-Sandbox): $normalized');
          continue;
        }
        final file = File(normalized);
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          appLog('Grundriss-PDF konnte nicht gelöscht werden: $normalized', error: e);
        }
      }
    }

    await _db.transaction(() async {
      await _db.deleteAnlagenByBuildingId(buildingId);
      await _db.deleteDisziplinenByBuildingId(buildingId);
      await _db.deleteFloorPlansByBuildingId(buildingId);
      await _db.deleteAttachmentsByBuildingId(buildingId);
    });

    _invalidateAnlagenListCache(buildingId);
    _disciplinesCache.remove(buildingId);
  }

  /// Endgültiges Löschen aller Gewerkevorlagen und globalem Import-Schema (projektweit).
  Future<void> permanentlyDeleteProjectImportData(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return;

    await _db.deleteTemplatesByProjectId(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('global_schema_$id');
  }

  Future<int> countTemplatesByProjectId(String projectId) async {
    final rows = await _db.getTemplatesByProjectId(projectId);
    return rows.length;
  }

  // ========== DISZIPLINEN ==========

  Future<List<Disziplin>> getDisciplinesByBuildingId(String buildingId) async {
    final map = await _getDisciplinesMap(buildingId);
    final list = map.values.toList();
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  Future<void> upsertDiscipline(String buildingId, Disziplin discipline) async {
    await _db.upsertDisziplin(DisziplinenCompanion.insert(
      buildingId: buildingId,
      label: discipline.label,
      data: json.encode(discipline.toJson()),
    ));
    _disciplinesCache.remove(buildingId);
    await _markDisciplinesInitialized(buildingId);
  }

  Future<void> replaceDisciplines(String buildingId, List<Disziplin> disciplines) async {
    await _db.transaction(() async {
      await _db.deleteDisziplinenByBuildingId(buildingId);
      for (final d in disciplines) {
        await _db.upsertDisziplin(DisziplinenCompanion.insert(
          buildingId: buildingId,
          label: d.label,
          data: json.encode(d.toJson()),
        ));
      }
    });
    _disciplinesCache.remove(buildingId);
    await _markDisciplinesInitialized(buildingId);
  }

  Future<void> deleteDiscipline(String buildingId, String label) async {
    await _db.deleteDisziplin(buildingId, label);
    _disciplinesCache.remove(buildingId);
    await _markDisciplinesInitialized(buildingId);
  }

  // ========== PROJECT ID ==========

  /// Ermittelt die projectId für ein gegebenes buildingId (nur aktive Gebäude)
  Future<String?> getProjectIdByBuildingId(String buildingId) async {
    final building = await _db.getBuildingById(buildingId);
    return building?.projectId;
  }

  Future<String?> getProjectIdByBuildingIdIncludingDeleted(String buildingId) async {
    final building = await _db.getBuildingByIdIncludingDeleted(buildingId);
    return building?.projectId;
  }

  Future<String?> getProjectNameByIdIncludingDeleted(String projectId) async {
    final project = await _db.getProjectByIdIncludingDeleted(projectId);
    return project?.name;
  }

  // ========== TEMPLATES ==========

  /// Lädt alle Templates für ein Projekt
  Future<List<TemplateDb>> getTemplatesByProjectId(String projectId) async {
    return await _db.getTemplatesByProjectId(projectId);
  }

  /// Lädt Templates für ein Projekt und ein bestimmtes Gewerk
  Future<List<TemplateDb>> getTemplatesByProjectIdAndGewerk(String projectId, String gewerk) async {
    return await _db.getTemplatesByProjectIdAndGewerk(projectId, gewerk);
  }

  /// Fügt ein Template in die Datenbank ein
  Future<void> insertTemplate(
    String projectId,
    String gewerk,
    String anlageBauteil,
    String anlagentyp,
    String bezeichnung,
    String? parameter,
  ) async {
    await _db.insertTemplate(TemplatesCompanion.insert(
      projectId: projectId,
      gewerk: gewerk,
      anlageBauteil: anlageBauteil,
      anlagentyp: anlagentyp,
      bezeichnung: bezeichnung,
      parameter: parameter != null ? Value(parameter) : const Value.absent(),
    ));
  }

  /// Löscht alle Templates für ein Projekt
  Future<void> deleteTemplatesByProjectId(String projectId) async {
    await _db.deleteTemplatesByProjectId(projectId);
  }
}

