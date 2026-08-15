/// Selection-Modes und Bulk-Aktionen der Gebäude-Seite.
///
/// Koordiniert Gewerk-/Gruppen-/Anlagen-Auswahl und Soft-Delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_manager.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/core/utils/delete_utils.dart';
import 'package:bestandsaufnahme_01/features/systems/pages/systems_page.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_anlage_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/soft_delete_confirm_dialog.dart';

/// Selection-Modes + Bulk-Aktionen (Abschnitt 5 der Gebäude-Seite).
mixin BuildingDetailsSelectionActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BuildingDetailsAnlageActions<T> {
  Building get selectionBuilding;
  Project get selectionProject;

  bool get systemsSelectionMode;
  set systemsSelectionMode(bool value);
  int get systemsSelectedCount;
  set systemsSelectedCount(int value);
  Map<String, int> get activeSelections;

  bool get disciplineSelectionMode;
  set disciplineSelectionMode(bool value);
  Set<String> get selectedDisciplineLabels;

  bool get groupSelectionMode;
  set groupSelectionMode(bool value);

  Map<Disziplin, GlobalKey<SystemsPageState>> get systemsPageKeys;
  AnimationController get drawerIconController;

  Future<void> reloadDisciplinesForSelection({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  });
  Future<void> reloadAllAnlagenForProgress();

  /// Beendet SelectionMode in allen SystemsPages zu den aktiven Labels.
  void exitSystemsPageSelectionsForLabels(Iterable<String> labels) {
    for (final label in labels) {
      try {
        final disc = systemsPageKeys.keys.firstWhere((d) => d.label == label);
        systemsPageKeys[disc]?.currentState?.exitSelectionMode();
      } catch (e) {
        appLog('Systems-Selection beenden fehlgeschlagen', error: e);
      }
    }
  }

  void enterGroupSelectionMode(
    Disziplin discipline,
    String groupKey,
    String groupValue,
    Map<String, dynamic> additionalParams, {
    required bool isSchemaItemLevel,
  }) {
    if (systemsSelectionMode) {
      exitSystemsPageSelectionsForLabels(activeSelections.keys.toList());
    }

    setState(() {
      systemsSelectionMode = false;
      systemsSelectedCount = 0;
      activeSelections.clear();
      disciplineSelectionMode = false;
      selectedDisciplineLabels.clear();
      groupSelectionMode = true;
      groupSelectionContext = (
        discipline: discipline,
        groupKey: groupKey,
        groupValue: groupValue,
        additionalParams: additionalParams,
        isSchemaItemLevel: isSchemaItemLevel,
      );
    });
    drawerIconController.forward();
  }

  void exitGroupSelectionMode() {
    setState(() {
      groupSelectionMode = false;
      groupSelectionContext = null;
    });
    drawerIconController.reverse();
  }

  void enterDisciplineSelectionMode(Disziplin discipline) {
    if (systemsSelectionMode) {
      exitSystemsPageSelectionsForLabels(activeSelections.keys.toList());
    }
    if (groupSelectionMode) {
      exitGroupSelectionMode();
    }

    setState(() {
      systemsSelectionMode = false;
      systemsSelectedCount = 0;
      activeSelections.clear();
      disciplineSelectionMode = true;
      selectedDisciplineLabels
        ..clear()
        ..add(discipline.label);
    });
    drawerIconController.forward();
  }

  void exitDisciplineSelectionMode() {
    setState(() {
      disciplineSelectionMode = false;
      selectedDisciplineLabels.clear();
    });
    drawerIconController.reverse();
  }

  void toggleDisciplineSelection(Disziplin discipline) {
    setState(() {
      if (!disciplineSelectionMode) {
        disciplineSelectionMode = true;
        selectedDisciplineLabels
          ..clear()
          ..add(discipline.label);
        drawerIconController.forward();
        return;
      }

      if (selectedDisciplineLabels.contains(discipline.label)) {
        selectedDisciplineLabels.remove(discipline.label);
        if (selectedDisciplineLabels.isEmpty) {
          disciplineSelectionMode = false;
          drawerIconController.reverse();
        }
      } else {
        selectedDisciplineLabels.add(discipline.label);
      }
    });
  }

  Disziplin? getSingleSelectedDiscipline() {
    if (selectedDisciplineLabels.length != 1) return null;
    final label = selectedDisciplineLabels.first;
    try {
      return systemsPageKeys.keys.firstWhere((d) => d.label == label);
    } catch (e) {
      appLog('Ausgewählte Disziplin nicht in Keys gefunden: $label', error: e);
      return null;
    }
  }

  Future<void> onAnlageCreatedFromSystemsPage() async {
    if (disciplineSelectionMode) {
      exitDisciplineSelectionMode();
    }
    await reloadAllAnlagenForProgress();
  }

  Future<void> onBauteilCreatedFromSystemsPage() async {
    await reloadAllAnlagenForProgress();
  }

  Future<void> editSelectedDiscipline() async {
    final d = getSingleSelectedDiscipline();
    if (d == null) return;

    final edited = await showDialog<Disziplin>(
      context: context,
      builder: (_) => DisziplinEditDialog(disziplin: d),
    );
    if (edited == null) return;

    final success = await updateDiscipline(
      context,
      ref.read(databaseServiceProvider),
      d,
      edited,
      selectionBuilding.id,
    );
    if (success) {
      await reloadDisciplinesForSelection();
      exitDisciplineSelectionMode();
    }
  }

  Future<void> deleteSelectedDiscipline() async {
    if (selectedDisciplineLabels.isEmpty) return;

    final dbService = ref.read(databaseServiceProvider);
    final labels = selectedDisciplineLabels.toList();
    final anlagenPerLabel = <String, List<Anlage>>{};
    int totalAnlagen = 0;
    for (final label in labels) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(
        selectionBuilding.id,
        label,
      );
      anlagenPerLabel[label] = anlagen;
      totalAnlagen += anlagen.length;
    }

    if (totalAnlagen > 0) {
      final confirmed = await showSoftDeleteConfirmDialog(
        context,
        title: 'Gewerk${labels.length > 1 ? 'e' : ''} hat noch Anlagen',
        countLabel: labels.length == 1
            ? '$totalAnlagen Anlage${totalAnlagen > 1 ? 'n' : ''} in "${labels.first}"'
            : '$totalAnlagen Anlage${totalAnlagen > 1 ? 'n' : ''} in ${labels.length} Gewerken',
        message:
            'Wenn du die Disziplin löschst, werden die zugehörigen Anlagen in den Papierkorb verschoben. Die Disziplin selbst wird entfernt (kein Soft-Delete für Gewerke).',
        confirmLabel: 'Löschen',
        footnote:
            'Anlagen können aus dem Papierkorb wiederhergestellt werden',
      );
      if (!confirmed) return;

      for (final entry in anlagenPerLabel.entries) {
        for (final a in entry.value) {
          await dbService.deleteAnlage(a.id);
        }
      }
    } else {
      final name =
          labels.length == 1 ? labels.first : '${labels.length} Gewerke';
      final confirmed =
          await showDeleteConfirmationDialog(context, 'Disziplin', name);
      if (!confirmed) return;
    }

    for (final label in labels) {
      await dbService.deleteDiscipline(selectionBuilding.id, label);
    }
    if (!mounted) return;

    await reloadDisciplinesForSelection();
    exitDisciplineSelectionMode();
  }

  Future<void> openBulkAddBauteilForSystemsSelection() async {
    final activeLabels = activeSelections.keys.toList();
    if (activeLabels.length != 1) return;

    try {
      final discipline =
          systemsPageKeys.keys.firstWhere((d) => d.label == activeLabels.first);
      systemsPageKeys[discipline]
          ?.currentState
          ?.openAddBauteilDialogForSelection();
    } catch (e) {
      appLog(
        'Disziplin ${activeLabels.first} nicht gefunden beim Bauteil-Hinzufügen',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gewerk „${activeLabels.first}“ nicht gefunden'),
          ),
        );
      }
    }
  }

  Future<void> openMoveDialogForSystemsSelection() async {
    final activeLabels = activeSelections.keys.toList();
    if (activeLabels.length != 1) return;

    try {
      final discipline =
          systemsPageKeys.keys.firstWhere((d) => d.label == activeLabels.first);
      systemsPageKeys[discipline]?.currentState?.moveSelectedAnlagen();
    } catch (e) {
      appLog(
        'Disziplin ${activeLabels.first} nicht gefunden beim Verschieben',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gewerk „${activeLabels.first}“ nicht gefunden'),
          ),
        );
      }
    }
  }

  Future<void> handleDeleteSelectedAnlagen() async {
    final confirmed = await showSoftDeleteConfirmDialog(
      context,
      title: 'Anlagen löschen?',
      countLabel:
          '$systemsSelectedCount Anlage${systemsSelectedCount > 1 ? 'n' : ''} ausgewählt',
      message:
          'Die ausgewählten Anlagen werden in den Papierkorb verschoben und können von dort wiederhergestellt werden.',
    );
    if (!confirmed) return;

    final activeDisciplines = activeSelections.keys.toList();
    for (final label in activeDisciplines) {
      try {
        final discipline =
            systemsPageKeys.keys.firstWhere((d) => d.label == label);
        systemsPageKeys[discipline]?.currentState?.deleteSelectedAnlagen();
      } catch (e) {
        appLog('Disziplin $label nicht gefunden beim Löschen');
      }
    }
  }
}
