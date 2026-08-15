/// Grundriss-Auswahl, Soft-Delete und PDF-Upload auf der Gebäude-Seite.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/services/floor_plan_service.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/pages/floor_plan_page.dart';

/// Grundriss-Auswahl, Löschen und Upload (Abschnitt 3 der Gebäude-Seite).
mixin BuildingDetailsFloorActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Building get floorBuilding;
  bool get isFloorSelectionMode;
  set isFloorSelectionMode(bool value);
  Set<int> get selectedFloorIndexes;
  AnimationController get drawerIconController;

  void showProviderError(Object e);

  void exitFloorplansSelectionMode() {
    setState(() {
      isFloorSelectionMode = false;
      selectedFloorIndexes.clear();
    });
    drawerIconController.reverse();
  }

  Future<void> deleteSelectedFloors() async {
    final toDelete = selectedFloorIndexes.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final idx in toDelete) {
      await FloorPlanService.deleteFloor(
        floorId: floorBuilding.floors[idx].id,
        floorList: floorBuilding.floors,
        indexInList: idx,
      );
    }
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(floorBuilding);
    } catch (e) {
      showProviderError(e);
      return;
    }
    exitFloorplansSelectionMode();
    if (mounted) setState(() {});
  }

  void onFloorTap(int idx) {
    if (isFloorSelectionMode) {
      setState(() {
        if (selectedFloorIndexes.contains(idx)) {
          selectedFloorIndexes.remove(idx);
          if (selectedFloorIndexes.isEmpty) {
            exitFloorplansSelectionMode();
          }
        } else {
          selectedFloorIndexes.add(idx);
        }
      });
    } else {
      final floor = floorBuilding.floors[idx];
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FloorPlanFullScreen(
            building: floorBuilding,
            floor: floor,
            dbService: ref.read(databaseServiceProvider),
          ),
          transitionsBuilder: (_, animation, __, child) {
            final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ).then((_) async {
        try {
          await ref.read(projectsProvider.notifier).updateBuilding(floorBuilding);
        } catch (e) {
          showProviderError(e);
        }
      });
    }
  }

  void onFloorLongPress(int idx) {
    if (!isFloorSelectionMode) {
      setState(() {
        isFloorSelectionMode = true;
        selectedFloorIndexes.add(idx);
      });
      drawerIconController.forward();
    }
  }

  Future<void> onDeleteSingleFloor(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.zero,
        title: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: const Text(
            'Grundriss löschen?',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        content: const Text(
          'Möchtest du den ausgewählten Grundriss wirklich löschen?',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FloorPlanService.deleteFloor(
        floorId: floorBuilding.floors[idx].id,
        floorList: floorBuilding.floors,
        indexInList: idx,
      );
      try {
        await ref.read(projectsProvider.notifier).updateBuilding(floorBuilding);
      } catch (e) {
        showProviderError(e);
        return;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> handleDeleteSelectedFloors() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.zero,
        title: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: const Text(
            'Grundrisse löschen?',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        content: Text(
          'Möchtest du ${selectedFloorIndexes.length} ausgewählte Grundrisse wirklich löschen?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteSelectedFloors();
    }
  }

  Future<void> addNewFloorAndUpload() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newFloor = FloorPlan(id: newId, name: '');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final originalPath = result.files.single.path!;
    final originalName = result.files.single.name;

    final appDir = await getApplicationDocumentsDirectory();
    final newPath = path.join(appDir.path, '${floorBuilding.id}_$newId.pdf');
    final newFile = await File(originalPath).copy(newPath);

    newFloor.pdfPath = newFile.path;
    newFloor.pdfName = originalName;

    setState(() {
      floorBuilding.floors.add(newFloor);
    });
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(floorBuilding);
    } catch (e) {
      showProviderError(e);
      return;
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FloorPlanFullScreen(
          building: floorBuilding,
          floor: newFloor,
          dbService: ref.read(databaseServiceProvider),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(floorBuilding);
    } catch (e) {
      showProviderError(e);
    }
  }
}
