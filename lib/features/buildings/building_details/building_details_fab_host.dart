/// AppBar-Aktionen und kontextabhängiger FAB der Gebäude-Seite.
///
/// Wechselt je nach Tab und Selection-Mode zwischen Upload, Hinzufügen
/// und Bulk-Aktionen (Löschen, Verschieben, …).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/buildings/widgets/building_details_fab.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/systems_list_tile_styles.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_anlage_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_floor_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_selection_actions.dart';

/// AppBar-Actions + FAB der Gebäude-Seite (Abschnitt 6).
mixin BuildingDetailsFabHost<T extends ConsumerStatefulWidget>
    on ConsumerState<T>,
        BuildingDetailsAnlageActions<T>,
        BuildingDetailsSelectionActions<T>,
        BuildingDetailsFloorActions<T> {
  TabController get mainTabController;
  Project get fabProject;

  String? get listViewGroupingKey;
  set listViewGroupingKey(String? value);
  List<String> get listViewParamKeys;
  set technikTabKey(Key value);

  static const listViewStandardGroupingValue = '__standard__';

  List<Widget> buildListViewAppBarActions({
    required bool inSelectionMode,
    required bool isTechnikTab,
    required Color onSurface,
  }) {
    if (inSelectionMode) return const [];
    if (!isTechnikTab || listViewParamKeys.isEmpty) return const [];

    final current = listViewGroupingKey;
    final isCustom =
        current != null && listViewParamKeys.contains(current);

    return [
      PopupMenuButton<String>(
        tooltip: 'Auflisten nach',
        offset: const Offset(0, 40),
        icon: Icon(
          Icons.sort,
          color: isCustom ? AppPalette.primary : onSurface.withOpacity(0.75),
        ),
        onSelected: (key) {
          setState(() {
            listViewGroupingKey =
                key == listViewStandardGroupingValue ? null : key;
            technikTabKey = UniqueKey();
          });
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem<String>(
            value: listViewStandardGroupingValue,
            checked: !isCustom,
            child: const Text('Standard (Hierarchie)'),
          ),
          const PopupMenuDivider(),
          for (final key in listViewParamKeys)
            CheckedPopupMenuItem<String>(
              value: key,
              checked: current == key,
              child: Text(key),
            ),
        ],
      ),
    ];
  }

  Widget? buildSelectionAwareFab() {
    final inSelectionMode = isFloorSelectionMode ||
        systemsSelectionMode ||
        disciplineSelectionMode ||
        groupSelectionMode;
    final inFloorplansSelection =
        isFloorSelectionMode && mainTabController.index == 0;
    final inSystemsSelection =
        systemsSelectionMode && mainTabController.index == 1;
    final inDisciplineSelection =
        disciplineSelectionMode && mainTabController.index == 1;
    final inGroupSelection =
        groupSelectionMode && mainTabController.index == 1;

    if (mainTabController.index == 0 && !inSelectionMode) {
      return FloatingActionButton(
        onPressed: addNewFloorAndUpload,
        tooltip: 'Grundriss hochladen',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.download, color: Colors.white),
      );
    }

    if (mainTabController.index == 1 && !inSelectionMode) {
      final leafLabel = fabProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(fabProject.id)).resolveLeafLevelLabel()
          : 'Anlage';
      return FloatingActionButton(
        onPressed: () async {
          await ensureDisciplinesFromTemplatesIfNeeded();
          if (!mounted) return;
          final discipline = await resolveDisciplineForAddOrMaterialize();
          if (discipline == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hasProjectTemplates
                      ? 'Bitte ein Gewerk aus den Vorlagen wählen oder $leafLabel per CSV importieren.'
                      : 'Bitte zuerst Gewerkevorlagen unter CSV-Import importieren '
                          'oder $leafLabel per CSV importieren.',
                ),
              ),
            );
            return;
          }
          await openAddAnlageWithPlacement(discipline);
        },
        tooltip: '$leafLabel hinzufügen',
        backgroundColor: SystemsOverviewPalette.primary,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }

    if (!inSelectionMode) return null;

    final List<Widget> buttons = [];

    if (inGroupSelection) {
      final ctx = groupSelectionContext;
      if (ctx != null && ctx.isSchemaItemLevel) {
        var leafLabel = 'Eintrag';
        if (fabProject.id.isNotEmpty) {
          final csv = ref.read(csvSettingsProvider(fabProject.id));
          leafLabel = csv.resolveDatensatzUnderRevisionsobjektLabel();
        }
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.add,
            tooltip: '$leafLabel hinzufügen',
            onPressed: openAddAnlageForGroupContext,
            backgroundColor: SystemsOverviewPalette.primary,
          ),
        );
      }
    } else if (inDisciplineSelection) {
      if (selectedDisciplineLabels.length == 1) {
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.edit,
            tooltip: 'Gewerk bearbeiten',
            onPressed: editSelectedDiscipline,
            backgroundColor: SystemsOverviewPalette.primaryLight,
          ),
        );
        final leafLabel = fabProject.id.isNotEmpty
            ? ref
                .read(csvSettingsProvider(fabProject.id))
                .resolveLeafLevelLabel()
            : 'Anlage';
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.add,
            tooltip: '$leafLabel hinzufügen',
            onPressed: () async {
              final d = getSingleSelectedDiscipline();
              if (d != null) {
                await openAddAnlageWithPlacement(d);
              }
            },
            backgroundColor: SystemsOverviewPalette.primary,
          ),
        );
      }
      buttons.add(
        BuildingDetailsFab(
          icon: Icons.delete_outline,
          tooltip: 'Gewerk löschen',
          onPressed: deleteSelectedDiscipline,
          backgroundColor: SystemsOverviewPalette.primaryDark,
        ),
      );
    } else if (inSystemsSelection) {
      if (activeSelections.keys.length == 1) {
        final activeLabel = activeSelections.keys.first;
        bool hasOnlyBauteile = false;

        try {
          final discipline = systemsPageKeys.keys.firstWhere(
            (d) => d.label == activeLabel,
          );
          hasOnlyBauteile = systemsPageKeys[discipline]
                  ?.currentState
                  ?.hasOnlyBauteileSelected() ??
              false;
        } catch (_) {}

        final csvSettings = fabProject.id.isNotEmpty
            ? ref.read(csvSettingsProvider(fabProject.id))
            : null;
        final showChildAdd = csvSettings?.allowsParentChildRows ?? false;
        if (showChildAdd && !hasOnlyBauteile) {
          final childLabel = csvSettings!.labelBauteil;
          buttons.add(
            BuildingDetailsFab(
              icon: Icons.add,
              tooltip: '$childLabel hinzufügen',
              onPressed: openBulkAddBauteilForSystemsSelection,
              backgroundColor: SystemsOverviewPalette.primary,
            ),
          );
        }
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.drive_file_move,
            tooltip: 'Verschieben',
            onPressed: openMoveDialogForSystemsSelection,
            backgroundColor: SystemsOverviewPalette.primaryMuted,
          ),
        );
      }
      buttons.add(
        BuildingDetailsFab(
          icon: Icons.delete_outline,
          tooltip: () {
            if (fabProject.id.isEmpty) {
              return 'Ausgewählte Einträge löschen';
            }
            final label = ref
                .read(csvSettingsProvider(fabProject.id))
                .pluralLeafLevelLabel(2);
            return 'Ausgewählte $label löschen';
          }(),
          onPressed: handleDeleteSelectedAnlagen,
          backgroundColor: SystemsOverviewPalette.primaryDark,
        ),
      );
    } else if (inFloorplansSelection) {
      buttons.add(
        BuildingDetailsFab(
          icon: Icons.delete_outline,
          tooltip: 'Ausgewählte Grundrisse löschen',
          onPressed: handleDeleteSelectedFloors,
          backgroundColor: SystemsOverviewPalette.primaryDark,
        ),
      );
    }

    if (buttons.isEmpty) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons.reversed.toList(),
    );
  }

  Widget buildBottomTab({
    required IconData icon,
    required String text,
    required int index,
  }) {
    final isSelected = mainTabController.index == index;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Tab(
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: isSelected ? surfaceColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
