// lib/services/database_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import '../models/project.dart' as models;
import '../models/building.dart' as models;
import '../models/envelope.dart' as models;
import '../models/floor_plan.dart' as models;
import '../models/anlage.dart' as models;
import '../models/consumption.dart' as models;
import '../models/attachments.dart' as models;
import '../models/disziplin_schnittstelle.dart';

class DatabaseService {
  final AppDatabase _db;
  final Map<String, Map<String, Disziplin>> _disciplinesCache = {};
  
  Future<void> _markDisciplinesInitialized(String buildingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disciplines_initialized_$buildingId', true);
  }

  Future<bool> isDisciplinesInitialized(String buildingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disciplines_initialized_$buildingId') ?? false;
  }
  
  // Singleton-Instanz
  static DatabaseService? _instance;
  
  DatabaseService._(this._db);
  
  factory DatabaseService(AppDatabase db) {
    _instance ??= DatabaseService._(db);
    return _instance!;
  }
  
  static DatabaseService? get instance => _instance;

  // ========== PROJECTS ==========

  Future<List<models.Project>> getAllProjects() async {
    final projectRows = await _db.getAllProjects();
    final projects = <models.Project>[];

    for (final row in projectRows) {
      final buildings = await getBuildingsByProjectId(row.id);
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

    // Lösche entfernte Gebäude
    for (final existing in existingBuildings) {
      if (!newIds.contains(existing.id)) {
        await deleteBuilding(existing.id);
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

  Future<void> deleteProject(String id) async {
    await _db.deleteProject(id);
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
    // Building ist hier die generierte Drift-Klasse
    // Envelope laden
    final envelopeRow = await _db.getEnvelopeByBuildingId(row.id);
    final envelope = envelopeRow != null
        ? await _envelopeRowToModel(envelopeRow)
        : models.Envelope(
            walls: [],
            roof: models.Roof(type: '', uValue: 0.0, area: 0.0, insulation: false),
            floor: models.FloorSurface(type: '', uValue: 0.0, area: 0.0, insulated: false),
            windows: [],
          );

    // Systems laden
    final anlagenRows = await _db.getAnlagenByBuildingId(row.id);
    final disciplinesMap = await _getDisciplinesMap(row.id);
    final systemsMap = <String, List<models.Anlage>>{};
    for (final anlageRow in anlagenRows) {
      final discipline = Disziplin.fromJson(json.decode(anlageRow.discipline));
      final label = discipline.label;
      final currentDiscipline = disciplinesMap[label.toLowerCase()];
      final anlage = _anlageRowToModelWithCurrentDiscipline(anlageRow, currentDiscipline);
      systemsMap.putIfAbsent(label, () => []).add(anlage);
    }
    final systems = models.BuildingSystems(systems: systemsMap);

    // FloorPlans laden
    final floorPlanRows = await _db.getFloorPlansByBuildingId(row.id);
    final floors = floorPlanRows.map((f) => models.FloorPlan(
          id: f.id,
          name: f.name,
          pdfPath: f.pdfPath,
          pdfName: f.pdfName,
        )).toList();

    // RenovationYears parsen
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
      envelope: envelope,
      systems: systems,
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

    // Envelope einfügen
    await insertEnvelope(building.envelope, building.id);

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

    // Envelope aktualisieren
    final existingEnvelope = await _db.getEnvelopeByBuildingId(building.id);
    if (existingEnvelope != null) {
      await updateEnvelope(building.envelope, existingEnvelope.id);
    } else {
      await insertEnvelope(building.envelope, building.id);
    }

    // Systems aktualisieren
    final existingAnlagen = await _db.getAnlagenByBuildingId(building.id);
    final existingIds = existingAnlagen.map((a) => a.id).toSet();
    final newIds = building.systems.systemsMap.values
        .expand((list) => list.map((a) => a.id))
        .toSet();

    // Lösche entfernte Anlagen
    for (final existing in existingAnlagen) {
      if (!newIds.contains(existing.id)) {
        await _db.deleteAnlage(existing.id);
      }
    }

    // Füge neue/aktualisierte Anlagen ein
    for (final entry in building.systems.systemsMap.entries) {
      for (final anlage in entry.value) {
        if (existingIds.contains(anlage.id)) {
          await updateAnlage(anlage);
        } else {
          await insertAnlage(anlage);
        }
      }
    }

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

  Future<void> deleteBuilding(String id) async {
    await _db.deleteBuilding(id);
  }

  // ========== ENVELOPES ==========

  Future<models.Envelope> _envelopeRowToModel(EnvelopeDb row) async {
    // Envelope ist hier die generierte Drift-Klasse
    final wallsRows = await _db.getWallsByEnvelopeId(row.id);
    final walls = wallsRows.map((w) => models.Wall(
          orientation: w.orientation,
          type: w.type,
          uValue: w.uValue,
          area: w.area,
          insulation: w.insulation,
        )).toList();

    final roof = models.Roof(
      type: row.roofType,
      uValue: row.roofUValue,
      area: row.roofArea,
      insulation: row.roofInsulation,
    );

    final floor = models.FloorSurface(
      type: row.floorType,
      uValue: row.floorUValue,
      area: row.floorArea,
      insulated: row.floorInsulated,
    );

    final windowsRows = await _db.getWindowsByEnvelopeId(row.id);
    final windows = windowsRows.map((w) => models.WindowElement(
          orientation: w.orientation,
          year: w.year,
          frame: w.frame,
          glazing: w.glazing,
          uValue: w.uValue,
          area: w.area,
        )).toList();

    return models.Envelope(
      walls: walls,
      roof: roof,
      floor: floor,
      windows: windows,
    );
  }

  Future<void> insertEnvelope(models.Envelope envelope, String buildingId) async {
    final envelopeId = buildingId; // Verwende buildingId als envelopeId
    await _db.insertEnvelope(EnvelopesCompanion.insert(
      id: envelopeId,
      buildingId: buildingId,
      roofType: envelope.roof.type,
      roofUValue: envelope.roof.uValue,
      roofArea: envelope.roof.area,
      roofInsulation: envelope.roof.insulation,
      floorType: envelope.floor.type,
      floorUValue: envelope.floor.uValue,
      floorArea: envelope.floor.area,
      floorInsulated: envelope.floor.insulated,
    ));

    // Walls einfügen
    for (final wall in envelope.walls) {
      await _db.insertWall(WallsCompanion.insert(
        envelopeId: envelopeId,
        orientation: wall.orientation,
        type: wall.type,
        uValue: wall.uValue,
        area: wall.area,
        insulation: wall.insulation,
      ));
    }

    // Windows einfügen
    for (final window in envelope.windows) {
      await _db.insertWindow(WindowsCompanion.insert(
        envelopeId: envelopeId,
        orientation: window.orientation,
        year: window.year,
        frame: window.frame,
        glazing: window.glazing,
        uValue: window.uValue,
        area: window.area,
      ));
    }
  }

  Future<void> updateEnvelope(models.Envelope envelope, String envelopeId) async {
    await _db.updateEnvelope(
      envelopeId,
      EnvelopesCompanion(
        roofType: Value(envelope.roof.type),
        roofUValue: Value(envelope.roof.uValue),
        roofArea: Value(envelope.roof.area),
        roofInsulation: Value(envelope.roof.insulation),
        floorType: Value(envelope.floor.type),
        floorUValue: Value(envelope.floor.uValue),
        floorArea: Value(envelope.floor.area),
        floorInsulated: Value(envelope.floor.insulated),
      ),
    );

    // Walls aktualisieren
    await _db.deleteWallsByEnvelopeId(envelopeId);
    for (final wall in envelope.walls) {
      await _db.insertWall(WallsCompanion.insert(
        envelopeId: envelopeId,
        orientation: wall.orientation,
        type: wall.type,
        uValue: wall.uValue,
        area: wall.area,
        insulation: wall.insulation,
      ));
    }

    // Windows aktualisieren
    await _db.deleteWindowsByEnvelopeId(envelopeId);
    for (final window in envelope.windows) {
      await _db.insertWindow(WindowsCompanion.insert(
        envelopeId: envelopeId,
        orientation: window.orientation,
        year: window.year,
        frame: window.frame,
        glazing: window.glazing,
        uValue: window.uValue,
        area: window.area,
      ));
    }
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
      } catch (_) {
        // Ignorieren: kaputter JSON-Eintrag
      }
    }
    _disciplinesCache[buildingId] = map;
    return map;
  }

  models.Anlage _anlageRowToModelWithCurrentDiscipline(AnlageDb row, Disziplin? currentDiscipline) {
    // Verwende die aktuelle Disziplin, falls verfügbar, sonst die gespeicherte
    final discipline = currentDiscipline ?? Disziplin.fromJson(json.decode(row.discipline));
    
    return models.Anlage(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      params: json.decode(row.params) as Map<String, dynamic>,
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

  Future<void> insertAnlage(models.Anlage anlage) async {
    await _db.insertAnlage(AnlagenCompanion.insert(
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
    ));
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
  }

  /// Aktualisiert alle Anlagen einer Disziplin, wenn diese umbenannt wurde.
  Future<void> updateAnlagenDiscipline(String buildingId, String oldLabel, String newLabel, Disziplin newDiscipline) async {
    await _db.updateAnlagenDiscipline(
      buildingId,
      oldLabel,
      newLabel,
      json.encode(newDiscipline.toJson()),
    );
  }

  Future<List<models.Anlage>> getAnlagenByBuildingId(String buildingId) async {
    final rows = await _db.getAnlagenByBuildingId(buildingId);
    final disciplinesMap = await _getDisciplinesMap(buildingId);
    final anlagen = <models.Anlage>[];
    for (final row in rows) {
      final currentDiscipline = disciplinesMap[row.markerType.toLowerCase()];
      anlagen.add(_anlageRowToModelWithCurrentDiscipline(row, currentDiscipline));
    }
    return anlagen;
  }

  Future<List<models.Anlage>> getAnlagenByBuildingIdAndDiscipline(String buildingId, String disciplineLabel) async {
    final rows = await _db.getAnlagenByBuildingIdAndDiscipline(buildingId, disciplineLabel);
    final disciplinesMap = await _getDisciplinesMap(buildingId);
    final currentDiscipline = disciplinesMap[disciplineLabel.toLowerCase()];
    return rows.map((row) => _anlageRowToModelWithCurrentDiscipline(row, currentDiscipline)).toList();
  }

  Future<models.Anlage?> getAnlageById(String id) async {
    final row = await _db.getAnlageById(id);
    if (row == null) return null;
    final disciplinesMap = await _getDisciplinesMap(row.buildingId);
    final currentDiscipline = disciplinesMap[row.markerType.toLowerCase()];
    return _anlageRowToModelWithCurrentDiscipline(row, currentDiscipline);
  }

  /// Findet eine Anlage anhand der laufenden Nummer (lfdNummer) und buildingId.
  /// Die lfdNummer wird in den Params als "lfdNummer" gespeichert.
  Future<models.Anlage?> getAnlageByLfdNummer(String lfdNummer, String buildingId) async {
    final allAnlagen = await getAnlagenByBuildingId(buildingId);
    for (final anlage in allAnlagen) {
      final lfdNummerInParams = anlage.params['lfdNummer']?.toString();
      if (lfdNummerInParams != null && lfdNummerInParams.trim() == lfdNummer.trim()) {
        return anlage;
      }
    }
    return null;
  }

  Future<void> deleteAnlage(String id) async {
    await _db.deleteAnlage(id);
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

  // ========== CONSUMPTIONS ==========

  Future<models.Consumption?> getConsumptionByBuildingId(String buildingId) async {
    final row = await _db.getConsumptionByBuildingId(buildingId);
    if (row == null) return null;

    return models.Consumption(
      electricityKWh: (json.decode(row.electricityKWh) as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      gasKWh: (json.decode(row.gasKWh) as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Future<void> insertConsumption(models.Consumption consumption, String buildingId) async {
    final consumptionId = buildingId; // Verwende buildingId als consumptionId
    await _db.insertConsumption(ConsumptionsCompanion.insert(
      id: consumptionId,
      buildingId: buildingId,
      electricityKWh: json.encode(consumption.electricityKWh),
      gasKWh: json.encode(consumption.gasKWh),
    ));
  }

  Future<void> updateConsumption(models.Consumption consumption, String buildingId) async {
    final consumptionId = buildingId;
    await _db.updateConsumption(
      consumptionId,
      ConsumptionsCompanion(
        electricityKWh: Value(json.encode(consumption.electricityKWh)),
        gasKWh: Value(json.encode(consumption.gasKWh)),
      ),
    );
  }

  // ========== ATTACHMENTS ==========

  Future<models.Attachments?> getAttachmentsByBuildingId(String buildingId) async {
    final row = await _db.getAttachmentsByBuildingId(buildingId);
    if (row == null) return null;

    return models.Attachments(
      photos: (json.decode(row.photos) as List<dynamic>).cast<String>(),
      plans: (json.decode(row.plans) as List<dynamic>).cast<String>(),
      notes: row.notes,
    );
  }

  Future<void> insertAttachments(models.Attachments attachments, String buildingId) async {
    final attachmentsId = buildingId;
    await _db.insertAttachments(AttachmentsTableCompanion.insert(
      id: attachmentsId,
      buildingId: buildingId,
      photos: json.encode(attachments.photos),
      plans: json.encode(attachments.plans),
      notes: attachments.notes,
    ));
  }

  Future<void> updateAttachments(models.Attachments attachments, String buildingId) async {
    final attachmentsId = buildingId;
    await _db.updateAttachments(
      attachmentsId,
      AttachmentsTableCompanion(
        photos: Value(json.encode(attachments.photos)),
        plans: Value(json.encode(attachments.plans)),
        notes: Value(attachments.notes),
      ),
    );
  }
}

