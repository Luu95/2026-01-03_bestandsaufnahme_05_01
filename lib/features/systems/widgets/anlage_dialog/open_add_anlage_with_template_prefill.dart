/// Gemeinsame Erfassung nach Placement: Template-Match, Prefill und Dialog.
///
/// Früher fast identisch in Gebäude- und Systems-Page; Call-Sites liefern
/// IDs, Placement-Params und [onSaved].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/generic_anlage_dialog.dart';

/// Öffnet [GenericAnlageDialog] mit Template-Prefill (falls Projekt vorhanden).
Future<void> openAddAnlageWithTemplatePrefill({
  required BuildContext context,
  required WidgetRef ref,
  required Disziplin discipline,
  required Map<String, dynamic> placementParams,
  required String buildingId,
  required String floorId,
  required String? projectId,
  required Future<void> Function(Anlage newAnlage) onSaved,
  /// true = Helper schreibt Parent (+ ggf. Kinder) in die DB.
  /// false = Caller persistiert selbst (z. B. SystemsPage-Batch).
  bool persistParentInHelper = true,
  bool createChildBauteile = false,
  bool Function()? isMounted,
}) async {
  bool stillMounted() => isMounted?.call() ?? context.mounted;

  if (projectId == null || projectId.isEmpty) {
    if (!stillMounted()) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: discipline,
        buildingId: buildingId,
        floorId: floorId,
        existingAnlage: null,
        index: null,
        initialParams:
            placementParams.isNotEmpty ? placementParams : null,
        onSave: (newAnlage, _) async {
          if (persistParentInHelper) {
            final dbService = ref.read(databaseServiceProvider);
            await dbService.insertAnlage(newAnlage);
          }
          await onSaved(newAnlage);
        },
      ),
    );
    return;
  }

  await ref.read(csvSettingsProvider(projectId).notifier).load();
  final csvSettings = ref.read(csvSettingsProvider(projectId));
  final params = Map<String, dynamic>.from(placementParams);
  final ro = (csvSettings.revisionsobjektValueFromParams(params) ??
          csvSettings.schemaItemValueFromParams(params) ??
          '')
      .trim();

  final dbService = ref.read(databaseServiceProvider);
  var gewerkTemplates = await TemplateService.loadTemplatesFromDatabase(
    dbService,
    projectId,
    gewerk: discipline.label,
  );

  var matched = ro.isNotEmpty && gewerkTemplates.isNotEmpty
      ? TemplateService.findTemplateForRevisionsobjekt(gewerkTemplates, ro)
      : null;
  if (ro.isNotEmpty && matched == null) {
    final allTemplates = await TemplateService.loadTemplatesFromDatabase(
      dbService,
      projectId,
    );
    matched = TemplateService.findTemplateForRevisionsobjekt(allTemplates, ro);
    if (matched != null) {
      gewerkTemplates = [matched, ...gewerkTemplates];
    } else if (gewerkTemplates.isEmpty) {
      gewerkTemplates = allTemplates;
    }
  }

  final schemaRo = ro.isNotEmpty
      ? (TemplateService.resolveRevisionsobjektKeyForValue(
            discipline,
            ro,
            templates: gewerkTemplates,
          ) ??
          matched?.anlagentyp.trim() ??
          ro)
      : '';

  final parentTemplate = matched ??
      Template(
        gewerk: discipline.label,
        anlageBauteil: '',
        anlagentyp: schemaRo.isNotEmpty ? schemaRo : 'Neu',
        bezeichnung: schemaRo.isNotEmpty ? schemaRo : 'Neu',
      );

  final childTemplates = createChildBauteile && schemaRo.isNotEmpty
      ? gewerkTemplates
          .where((t) =>
              t.anlagentyp.trim() == schemaRo && t.anlageBauteil == 'b')
          .toList()
      : <Template>[];

  final selectedAnlagentyp = schemaRo.isNotEmpty ? schemaRo : ro;
  final effectiveDiscipline = selectedAnlagentyp.trim().isNotEmpty
      ? TemplateService.disciplineWithSchemaForRevisionsobjekt(
          discipline: discipline,
          revisionsobjekt: selectedAnlagentyp.trim(),
          template: parentTemplate,
          templatesForLookup: gewerkTemplates,
          importHeaders: csvSettings.importHeaderRow,
        )
      : discipline;

  final formParams = TemplateService.buildInitialParamsForSchemaItem(
    parentTemplate: parentTemplate,
    selectedAnlagentyp: selectedAnlagentyp,
    schemaItemParamKey: csvSettings.resolveSchemaItemParamKey(),
  );
  formParams.addAll(params);

  final initialName = csvSettings.displayNameValueFromParams(formParams) ?? '';
  const uuid = Uuid();

  if (!stillMounted()) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => GenericAnlageDialog(
      discipline: effectiveDiscipline,
      buildingId: buildingId,
      floorId: floorId,
      initialParams: formParams,
      initialName: initialName.isNotEmpty ? initialName : null,
      initialRevisionsobjekt:
          selectedAnlagentyp.trim().isNotEmpty ? selectedAnlagentyp.trim() : null,
      onSave: (newAnlage, _) async {
        final db = ref.read(databaseServiceProvider);
        if (persistParentInHelper) {
          final existing = await db.getAnlageById(newAnlage.id);
          if (existing != null) {
            await db.updateAnlage(newAnlage);
          } else {
            await db.insertAnlage(newAnlage);
          }
        }

        if (createChildBauteile) {
          for (final t in childTemplates) {
            final childName = t.bezeichnung.trim().isNotEmpty
                ? t.bezeichnung.trim()
                : t.anlagentyp.trim();
            await db.insertAnlage(
              Anlage(
                id: uuid.v4(),
                parentId: newAnlage.id,
                name: childName,
                params:
                    TemplateService.buildEmptyParamsFromTemplate(t.parameter),
                floorId: floorId,
                buildingId: buildingId,
                isMarker: false,
                markerInfo: null,
                markerType: discipline.label,
                discipline: effectiveDiscipline.withEffectiveSchema(
                  revisionsobjekt: t.anlagentyp.trim(),
                ),
              ),
            );
          }
        }

        await onSaved(newAnlage);
      },
    ),
  );
}
