/// Anlagen hinzufügen und Placement auf der Gebäude-Seite.
///
/// Als Mixin an `_BuildingDetailsPageState`, damit Dialoge auf `context`/`ref`
/// zugreifen können, ohne die Page-Datei weiter aufzublähen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/anlage_dialog/open_add_anlage_with_template_prefill.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/move_anlagen_dialog.dart';

/// Anlagen hinzufügen / Placement (Abschnitt 4 der Gebäude-Seite).
mixin BuildingDetailsAnlageActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Building get anlageBuilding;
  Project get anlageProject;
  List<Disziplin> get anlageDisciplines;
  Disziplin? get lastExpandedDiscipline;
  bool get hasProjectTemplates;
  ({
    Disziplin discipline,
    String groupKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
    bool isSchemaItemLevel,
  })? get groupSelectionContext;
  set groupSelectionContext(
    ({
      Disziplin discipline,
      String groupKey,
      String groupValue,
      Map<String, dynamic> additionalParams,
      bool isSchemaItemLevel,
    })? value,
  );

  String? resolveHierarchyGroupingParamKey();
  String? resolveHierarchySubGroupingParamKey();

  Future<void> reloadDisciplinesForAnlage({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  });
  Future<void> saveNewAnlageFromDialog(Anlage newAnlage);

  Future<AnlagePlacementResult?> pickPlacementForDiscipline(
    Disziplin discipline, {
    String? initialRevisionsfeld,
    String? initialRevisionsobjekt,
    Map<String, dynamic>? mergeExtraParams,
  }) async {
    // Immer Hierarchie-Keys – nicht die Listen-Gruppierung (z. B. Baujahr),
    // sonst entfällt die Revisionsobjekt-Wahl und das Eingabe-Schema bleibt leer.
    final subKey = resolveHierarchySubGroupingParamKey();
    if (subKey == null || subKey.isEmpty) {
      return AnlagePlacementResult(
        discipline: discipline,
        initialParams: Map<String, dynamic>.from(mergeExtraParams ?? {}),
      );
    }

    if (anlageProject.id.isEmpty) {
      return AnlagePlacementResult(
        discipline: discipline,
        initialParams: Map<String, dynamic>.from(mergeExtraParams ?? {}),
      );
    }

    await ref.read(csvSettingsProvider(anlageProject.id).notifier).load();

    final picked = await showModalBottomSheet<AnlagePlacementResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MoveAnlagenDialog.forPlacement(
        discipline: discipline,
        buildingId: anlageBuilding.id,
        floorId: 'global',
        projectId: anlageProject.id,
        revisionsfeldGroupingKey: resolveHierarchyGroupingParamKey(),
        revisionsobjektGroupingKey: subKey,
        initialRevisionsfeld: initialRevisionsfeld,
        initialRevisionsobjekt: initialRevisionsobjekt,
      ),
    );
    if (picked == null) return null;

    final merged = Map<String, dynamic>.from(picked.initialParams);
    if (mergeExtraParams != null) {
      merged.addAll(mergeExtraParams);
    }
    return AnlagePlacementResult(
      discipline: picked.discipline,
      initialParams: merged,
    );
  }

  Disziplin resolveDisciplineForAdd() {
    if (anlageDisciplines.isEmpty) {
      throw StateError('Keine Disziplinen vorhanden');
    }
    return anlageDisciplines.length == 1
        ? anlageDisciplines.first
        : (lastExpandedDiscipline ?? anlageDisciplines.first);
  }

  Future<void> ensureDisciplinesFromTemplatesIfNeeded() async {
    if (anlageProject.id.isEmpty) return;
    final dbService = ref.read(databaseServiceProvider);
    final templates =
        await dbService.getTemplatesByProjectId(anlageProject.id);
    if (templates.isEmpty) return;
    // Nur Schemata in bestehende Disziplinen mergen – keine leeren Shells.
    final existing =
        await dbService.getDisciplinesByBuildingId(anlageBuilding.id);
    if (existing.isEmpty) return;
    await TemplateService.ensureDisciplinesFromTemplates(
      dbService,
      anlageBuilding.id,
      anlageProject.id,
    );
    await reloadDisciplinesForAnlage(refreshSystemsPages: true);
  }

  /// Plus: Start-Disziplin für den Platzierungsdialog (Gewerk + Ebene 2).
  Future<Disziplin?> resolveDisciplineForAddOrMaterialize() async {
    if (anlageDisciplines.isNotEmpty) {
      return resolveDisciplineForAdd();
    }
    if (anlageProject.id.isEmpty || !hasProjectTemplates) {
      return null;
    }
    final dbService = ref.read(databaseServiceProvider);
    final templateRows =
        await dbService.getTemplatesByProjectId(anlageProject.id);
    if (templateRows.isEmpty || !mounted) return null;

    final virtual =
        TemplateService.buildVirtualDisciplinesFromTemplateRows(templateRows);
    if (virtual.isEmpty) return null;
    return virtual.first;
  }

  Future<void> openAnlageErfassungAfterPlacement({
    required Disziplin discipline,
    required Map<String, dynamic> placementParams,
  }) async {
    await openAddAnlageWithTemplatePrefill(
      context: context,
      ref: ref,
      discipline: discipline,
      placementParams: placementParams,
      buildingId: anlageBuilding.id,
      floorId: 'global',
      projectId: anlageProject.id,
      createChildBauteile: true,
      persistParentInHelper: true,
      isMounted: () => mounted,
      onSaved: saveNewAnlageFromDialog,
    );
  }

  Future<void> openAddAnlageWithPlacement(
    Disziplin discipline, {
    Map<String, dynamic>? prefilledParams,
    String? initialRevisionsfeld,
    String? initialRevisionsobjekt,
  }) async {
    final placement = await pickPlacementForDiscipline(
      discipline,
      initialRevisionsfeld: initialRevisionsfeld,
      initialRevisionsobjekt: initialRevisionsobjekt,
      mergeExtraParams: prefilledParams,
    );
    if (placement == null || !mounted) return;

    await reloadDisciplinesForAnlage(refreshSystemsPages: true);
    if (!mounted) return;

    await openAnlageErfassungAfterPlacement(
      discipline: placement.discipline,
      placementParams: placement.initialParams,
    );
  }

  Future<void> openAddAnlageForGroupContext() async {
    final ctx = groupSelectionContext;
    if (ctx == null || !ctx.isSchemaItemLevel) return;

    final roValue = ctx.groupValue.trim();
    if (roValue.isEmpty) return;

    await ref.read(csvSettingsProvider(anlageProject.id).notifier).load();
    final csvSettings = ref.read(csvSettingsProvider(anlageProject.id));

    final additionalParams = Map<String, dynamic>.from(ctx.additionalParams)
      ..remove('__schemaOverride')
      ..remove('__sampleAnlageId');

    String? initialRf;
    final rfKey = csvSettings.resolveRevisionsfeldListGroupingParamKey();
    if (rfKey != null && rfKey.isNotEmpty) {
      initialRf = additionalParams.remove(rfKey)?.toString().trim();
    }

    final dbService = ref.read(databaseServiceProvider);
    Disziplin discipline = ctx.discipline;
    try {
      final disciplines =
          await dbService.getDisciplinesByBuildingId(anlageBuilding.id);
      discipline = disciplines.firstWhere(
        (d) => d.label == ctx.discipline.label,
        orElse: () => ctx.discipline,
      );
    } catch (e) {
      appLog('Disziplinen für Gebäude konnten nicht geladen werden', error: e);
    }

    await openAddAnlageWithPlacement(
      discipline,
      prefilledParams: additionalParams,
      initialRevisionsfeld: initialRf,
      initialRevisionsobjekt: roValue,
    );
  }
}
