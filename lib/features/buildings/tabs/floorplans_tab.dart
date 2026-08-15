/// Tab „Grundrisse“: Liste der Etagen-PDFs, Expand und Selection.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/pages/floor_plan_page.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';

/// Liste der Grundrisse eines Gebäudes inkl. Upload/Löschen-Callbacks.
class FloorPlansTab extends ConsumerStatefulWidget {
  final Building building;
  final int index;

  /// Optionale Callbacks an die Gebäude-Seite.
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

/// State der Grundriss-Liste (Expand-Zustand der Etagen).
class _FloorPlansTabState extends ConsumerState<FloorPlansTab> {
  final Set<String> _expandedFloorIds = {};

  @override
  void didUpdateWidget(covariant FloorPlansTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Aufgeräumt halten, falls Etagen gelöscht wurden
    final currentIds = widget.building.floors.map((f) => f.id).toSet();
    _expandedFloorIds.removeWhere((id) => !currentIds.contains(id));
  }

  Future<void> _handleTap(int idx, FloorPlan floor) async {
    if (widget.isSelectionMode) {
      widget.onFloorTap?.call(idx);
      return;
    }

    // PDF öffnen, falls vorhanden
    if (floor.pdfPath != null && await File(floor.pdfPath!).exists()) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FloorPlanFullScreen(
            building: widget.building,
            floor: floor,
            dbService: ref.read(databaseServiceProvider),
          ),
          transitionsBuilder: (_, animation, __, child) {
            final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
      try {
        await ref.read(projectsProvider.notifier).updateBuilding(widget.building);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gebäude speichern fehlgeschlagen: $e')),
          );
        }
      }
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
    final newPath = path.join(appDir.path, '${widget.building.id}_${floor.id}.pdf');
    final newFile = await File(originalPath).copy(newPath);

    setState(() {
      floor.pdfPath = newFile.path;
      floor.pdfName = originalName; // PDF-Name wird jetzt im FloorPlan-Objekt gespeichert
    });

    // PDF-Pfade werden jetzt in Drift gespeichert, keine SharedPreferences mehr nötig
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(widget.building);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gebäude speichern fehlgeschlagen: $e')),
        );
      }
      return;
    }

    // direkt Vollbild anzeigen
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FloorPlanFullScreen(
          building: widget.building,
          floor: floor,
          dbService: ref.read(databaseServiceProvider),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    await ref.read(projectsProvider.notifier).updateBuilding(widget.building);
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.building.floors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: floors.isEmpty
          ? const Center(
        child: Text(
          'Es sind keine Etagen oder Grundriss-PDFs vorhanden.\n'
              'Füge über den Button unten rechts eine PDF hinzu oder importiere Daten per CSV.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: [
          for (var idx = 0; idx < floors.length; idx++)
            _buildFloorTile(idx, floors[idx]),
        ],
      ),
    );
  }

  Widget _buildFloorTile(int idx, FloorPlan floor) {
    final isSelected = widget.selectedFloorIndexes.contains(idx);
    final isExpanded = _expandedFloorIds.contains(floor.id);
    final hasPdf = floor.pdfPath != null && floor.pdfPath!.trim().isNotEmpty;
    final title = floor.name.trim().isNotEmpty
        ? floor.name.trim()
        : (floor.pdfName?.trim().isNotEmpty == true ? floor.pdfName!.trim() : 'Unbenannte Etage');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, AppPalette.surface, 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isSelectionMode && isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.35)
              : (isExpanded ? AppPalette.primary.withOpacity(0.28) : Colors.grey.withOpacity(0.15)),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (widget.isSelectionMode) {
                    widget.onFloorTap?.call(idx);
                    return;
                  }
                  setState(() {
                    if (isExpanded) {
                      _expandedFloorIds.remove(floor.id);
                    } else {
                      _expandedFloorIds.add(floor.id);
                    }
                  });
                },
                onLongPress: widget.onFloorLongPress != null
                    ? () => widget.onFloorLongPress!(idx)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.isSelectionMode && isSelected
                                ? [
                                    Theme.of(context).primaryColor.withOpacity(0.22),
                                    Theme.of(context).primaryColor.withOpacity(0.10),
                                  ]
                                : [
                                    AppPalette.primary.withOpacity(0.18),
                                    AppPalette.primary.withOpacity(0.08),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.layers,
                          color: widget.isSelectionMode && isSelected
                              ? Theme.of(context).primaryColor
                              : AppPalette.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelectionMode && isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[900],
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hasPdf ? AppPalette.primary : Colors.grey).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasPdf ? 'PDF' : '—',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasPdf ? AppPalette.primary : Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (widget.isSelectionMode)
                        (isSelected
                            ? Icon(Icons.check_circle, color: AppPalette.primary)
                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey))
                      else
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppPalette.primary.withOpacity(0.10)
                                : Colors.grey.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                            color: isExpanded ? AppPalette.primary : Colors.grey[600],
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: isExpanded
                  ? Container(
                      color: Colors.grey[50],
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Icon(
                              hasPdf ? Icons.picture_as_pdf : Icons.upload_file,
                              color: hasPdf ? AppPalette.primary : AppPalette.iconMuted,
                            ),
                            title: Text(
                              hasPdf
                                  ? (floor.pdfName?.isNotEmpty == true ? floor.pdfName! : 'Grundriss öffnen')
                                  : 'Grundriss (PDF) hinzufügen',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: hasPdf
                                ? const Text('Tippen zum Öffnen', style: TextStyle(fontSize: 12))
                                : const Text('Tippen zum Auswählen', style: TextStyle(fontSize: 12)),
                            onTap: () => _handleTap(idx, floor),
                            trailing: widget.isSelectionMode
                                ? null
                                : const Icon(Icons.chevron_right, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
