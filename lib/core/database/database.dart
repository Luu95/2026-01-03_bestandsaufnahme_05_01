/// Drift-Schema und [AppDatabase] für die Bestandsaufnahme-App.
/// Tabellen, Migrationen und CRUD; Verbindung über Conditional Imports.
import 'package:drift/drift.dart';

import 'database_connection_stub.dart'
    if (dart.library.io) 'database_connection_io.dart'
    if (dart.library.html) 'database_connection_web.dart';

part 'database.g.dart';

/// Projekte (Stammdaten inkl. Soft-Delete).
@DataClassName('ProjectDb')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get customer => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gebäude eines Projekts (Adress-/Stammdaten, Soft-Delete).
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
  /// JSON-Array der Sanierungsjahre als String.
  TextColumn get renovationYears => text()();
  BoolColumn get protectedMonument => boolean()();
  IntColumn get units => integer()();
  RealColumn get floorArea => real()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Grundrisse (PDF-Pfad/-Name) eines Gebäudes.
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

/// Anlagen und Marker inkl. Hierarchie ([parentId]) und Soft-Delete.
@DataClassName('AnlageDb')
class Anlagen extends Table {
  TextColumn get id => text()();
  /// Eltern-Anlage für Bauteile / Hierarchie.
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  /// Parameter-Map als JSON-String.
  TextColumn get params => text()();
  TextColumn get floorId => text().nullable()();
  TextColumn get buildingId => text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isMarker => boolean()();
  /// Marker-Metadaten als JSON-String.
  TextColumn get markerInfo => text().nullable()();
  TextColumn get markerType => text()();
  /// Gespeicherte Disziplin (Schema) als JSON-String.
  TextColumn get discipline => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gebäude-Anhänge (Fotos, Pläne, Notizen) als JSON-Felder.
@DataClassName('AttachmentsTableDb')
class AttachmentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get buildingId => text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  /// JSON-Array der Foto-Pfade.
  TextColumn get photos => text()();
  /// JSON-Array der Plan-Pfade.
  TextColumn get plans => text()();
  TextColumn get notes => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gewerke/Disziplinen je Gebäude (Schema in [data]).
@DataClassName('DisziplinDb')
class Disziplinen extends Table {
  TextColumn get buildingId =>
      text().references(Buildings, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  /// Serialisierte [Disziplin] (`toJson()`).
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {buildingId, label};
}

/// Projektweite Gewerkevorlagen (Import-Templates).
@DataClassName('TemplateDb')
class Templates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get gewerk => text()();
  /// `'a'` = Anlage, `'b'` = Bauteil.
  TextColumn get anlageBauteil => text()();
  TextColumn get anlagentyp => text()();
  TextColumn get bezeichnung => text()();
  TextColumn get parameter => text().nullable()();
}

/// Zentrale Drift-Datenbank mit Schema-Version und CRUD-Zugriffen.
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
  AppDatabase() : super(createConnection());

  /// Aktuelle Schema-Version (v5: Soft-Delete-Spalten).
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // parentId für hierarchische Anlagen
        await migrator.addColumn(anlagen, anlagen.parentId);
      }
      if (from < 3) {
        await migrator.createTable(disziplinen);
      }
      if (from < 4) {
        await migrator.createTable(templates);
      }
      if (from < 5) {
        // Soft-Delete für Projekte, Gebäude und Anlagen
        await migrator.addColumn(projects, projects.isDeleted);
        await migrator.addColumn(buildings, buildings.isDeleted);
        await migrator.addColumn(anlagen, anlagen.isDeleted);
      }
    },
  );

  // --- Projects ---

  /// Aktive (nicht soft-gelöschte) Projekte.
  Future<List<ProjectDb>> getAllProjects() =>
      (select(projects)..where((p) => p.isDeleted.equals(false))).get();

  /// Projekte im Papierkorb.
  Future<List<ProjectDb>> getDeletedProjects() =>
      (select(projects)..where((p) => p.isDeleted.equals(true))).get();

  Future<ProjectDb?> getProjectById(String id) =>
      (select(projects)..where((p) => p.id.equals(id) & p.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<ProjectDb?> getProjectByIdIncludingDeleted(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertProject(ProjectsCompanion project) => into(projects).insert(project);
  Future<int> updateProject(String id, ProjectsCompanion project) =>
      (update(projects)..where((p) => p.id.equals(id))).write(project);

  Future<int> softDeleteProject(String id) =>
      (update(projects)..where((p) => p.id.equals(id)))
          .write(const ProjectsCompanion(isDeleted: Value(true)));

  Future<int> restoreProject(String id) =>
      (update(projects)..where((p) => p.id.equals(id)))
          .write(const ProjectsCompanion(isDeleted: Value(false)));

  /// Endgültiges Löschen eines Projekts.
  Future<int> deleteProject(String id) => (delete(projects)..where((p) => p.id.equals(id))).go();

  // --- Buildings ---

  Future<List<BuildingDb>> getAllActiveBuildings() =>
      (select(buildings)..where((b) => b.isDeleted.equals(false))).get();

  Future<List<BuildingDb>> getBuildingsByProjectId(String projectId) =>
      (select(buildings)
            ..where((b) => b.projectId.equals(projectId) & b.isDeleted.equals(false)))
          .get();

  Future<List<BuildingDb>> getDeletedBuildings() =>
      (select(buildings)..where((b) => b.isDeleted.equals(true))).get();

  Future<List<BuildingDb>> getDeletedBuildingsByProjectId(String projectId) =>
      (select(buildings)
            ..where((b) => b.projectId.equals(projectId) & b.isDeleted.equals(true)))
          .get();

  Future<BuildingDb?> getBuildingById(String id) =>
      (select(buildings)..where((b) => b.id.equals(id) & b.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<BuildingDb?> getBuildingByIdIncludingDeleted(String id) =>
      (select(buildings)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> insertBuilding(BuildingsCompanion building) => into(buildings).insert(building);
  Future<int> updateBuilding(String id, BuildingsCompanion building) =>
      (update(buildings)..where((b) => b.id.equals(id))).write(building);

  Future<int> softDeleteBuilding(String id) =>
      (update(buildings)..where((b) => b.id.equals(id)))
          .write(const BuildingsCompanion(isDeleted: Value(true)));

  Future<int> restoreBuilding(String id) =>
      (update(buildings)..where((b) => b.id.equals(id)))
          .write(const BuildingsCompanion(isDeleted: Value(false)));

  Future<int> deleteBuilding(String id) => (delete(buildings)..where((b) => b.id.equals(id))).go();

  // --- FloorPlans ---

  Future<List<FloorPlanDb>> getAllFloorPlans() => select(floorPlans).get();

  Future<List<FloorPlanDb>> getFloorPlansByBuildingId(String buildingId) => (select(floorPlans)..where((f) => f.buildingId.equals(buildingId))).get();
  Future<FloorPlanDb?> getFloorPlanById(String id) => (select(floorPlans)..where((f) => f.id.equals(id))).getSingleOrNull();
  Future<int> insertFloorPlan(FloorPlansCompanion floorPlan) => into(floorPlans).insert(floorPlan);
  Future<int> updateFloorPlan(String id, FloorPlansCompanion floorPlan) => (update(floorPlans)..where((f) => f.id.equals(id))).write(floorPlan);
  Future<int> deleteFloorPlan(String id) => (delete(floorPlans)..where((f) => f.id.equals(id))).go();

  Future<int> deleteFloorPlansByBuildingId(String buildingId) =>
      (delete(floorPlans)..where((f) => f.buildingId.equals(buildingId))).go();

  // --- Anlagen ---

  Future<List<AnlageDb>> getAnlagenByBuildingId(String buildingId) =>
      (select(anlagen)
            ..where((a) => a.buildingId.equals(buildingId) & a.isDeleted.equals(false)))
          .get();

  Future<List<AnlageDb>> getDeletedAnlagen() =>
      (select(anlagen)..where((a) => a.isDeleted.equals(true))).get();

  Future<List<AnlageDb>> getDeletedAnlagenByBuildingId(String buildingId) =>
      (select(anlagen)
            ..where((a) => a.buildingId.equals(buildingId) & a.isDeleted.equals(true)))
          .get();

  Future<List<AnlageDb>> getAnlagenByBuildingIdAndDiscipline(String buildingId, String disciplineLabel) {
    return (select(anlagen)
          ..where((a) =>
              a.buildingId.equals(buildingId) &
              a.markerType.equals(disciplineLabel) &
              a.isDeleted.equals(false)))
        .get();
  }

  Future<AnlageDb?> getAnlageById(String id) =>
      (select(anlagen)..where((a) => a.id.equals(id) & a.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<AnlageDb?> getAnlageByIdIncludingDeleted(String id) =>
      (select(anlagen)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<AnlageDb>> getAnlagenByParentId(String parentId) =>
      (select(anlagen)
            ..where((a) => a.parentId.equals(parentId) & a.isDeleted.equals(false)))
          .get();

  Future<List<AnlageDb>> getAnlagenByParentIdIncludingDeleted(String parentId) =>
      (select(anlagen)..where((a) => a.parentId.equals(parentId))).get();
  Future<int> insertAnlage(AnlagenCompanion anlage) => into(anlagen).insert(anlage);
  Future<int> updateAnlage(String id, AnlagenCompanion anlage) => (update(anlagen)..where((a) => a.id.equals(id))).write(anlage);

  /// Setzt [markerType] und Disziplin-JSON bei Umbenennung eines Gewerks.
  Future<void> updateAnlagenDiscipline(String buildingId, String oldLabel, String newLabel, String newDisciplineJson) async {
    await (update(anlagen)
      ..where((a) => a.buildingId.equals(buildingId) & a.markerType.equals(oldLabel)))
      .write(AnlagenCompanion(
        markerType: Value(newLabel),
        discipline: Value(newDisciplineJson),
      ));
  }

  Future<int> softDeleteAnlage(String id) =>
      (update(anlagen)..where((a) => a.id.equals(id)))
          .write(const AnlagenCompanion(isDeleted: Value(true)));

  Future<int> restoreAnlage(String id) =>
      (update(anlagen)..where((a) => a.id.equals(id)))
          .write(const AnlagenCompanion(isDeleted: Value(false)));

  Future<int> deleteAnlage(String id) => (delete(anlagen)..where((a) => a.id.equals(id))).go();
  Future<int> deleteAnlagenByBuildingId(String buildingId) => (delete(anlagen)..where((a) => a.buildingId.equals(buildingId))).go();

  // --- Attachments ---

  Future<AttachmentsTableDb?> getAttachmentsByBuildingId(String buildingId) => (select(attachmentsTable)..where((a) => a.buildingId.equals(buildingId))).getSingleOrNull();
  Future<int> insertAttachments(AttachmentsTableCompanion attachments) => into(attachmentsTable).insert(attachments);
  Future<int> updateAttachments(String id, AttachmentsTableCompanion attachments) => (update(attachmentsTable)..where((a) => a.id.equals(id))).write(attachments);
  Future<int> deleteAttachments(String id) => (delete(attachmentsTable)..where((a) => a.id.equals(id))).go();

  Future<int> deleteAttachmentsByBuildingId(String buildingId) =>
      (delete(attachmentsTable)..where((a) => a.buildingId.equals(buildingId))).go();

  // --- Disziplinen ---

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

  // --- Templates ---

  Future<List<TemplateDb>> getTemplatesByProjectId(String projectId) =>
      (select(templates)..where((t) => t.projectId.equals(projectId))).get();

  Future<List<TemplateDb>> getTemplatesByProjectIdAndGewerk(String projectId, String gewerk) =>
      (select(templates)
            ..where((t) => t.projectId.equals(projectId) & t.gewerk.equals(gewerk)))
          .get();

  /// Nur Gewerk-Namen (ohne `parameter`-Blobs) – für schnelle Placement-Auswahl.
  Future<List<String>> getDistinctTemplateGewerke(String projectId) async {
    final rows = await (selectOnly(templates)
          ..addColumns([templates.gewerk])
          ..where(templates.projectId.equals(projectId))
          ..groupBy([templates.gewerk]))
        .get();
    final labels = <String>{};
    for (final row in rows) {
      final g = row.read(templates.gewerk)?.trim() ?? '';
      if (g.isNotEmpty) labels.add(g);
    }
    final list = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Nur Anlagentypen eines Gewerks (ohne `parameter`-Blobs).
  Future<List<String>> getDistinctTemplateAnlagentypen(
    String projectId,
    String gewerk,
  ) async {
    final g = gewerk.trim();
    if (g.isEmpty) return const [];
    final rows = await (selectOnly(templates)
          ..addColumns([templates.anlagentyp])
          ..where(
            templates.projectId.equals(projectId) & templates.gewerk.equals(g),
          )
          ..groupBy([templates.anlagentyp]))
        .get();
    final types = <String>{};
    for (final row in rows) {
      final t = row.read(templates.anlagentyp)?.trim() ?? '';
      if (t.isNotEmpty) types.add(t);
    }
    final list = types.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Ob das Projekt mindestens eine Gewerkevorlage hat (ohne Zeilen zu laden).
  Future<bool> hasTemplatesForProject(String projectId) async {
    final row = await (selectOnly(templates)
          ..addColumns([templates.id])
          ..where(templates.projectId.equals(projectId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<int> insertTemplate(TemplatesCompanion template) => into(templates).insert(template);

  Future<int> deleteTemplatesByProjectId(String projectId) =>
      (delete(templates)..where((t) => t.projectId.equals(projectId))).go();
}
