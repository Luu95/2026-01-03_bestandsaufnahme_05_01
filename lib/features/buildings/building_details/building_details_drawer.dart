/// Seitenmenü: Projekte, Gebäude und CSV-/Settings-Aktionen.
///
/// Die [BuildingDetailsPage] hält den State; dieses Widget ist Darstellung
/// plus Tippen/Long-Press → Callbacks.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_action_button.dart';

/// Drawer der Gebäude-Hauptseite.
class BuildingDetailsDrawer extends StatelessWidget {
  final List<Project> projects;
  final Project currentProject;
  final Building currentBuilding;
  final int currentProjectIndex;
  final int currentBuildingIndex;

  final bool projectSelectionMode;
  final bool buildingSelectionMode;
  final Set<int> selectedProjectIndexes;
  final Set<int> selectedBuildingIndexes;

  /// Animation für Close-Icon (geteilt mit AppBar-Hamburger).
  final Animation<double> drawerIconAnimation;

  final VoidCallback onExitProjectSelection;
  final VoidCallback onExitBuildingSelection;
  final ValueChanged<int> onStartProjectSelection;
  final ValueChanged<int> onStartBuildingSelection;
  final ValueChanged<int> onSwitchProject;
  final ValueChanged<int> onSwitchBuilding;

  final VoidCallback onDeleteSelectedProjects;
  final VoidCallback onDeleteSelectedBuildings;
  final VoidCallback onOpenRecycleBin;
  final VoidCallback onAddProject;
  final VoidCallback onAddBuilding;

  final VoidCallback onImportCsv;
  final VoidCallback onExportCsv;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenCsvSettings;

  const BuildingDetailsDrawer({
    super.key,
    required this.projects,
    required this.currentProject,
    required this.currentBuilding,
    required this.currentProjectIndex,
    required this.currentBuildingIndex,
    required this.projectSelectionMode,
    required this.buildingSelectionMode,
    required this.selectedProjectIndexes,
    required this.selectedBuildingIndexes,
    required this.drawerIconAnimation,
    required this.onExitProjectSelection,
    required this.onExitBuildingSelection,
    required this.onStartProjectSelection,
    required this.onStartBuildingSelection,
    required this.onSwitchProject,
    required this.onSwitchBuilding,
    required this.onDeleteSelectedProjects,
    required this.onDeleteSelectedBuildings,
    required this.onOpenRecycleBin,
    required this.onAddProject,
    required this.onAddBuilding,
    required this.onImportCsv,
    required this.onExportCsv,
    required this.onOpenAppSettings,
    required this.onOpenCsvSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildProjectsHeader(context),
              _buildProjectsList(context),
              _buildBuildingsHeader(context),
              _buildBuildingsList(context),
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsHeader(BuildContext context) {
    if (projectSelectionMode) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onExitProjectSelection,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: RotationTransition(
                    turns: drawerIconAnimation,
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${selectedProjectIndexes.length} ausgewählt',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onDeleteSelectedProjects,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.folder,
              color: AppPalette.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Projekte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onOpenRecycleBin,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  size: 22,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onAddProject,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: AppPalette.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(BuildContext context) {
    return Flexible(
      flex: 2,
      child: projects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Keine Projekte',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: projects.length,
              itemBuilder: (ctx, idx) {
                final proj = projects[idx];
                final isSelected = idx == currentProjectIndex;
                final isChecked = selectedProjectIndexes.contains(idx);

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onLongPress: () {
                        if (!projectSelectionMode) {
                          onStartProjectSelection(idx);
                        }
                      },
                      onTap: () => onSwitchProject(idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.15)
                                    : AppPalette.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : AppPalette.primaryDark,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                proj.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[900],
                                ),
                              ),
                            ),
                            if (projectSelectionMode)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isChecked
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  color: isChecked
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              )
                            else if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).primaryColor,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBuildingsHeader(BuildContext context) {
    if (buildingSelectionMode) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onExitBuildingSelection,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: RotationTransition(
                    turns: drawerIconAnimation,
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${selectedBuildingIndexes.length} ausgewählt',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onDeleteSelectedBuildings,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_city,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentProjectIndex < 0 ? 'Keine Projekte' : 'Gebäude',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (currentProjectIndex >= 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAddBuilding,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 22,
                    color: AppPalette.primaryLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingsList(BuildContext context) {
    return Flexible(
      flex: 3,
      child: currentProject.buildings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_city_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Keine Gebäude',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: currentProject.buildings.length,
              itemBuilder: (ctx, idx) {
                final bldg = currentProject.buildings[idx];
                final isBldgSelected = idx == currentBuildingIndex;
                final isChecked = selectedBuildingIndexes.contains(idx);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isBldgSelected
                        ? AppPalette.primary.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBldgSelected
                          ? AppPalette.primary.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onLongPress: () {
                        if (!buildingSelectionMode) {
                          onStartBuildingSelection(idx);
                        }
                      },
                      onTap: () => onSwitchBuilding(idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isBldgSelected
                                    ? AppPalette.primary.withOpacity(0.15)
                                    : AppPalette.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.location_city,
                                color: isBldgSelected
                                    ? AppPalette.primaryDark
                                    : AppPalette.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bldg.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isBldgSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isBldgSelected
                                      ? AppPalette.primaryDark
                                      : Colors.grey[900],
                                ),
                              ),
                            ),
                            if (buildingSelectionMode)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isChecked
                                        ? AppPalette.primaryLight
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  color: isChecked
                                      ? AppPalette.primaryLight
                                      : Colors.transparent,
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              )
                            else if (isBldgSelected)
                              Icon(
                                Icons.check_circle,
                                color: AppPalette.primaryDark,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BuildingDetailsActionButton(
            icon: Icons.download_rounded,
            label: 'CSV importieren',
            color: AppPalette.success,
            onTap: onImportCsv,
          ),
          const SizedBox(height: 8),
          BuildingDetailsActionButton(
            icon: Icons.upload_rounded,
            label: 'CSV exportieren',
            color: AppPalette.primary,
            onTap: onExportCsv,
          ),
          const SizedBox(height: 8),
          BuildingDetailsActionButton(
            icon: Icons.tune_rounded,
            label: 'Allgemeine Einstellungen',
            color: AppPalette.primary,
            onTap: onOpenAppSettings,
          ),
          const SizedBox(height: 8),
          BuildingDetailsActionButton(
            icon: Icons.settings_rounded,
            label: 'CSV-Import',
            color: AppPalette.primaryLight,
            onTap: onOpenCsvSettings,
          ),
        ],
      ),
    );
  }
}
