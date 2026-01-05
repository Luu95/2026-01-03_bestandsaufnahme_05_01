// lib/pages/tabs/floorplans_tab.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/building.dart';
import '../../models/floor_plan.dart';
import '../floor_plan_page.dart';
import '../../providers/projects_provider.dart';

class FloorPlansTab extends ConsumerStatefulWidget {
  final Building building;
  final int index;

  // Optionale Callbacks:
  final VoidCallback? onAddFloor;
  final bool isSelectionMode;
  final Set<int> selectedFloorIndexes;
  final void Function(int)? onFloorTap;
  final void Function(int)? onFloorLongPress;
  final Future<void> Function(int)? onDeleteSingleFloor;

  const FloorPlansTab({
    Key? key,
    required this.building,
    required this.index,
    this.onAddFloor,
    this.isSelectionMode = false,
    this.selectedFloorIndexes = const {},
    this.onFloorTap,
    this.onFloorLongPress,
    this.onDeleteSingleFloor,
  }) : super(key: key);

  @override
  ConsumerState<FloorPlansTab> createState() => _FloorPlansTabState();
}

class _FloorPlansTabState extends ConsumerState<FloorPlansTab> {
  late Building _building;

  @override
  void initState() {
    super.initState();
    _building = widget.building;
  }

  @override
  void didUpdateWidget(covariant FloorPlansTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.building.id != widget.building.id ||
        oldWidget.building.floors.length != widget.building.floors.length) {
      _building = widget.building;
    }
  }

  Future<void> _handleTap(int idx, FloorPlan floor) async {
    if (widget.isSelectionMode) {
      widget.onFloorTap?.call(idx);
      return;
    }

    // PDF öffnen, falls vorhanden
    if (floor.pdfPath != null && File(floor.pdfPath!).existsSync()) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FloorPlanFullScreen(
            building: _building,
            floor: floor,
          ),
          transitionsBuilder: (_, animation, __, child) {
            final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
      await ref.read(projectsProvider.notifier).updateBuilding(_building);
      return;
    }

    // PDF nachladen, falls noch nicht vorhanden
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final originalPath = result.files.single.path!;
    final originalName = result.files.single.name;
    final appDir = await getApplicationDocumentsDirectory();
    final newPath = path.join(appDir.path, '${_building.id}_${floor.id}.pdf');
    final newFile = await File(originalPath).copy(newPath);

    setState(() {
      floor.pdfPath = newFile.path;
      floor.pdfName = originalName; // PDF-Name wird jetzt im FloorPlan-Objekt gespeichert
    });

    // PDF-Pfade werden jetzt in Drift gespeichert, keine SharedPreferences mehr nötig
    await ref.read(projectsProvider.notifier).updateBuilding(_building);

    // direkt Vollbild anzeigen
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FloorPlanFullScreen(
          building: _building,
          floor: floor,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    await ref.read(projectsProvider.notifier).updateBuilding(_building);
  }

  @override
  Widget build(BuildContext context) {
    final validFloors = _building.floors
        .where((f) => f.pdfPath != null && File(f.pdfPath!).existsSync())
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: validFloors.isEmpty
          ? const Center(
        child: Text(
          'Es sind keine Grundriss-PDFs vorhanden.\n'
              'Füge über den Button unten rechts eine PDF hinzu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : ListView.separated(
        itemCount: validFloors.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (ctx, idx) {
          final floor = validFloors[idx];
          final isSelected = widget.selectedFloorIndexes.contains(idx);

          return ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isSelected
                  ? Theme.of(context)
                  .primaryColor
                  .withOpacity(0.3)
                  : Colors.grey.shade200,
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
                size: 28,
              ),
            ),
            title: Text(
              floor.pdfName?.isNotEmpty == true
                  ? floor.pdfName!
                  : (floor.name.isNotEmpty
                      ? floor.name
                      : 'Unbenannter Grundriss'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
            onTap: () => _handleTap(idx, floor),
            onLongPress: widget.onFloorLongPress != null
                ? () => widget.onFloorLongPress!(idx)
                : null,
            trailing: widget.isSelectionMode
                ? (isSelected
                ? const Icon(Icons.check_circle,
                color: Colors.blueAccent)
                : const Icon(Icons.radio_button_unchecked,
                color: Colors.grey))
                : null,
          );
        },
      ),
    );
  }
}
