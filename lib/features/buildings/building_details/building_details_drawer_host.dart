/// Drawer-Host: Projekte/Gebäude anlegen, Selection und Settings-Navigation.
///
/// Mixin für `_BuildingDetailsPageState`; baut [BuildingDetailsDrawer] und
/// kapselt Dialoge/Navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/pages/app_settings_page.dart';
import 'package:bestandsaufnahme_01/features/csv/pages/csv_settings_page.dart';
import 'package:bestandsaufnahme_01/features/recycle_bin/pages/recycle_bin_page.dart';
import 'package:bestandsaufnahme_01/shared/widgets/confirm_delete_dialog.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_drawer.dart';

/// Drawer-Host: Projekte/Gebäude anlegen, Selection, Settings-Navigation.
mixin BuildingDetailsDrawerHost<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Project get drawerProject;
  set drawerProject(Project value);
  Building get drawerBuilding;
  set drawerBuilding(Building value);
  int get drawerProjectIndex;
  set drawerProjectIndex(int value);
  int get drawerBuildingIndex;
  set drawerBuildingIndex(int value);

  bool get projectSelectionMode;
  set projectSelectionMode(bool value);
  Set<int> get selectedProjectIndexes;
  bool get buildingSelectionMode;
  set buildingSelectionMode(bool value);
  Set<int> get selectedBuildingIndexes;

  AnimationController get drawerIconController;
  Animation<double> get drawerIconAnimation;

  VoidCallback get onImportCsv;
  VoidCallback get onExportCsv;

  void showProviderError(Object e);
  Future<void> reloadDisciplinesForDrawer({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  });
  Future<void> onBuildingSwitched();

  void showAddProjectDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Projekt erstellen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name des Projekts'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final neueId = DateTime.now().millisecondsSinceEpoch.toString();
        final newProject = Project(
          id: neueId,
          name: nameController.text.trim(),
          description: '',
          customer: '',
          buildings: [],
        );

        await ref.read(projectsProvider.notifier).addProject(newProject);
        final projectsState = ref.read(projectsProvider);
        if (projectsState.projects.length == 1) {
          ref.read(projectsProvider.notifier).selectProject(0);
        }
      } catch (e) {
        showProviderError(e);
      }
    }
  }

  void showAddBuildingDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Gebäude erstellen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name des Gebäudes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final neueId = DateTime.now().millisecondsSinceEpoch.toString();
        final neuesBuilding = Building(
          id: neueId,
          name: nameController.text.trim(),
          address: '',
          postalCode: '',
          city: '',
          type: '',
          bgf: 0.0,
          constructionYear: 0,
          renovationYears: <int>[],
          protectedMonument: false,
          units: 0,
          floorArea: 0.0,
          floors: <FloorPlan>[],
        );

        await ref.read(projectsProvider.notifier).addBuilding(neuesBuilding);
      } catch (e) {
        showProviderError(e);
      }
    }
  }

  Future<void> deleteSelectedBuildingsInDrawer() async {
    if (selectedBuildingIndexes.isEmpty) return;

    final toDelete = selectedBuildingIndexes.toList()
      ..sort((a, b) => b.compareTo(a));
    final buildingsToDelete = toDelete
        .where((idx) => idx >= 0 && idx < drawerProject.buildings.length)
        .map((idx) => drawerProject.buildings[idx])
        .toList();

    for (final building in buildingsToDelete) {
      final confirmed = await showConfirmDeleteDialog(
        context,
        itemType: 'Gebäude',
        itemName: building.name,
      );
      if (!confirmed) return;
    }

    try {
      await ref.read(projectsProvider.notifier).deleteBuildings(toDelete);
    } catch (e) {
      showProviderError(e);
      return;
    }

    setState(() {
      buildingSelectionMode = false;
      selectedBuildingIndexes.clear();
    });
  }

  void openRecycleBin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecycleBinPage()),
    );
  }

  Future<void> deleteSelectedProjects() async {
    if (selectedProjectIndexes.isEmpty) return;

    final projects = ref.read(projectsProvider).projects;
    final toDelete = selectedProjectIndexes.toList()
      ..sort((a, b) => b.compareTo(a));
    final projectsToDelete = toDelete
        .where((idx) => idx >= 0 && idx < projects.length)
        .map((idx) => projects[idx])
        .toList();

    for (final project in projectsToDelete) {
      final confirmed = await showConfirmDeleteDialog(
        context,
        itemType: 'Projekt',
        itemName: project.name,
      );
      if (!confirmed) return;
    }

    try {
      await ref.read(projectsProvider.notifier).deleteProjects(toDelete);
    } catch (e) {
      showProviderError(e);
      return;
    }

    setState(() {
      projectSelectionMode = false;
      selectedProjectIndexes.clear();
    });
    if (mounted) Navigator.of(context).pop();
  }

  void switchProject(int idx) {
    if (projectSelectionMode) {
      setState(() {
        if (selectedProjectIndexes.contains(idx)) {
          selectedProjectIndexes.remove(idx);
          if (selectedProjectIndexes.isEmpty) {
            drawerIconController.reverse();
            projectSelectionMode = false;
          }
        } else {
          drawerIconController.reset();
          buildingSelectionMode = false;
          selectedBuildingIndexes.clear();

          selectedProjectIndexes.add(idx);
          drawerIconController.forward();
        }
      });
      return;
    }

    if (idx == drawerProjectIndex) return;

    ref.read(projectsProvider.notifier).selectProject(idx);
    onBuildingSwitched();
  }

  void switchBuilding(int idx) {
    if (buildingSelectionMode) {
      setState(() {
        if (selectedBuildingIndexes.contains(idx)) {
          selectedBuildingIndexes.remove(idx);
          if (selectedBuildingIndexes.isEmpty) {
            drawerIconController.reverse();
            buildingSelectionMode = false;
          }
        } else {
          drawerIconController.reset();
          projectSelectionMode = false;
          selectedProjectIndexes.clear();

          selectedBuildingIndexes.add(idx);
          drawerIconController.forward();
        }
      });
      return;
    }

    if (idx == drawerBuildingIndex) return;

    setState(() {
      drawerBuildingIndex = idx;
      drawerBuilding = drawerProject.buildings[idx];
    });
    ref.read(projectsProvider.notifier).selectBuilding(idx);
    onBuildingSwitched();
  }

  void onDrawerChanged(bool isOpen) {
    if (isOpen) {
      drawerIconController.forward();
    } else {
      drawerIconController.reverse();
      setState(() {
        projectSelectionMode = false;
        selectedProjectIndexes.clear();
        buildingSelectionMode = false;
        selectedBuildingIndexes.clear();
      });
    }
  }

  Widget buildBuildingDetailsDrawer(BuildContext context) {
    final projects = ref.read(projectsProvider).projects;

    return BuildingDetailsDrawer(
      projects: projects,
      currentProject: drawerProject,
      currentBuilding: drawerBuilding,
      currentProjectIndex: drawerProjectIndex,
      currentBuildingIndex: drawerBuildingIndex,
      projectSelectionMode: projectSelectionMode,
      buildingSelectionMode: buildingSelectionMode,
      selectedProjectIndexes: selectedProjectIndexes,
      selectedBuildingIndexes: selectedBuildingIndexes,
      drawerIconAnimation: drawerIconAnimation,
      onExitProjectSelection: exitProjectSelection,
      onExitBuildingSelection: exitBuildingSelection,
      onStartProjectSelection: startProjectSelection,
      onStartBuildingSelection: startBuildingSelection,
      onSwitchProject: switchProject,
      onSwitchBuilding: switchBuilding,
      onDeleteSelectedProjects: deleteSelectedProjects,
      onDeleteSelectedBuildings: deleteSelectedBuildingsInDrawer,
      onOpenRecycleBin: openRecycleBin,
      onAddProject: showAddProjectDialog,
      onAddBuilding: showAddBuildingDialog,
      onImportCsv: onImportCsv,
      onExportCsv: onExportCsv,
      onOpenAppSettings: openAppSettingsFromDrawer,
      onOpenCsvSettings: openCsvSettingsFromDrawer,
    );
  }

  void exitProjectSelection() {
    drawerIconController.reverse();
    setState(() {
      projectSelectionMode = false;
      selectedProjectIndexes.clear();
    });
  }

  void exitBuildingSelection() {
    drawerIconController.reverse();
    setState(() {
      buildingSelectionMode = false;
      selectedBuildingIndexes.clear();
    });
  }

  void startProjectSelection(int idx) {
    drawerIconController.reset();
    buildingSelectionMode = false;
    selectedBuildingIndexes.clear();
    setState(() {
      projectSelectionMode = true;
      selectedProjectIndexes.add(idx);
    });
    drawerIconController.forward();
  }

  void startBuildingSelection(int idx) {
    drawerIconController.reset();
    projectSelectionMode = false;
    selectedProjectIndexes.clear();
    setState(() {
      buildingSelectionMode = true;
      selectedBuildingIndexes.add(idx);
    });
    drawerIconController.forward();
  }

  void openAppSettingsFromDrawer() {
    final projects = ref.read(projectsProvider).projects;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppSettingsPage(
          projectId: projects.isNotEmpty ? drawerProject.id : null,
          buildingId: projects.isNotEmpty && drawerProject.buildings.isNotEmpty
              ? drawerBuilding.id
              : null,
        ),
      ),
    );
  }

  Future<void> openCsvSettingsFromDrawer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CsvSettingsPage(
          projectId: drawerProject.id,
          buildingId: drawerBuilding.id,
        ),
      ),
    );
    await reloadDisciplinesForDrawer(refreshSystemsPages: true);
  }
}
