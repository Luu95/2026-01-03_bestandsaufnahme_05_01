// lib/database/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Tabellen-Definitionen
@DataClassName('ProjectDb')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get customer => text()();

  @override
  Set<Column> get primaryKey => {id};
}
@DataClassName('BuildingDb')
class Buildings extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get address => text()();
  TextColumn get postalCode => text()();
  TextColumn get city => text()();
  TextColumn get type => text()();
  RealColumn get bgf => real()();
  IntColumn get constructionYear => integer()();
  TextColumn get renovationYears => text()(); // JSON-Array als String
  BoolColumn get protectedMonument => boolean()();
  IntColumn get units => integer()();
  RealColumn get floorArea => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FloorPlanDb')
class FloorPlans extends Table {
  TextColumn get id => text()();
  TextColumn get buildingId => text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get pdfPath => text().nullable()();
  TextColumn get pdfName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnlageDb')
class Anlagen extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()(); // Für hierarchische Anlagen
  TextColumn get name => text()();
  TextColumn get params => text()(); // JSON als String
  TextColumn get floorId => text().nullable()();
  TextColumn get buildingId => text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isMarker => boolean()();
  TextColumn get markerInfo => text().nullable()(); // JSON als String
  TextColumn get markerType => text()();
  TextColumn get discipline => text()(); // JSON als String

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AttachmentsTableDb')
class AttachmentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get buildingId => text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  TextColumn get photos => text()(); // JSON-Array als String
  TextColumn get plans => text()(); // JSON-Array als String
  TextColumn get notes => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DisziplinDb')
class Disziplinen extends Table {
  TextColumn get buildingId =>
      text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  TextColumn get data => text()(); // JSON als String (Disziplin.toJson())

  @override
  Set<Column> get primaryKey => {buildingId, label};
}

@DataClassName('TemplateDb')
class Templates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get gewerk => text()();
  TextColumn get anlageBauteil => text()(); // 'a' oder 'b'
  TextColumn get anlagentyp => text()();
  TextColumn get bezeichnung => text()();
  TextColumn get parameter => text().nullable()();
}

@DriftDatabase(tables: [
  Projects,
  Buildings,
  FloorPlans,
  Anlagen,
  AttachmentsTable,
  Disziplinen,
  Templates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4; // v2: parentId, v3: disziplinen, v4: templates

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Migration von Version 1 zu 2: parentId-Spalte zur Anlagen-Tabelle hinzufügen
        await migrator.addColumn(anlagen, anlagen.parentId);
      }
      if (from < 3) {
        // Migration von Version 2 zu 3: Disziplinen-Tabelle hinzufügen
        await migrator.createTable(disziplinen);
      }
      if (from < 4) {
        // Migration von Version 3 zu 4: Templates-Tabelle hinzufügen
        await migrator.createTable(templates);
      }
    },
  );

  // CRUD-Methoden für Projects
  Future<List<ProjectDb>> getAllProjects() => select(projects).get();
  Future<ProjectDb?> getProjectById(String id) => (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<int> insertProject(ProjectsCompanion project) => into(projects).insert(project);
  Future<int> updateProject(String id, ProjectsCompanion project) => (update(projects)..where((p) => p.id.equals(id))).write(project);
  Future<int> deleteProject(String id) => (delete(projects)..where((p) => p.id.equals(id))).go();

  // CRUD-Methoden für Buildings
  Future<List<BuildingDb>> getBuildingsByProjectId(String projectId) => (select(buildings)..where((b) => b.projectId.equals(projectId))).get();
  Future<BuildingDb?> getBuildingById(String id) => (select(buildings)..where((b) => b.id.equals(id))).getSingleOrNull();
  Future<int> insertBuilding(BuildingsCompanion building) => into(buildings).insert(building);
  Future<int> updateBuilding(String id, BuildingsCompanion building) => (update(buildings)..where((b) => b.id.equals(id))).write(building);
  Future<int> deleteBuilding(String id) => (delete(buildings)..where((b) => b.id.equals(id))).go();

  // CRUD-Methoden für FloorPlans
  Future<List<FloorPlanDb>> getFloorPlansByBuildingId(String buildingId) => (select(floorPlans)..where((f) => f.buildingId.equals(buildingId))).get();
  Future<FloorPlanDb?> getFloorPlanById(String id) => (select(floorPlans)..where((f) => f.id.equals(id))).getSingleOrNull();
  Future<int> insertFloorPlan(FloorPlansCompanion floorPlan) => into(floorPlans).insert(floorPlan);
  Future<int> updateFloorPlan(String id, FloorPlansCompanion floorPlan) => (update(floorPlans)..where((f) => f.id.equals(id))).write(floorPlan);
  Future<int> deleteFloorPlan(String id) => (delete(floorPlans)..where((f) => f.id.equals(id))).go();

  // CRUD-Methoden für Anlagen
  Future<List<AnlageDb>> getAnlagenByBuildingId(String buildingId) => (select(anlagen)..where((a) => a.buildingId.equals(buildingId))).get();
  Future<List<AnlageDb>> getAnlagenByBuildingIdAndDiscipline(String buildingId, String disciplineLabel) {
    return (select(anlagen)..where((a) => a.buildingId.equals(buildingId) & a.markerType.equals(disciplineLabel))).get();
  }
  Future<AnlageDb?> getAnlageById(String id) => (select(anlagen)..where((a) => a.id.equals(id))).getSingleOrNull();
  Future<List<AnlageDb>> getAnlagenByParentId(String parentId) => (select(anlagen)..where((a) => a.parentId.equals(parentId))).get();
  Future<int> insertAnlage(AnlagenCompanion anlage) => into(anlagen).insert(anlage);
  Future<int> updateAnlage(String id, AnlagenCompanion anlage) => (update(anlagen)..where((a) => a.id.equals(id))).write(anlage);
  
  /// Aktualisiert alle Anlagen einer Disziplin, wenn diese umbenannt wurde.
  Future<void> updateAnlagenDiscipline(String buildingId, String oldLabel, String newLabel, String newDisciplineJson) async {
    await (update(anlagen)
      ..where((a) => a.buildingId.equals(buildingId) & a.markerType.equals(oldLabel)))
      .write(AnlagenCompanion(
        markerType: Value(newLabel),
        discipline: Value(newDisciplineJson),
      ));
  }

  Future<int> deleteAnlage(String id) => (delete(anlagen)..where((a) => a.id.equals(id))).go();
  Future<int> deleteAnlagenByBuildingId(String buildingId) => (delete(anlagen)..where((a) => a.buildingId.equals(buildingId))).go();

  // CRUD-Methoden für Attachments
  Future<AttachmentsTableDb?> getAttachmentsByBuildingId(String buildingId) => (select(attachmentsTable)..where((a) => a.buildingId.equals(buildingId))).getSingleOrNull();
  Future<int> insertAttachments(AttachmentsTableCompanion attachments) => into(attachmentsTable).insert(attachments);
  Future<int> updateAttachments(String id, AttachmentsTableCompanion attachments) => (update(attachmentsTable)..where((a) => a.id.equals(id))).write(attachments);
  Future<int> deleteAttachments(String id) => (delete(attachmentsTable)..where((a) => a.id.equals(id))).go();

  // CRUD-Methoden für Disziplinen
  Future<List<DisziplinDb>> getDisziplinenByBuildingId(String buildingId) =>
      (select(disziplinen)..where((d) => d.buildingId.equals(buildingId))).get();

  Future<int> upsertDisziplin(DisziplinenCompanion entry) =>
      into(disziplinen).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteDisziplin(String buildingId, String label) =>
      (delete(disziplinen)
            ..where((d) => d.buildingId.equals(buildingId) & d.label.equals(label)))
          .go();

  Future<int> deleteDisziplinenByBuildingId(String buildingId) =>
      (delete(disziplinen)..where((d) => d.buildingId.equals(buildingId))).go();

  // CRUD-Methoden für Templates
  Future<List<TemplateDb>> getTemplatesByProjectId(String projectId) =>
      (select(templates)..where((t) => t.projectId.equals(projectId))).get();

  Future<List<TemplateDb>> getTemplatesByProjectIdAndGewerk(String projectId, String gewerk) =>
      (select(templates)
            ..where((t) => t.projectId.equals(projectId) & t.gewerk.equals(gewerk)))
          .get();

  Future<int> insertTemplate(TemplatesCompanion template) => into(templates).insert(template);

  Future<int> deleteTemplatesByProjectId(String projectId) =>
      (delete(templates)..where((t) => t.projectId.equals(projectId))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bestandsaufnahme.db'));
    return NativeDatabase(file);
  });
}

