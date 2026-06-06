// lib/pages/widgets/move_anlagen_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/csv_settings_provider.dart';
import '../../database/database_service.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_palette.dart';
import '../../services/template_service.dart';

/// Ergebnis der Verortungs-Auswahl beim Anlegen einer neuen Anlage.
class AnlagePlacementResult {
  final Disziplin discipline;
  final Map<String, dynamic> initialParams;

  const AnlagePlacementResult({
    required this.discipline,
    required this.initialParams,
  });
}

class MoveAnlagenDialog extends ConsumerStatefulWidget {
  final List<Anlage> anlagenToMove;
  final String currentBuildingId;
  final String currentFloorId;
  final Disziplin currentDiscipline;
  final String? projectId;

  /// Param-Key Ebene 1 (Revisionsfeld), null wenn Gewerk = Tab.
  final String? revisionsfeldGroupingKey;

  /// Param-Key Ebene 2 (Revisionsobjekt).
  final String? revisionsobjektGroupingKey;

  /// Nur Verortung wählen (neue Anlage), ohne Verschieben.
  final bool placementMode;

  /// Vorauswahl Revisionsfeld (z. B. aus Gruppen-Kontext).
  final String? initialRevisionsfeld;

  /// Vorauswahl Revisionsobjekt (z. B. aus Gruppen-Kontext).
  final String? initialRevisionsobjekt;

  const MoveAnlagenDialog({
    Key? key,
    required this.anlagenToMove,
    required this.currentBuildingId,
    required this.currentFloorId,
    required this.currentDiscipline,
    this.projectId,
    this.revisionsfeldGroupingKey,
    this.revisionsobjektGroupingKey,
    this.placementMode = false,
    this.initialRevisionsfeld,
    this.initialRevisionsobjekt,
  }) : super(key: key);

  /// Dialog zur Auswahl der Ziel-Verortung für eine neue Anlage.
  factory MoveAnlagenDialog.forPlacement({
    required Disziplin discipline,
    required String buildingId,
    required String floorId,
    String? projectId,
    String? revisionsfeldGroupingKey,
    String? revisionsobjektGroupingKey,
    String? initialRevisionsfeld,
    String? initialRevisionsobjekt,
  }) {
    return MoveAnlagenDialog(
      anlagenToMove: const [],
      currentBuildingId: buildingId,
      currentFloorId: floorId,
      currentDiscipline: discipline,
      projectId: projectId,
      revisionsfeldGroupingKey: revisionsfeldGroupingKey,
      revisionsobjektGroupingKey: revisionsobjektGroupingKey,
      placementMode: true,
      initialRevisionsfeld: initialRevisionsfeld,
      initialRevisionsobjekt: initialRevisionsobjekt,
    );
  }

  @override
  ConsumerState<MoveAnlagenDialog> createState() => _MoveAnlagenDialogState();
}

class _MoveAnlagenDialogState extends ConsumerState<MoveAnlagenDialog> {
  Disziplin? _selectedDiscipline;

  List<Disziplin> _availableDisciplines = [];

  CsvSettings? _csvSettings;
  String? _selectedRevisionsfeld;
  String? _selectedRevisionsobjekt;
  /// Revisionsfeld → bekannte Revisionsobjekte im Gebäude.
  Map<String, Set<String>> _locationTargets = {};

  bool _isLoading = true;
  bool _isMoving = false;

  bool get _areAllAnlagen {
    if (widget.placementMode && widget.anlagenToMove.isEmpty) return true;
    return widget.anlagenToMove.every((a) => a.parentId == null);
  }

  bool get _areAllBauteile {
    return widget.anlagenToMove.every((a) => a.parentId != null);
  }

  bool get _hasHierarchyMove =>
      _areAllAnlagen &&
      widget.revisionsobjektGroupingKey != null &&
      widget.revisionsobjektGroupingKey!.trim().isNotEmpty;

  String get _revisionsfeldLabel {
    final fromKey = widget.revisionsfeldGroupingKey?.trim();
    if (fromKey != null && fromKey.isNotEmpty) return fromKey;
    return _csvSettings?.labelGewerk ?? 'Revisionsfeld';
  }

  String get _revisionsobjektLabel {
    final fromKey = widget.revisionsobjektGroupingKey?.trim();
    if (fromKey != null && fromKey.isNotEmpty) return fromKey;
    return _csvSettings?.resolveSchemaItemLevelLabel() ?? 'Revisionsobjekt';
  }

  @override
  void initState() {
    super.initState();
    _selectedDiscipline = widget.currentDiscipline;
    final initialRf = widget.initialRevisionsfeld?.trim();
    if (initialRf != null && initialRf.isNotEmpty) {
      _selectedRevisionsfeld = initialRf;
    }
    final initialRo = widget.initialRevisionsobjekt?.trim();
    if (initialRo != null && initialRo.isNotEmpty) {
      _selectedRevisionsobjekt = initialRo;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseServiceProvider);

    var projectId = widget.projectId;
    if (projectId == null || projectId.isEmpty) {
      projectId = await db.getProjectIdByBuildingId(widget.currentBuildingId);
    }
    if (projectId != null && projectId.isNotEmpty) {
      await ref.read(csvSettingsProvider(projectId).notifier).load();
      _csvSettings = ref.read(csvSettingsProvider(projectId));
    }

    final disciplines = await db.getDisciplinesByBuildingId(widget.currentBuildingId);

    if (_hasHierarchyMove) {
      await _loadHierarchyTargets(
        db,
        disciplines: disciplines,
      );
    }

    if (mounted) {
      setState(() {
        _availableDisciplines = disciplines;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHierarchyTargets(
    DatabaseService db, {
    String? disciplineLabel,
    List<Disziplin>? disciplines,
  }) async {
    final csv = _csvSettings;
    final roKey = widget.revisionsobjektGroupingKey!.trim();
    final rfKey = widget.revisionsfeldGroupingKey?.trim();
    final label = disciplineLabel ?? _selectedDiscipline?.label ?? widget.currentDiscipline.label;

    final allInScope = await db.getAnlagenByBuildingIdAndDiscipline(
      widget.currentBuildingId,
      label,
    );

    final targets = <String, Set<String>>{};
    for (final anlage in allInScope) {
      if (anlage.parentId != null) continue;
      final ro = csv?.revisionsobjektValueFromParams(anlage.params) ??
          anlage.params[roKey]?.toString().trim() ??
          '';
      if (ro.isEmpty) continue;

      var rf = '';
      if (rfKey != null && rfKey.isNotEmpty) {
        rf = csv?.revisionsfeldValueFromParams(anlage.params) ??
            anlage.params[rfKey]?.toString().trim() ??
            '';
      }
      targets.putIfAbsent(rf, () => {}).add(ro);
    }

    final disciplineList = disciplines ?? _availableDisciplines;
    final disciplineForNames = disciplineList.firstWhere(
      (d) => d.label == label,
      orElse: () => widget.currentDiscipline,
    );
    for (final ro in disciplineForNames.revisionsobjektNames) {
      if (ro.trim().isEmpty) continue;
      targets.putIfAbsent('', () => {}).add(ro.trim());
    }

    final projectId = await db.getProjectIdByBuildingId(widget.currentBuildingId);
    if (projectId != null && projectId.isNotEmpty) {
      final templates = await TemplateService.loadTemplatesFromDatabase(
        db,
        projectId,
        gewerk: label,
      );
      for (final t in templates) {
        final typ = t.anlagentyp.trim();
        if (typ.isNotEmpty) {
          targets.putIfAbsent('', () => {}).add(typ);
        }
      }
    }

    // Aktuelle Verortung der zu verschiebenden Elemente als Vorauswahl
    String? initialRf;
    String? initialRo;
    if (widget.placementMode) {
      initialRf = widget.initialRevisionsfeld?.trim();
      initialRo = widget.initialRevisionsobjekt?.trim();
    }
    if (widget.anlagenToMove.isNotEmpty) {
      final first = widget.anlagenToMove.first;
      initialRo = csv?.revisionsobjektValueFromParams(first.params) ??
          first.params[roKey]?.toString().trim();
      if (rfKey != null && rfKey.isNotEmpty) {
        initialRf = csv?.revisionsfeldValueFromParams(first.params) ??
            first.params[rfKey]?.toString().trim() ??
            '';
      }
    }

    if (mounted) {
      setState(() {
        _locationTargets = targets;
        _selectedRevisionsfeld = initialRf ?? '';
        if (initialRo != null && initialRo.isNotEmpty) {
          _selectedRevisionsobjekt = initialRo;
        } else if (targets.isNotEmpty) {
          final firstRf = targets.keys.first;
          final ros = targets[firstRf];
          if (ros != null && ros.isNotEmpty) {
            _selectedRevisionsobjekt = ros.first;
          }
        }
      });
    }
  }

  List<String> get _sortedRevisionsfelder {
    final keys = _locationTargets.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });
    return keys;
  }

  List<String> get _revisionsobjekteForSelectedFeld {
    final rf = _selectedRevisionsfeld ?? '';
    final ros = _locationTargets[rf]?.toList() ?? [];
    ros.sort((a, b) => a.compareTo(b));
    return ros;
  }

  /// Tatsächlich gewähltes Revisionsfeld (Dropdown-Anzeige = gespeicherter Wert).
  String? get _effectiveRevisionsfeld {
    final list = _sortedRevisionsfelder;
    if (list.isEmpty) return null;
    final selected = _selectedRevisionsfeld;
    if (selected != null && list.contains(selected)) return selected;
    return list.first;
  }

  /// Tatsächlich gewähltes Revisionsobjekt (Dropdown-Anzeige = gespeicherter Wert).
  String? get _effectiveRevisionsobjekt {
    final list = _revisionsobjekteForSelectedFeld;
    if (list.isEmpty) return null;
    final selected = _selectedRevisionsobjekt?.trim();
    if (selected != null && selected.isNotEmpty && list.contains(selected)) {
      return selected;
    }
    return list.first;
  }

  void _syncHierarchySelectionFromDropdowns() {
    if (!_hasHierarchyMove) return;
    final rfKey = widget.revisionsfeldGroupingKey?.trim();
    if (rfKey != null && rfKey.isNotEmpty) {
      _selectedRevisionsfeld = _effectiveRevisionsfeld;
    }
    _selectedRevisionsobjekt = _effectiveRevisionsobjekt;
  }

  bool _areSchemasCompatible(Disziplin source, Disziplin target) {
    final sourceKeys = source.schema.map((e) => e['key']).toSet();
    final targetKeys = target.schema.map((e) => e['key']).toSet();
    return targetKeys.containsAll(sourceKeys) ||
        sourceKeys.intersection(targetKeys).isNotEmpty;
  }

  bool get _canExecuteHierarchyMove {
    if (!_hasHierarchyMove) return true;
    final ro = _effectiveRevisionsobjekt?.trim() ?? '';
    if (ro.isEmpty) return false;
    final rfKey = widget.revisionsfeldGroupingKey?.trim();
    if (rfKey != null && rfKey.isNotEmpty) {
      final rf = _effectiveRevisionsfeld?.trim() ?? '';
      if (rf.isEmpty) return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> _buildHierarchyParamsForSelection() async {
    final db = ref.read(databaseServiceProvider);
    var projectId = widget.projectId;
    if (projectId == null || projectId.isEmpty) {
      projectId = await db.getProjectIdByBuildingId(widget.currentBuildingId);
    }
    final params = <String, dynamic>{};
    if (projectId == null) return params;

    final csvSettings = await CsvSettings.loadForProject(projectId);
    final gewerkKey = csvSettings.resolveGewerkGroupingParamKey();
    if (gewerkKey.isNotEmpty && !csvSettings.isLeafNameParamKey(gewerkKey)) {
      params[gewerkKey] = _selectedDiscipline!.label;
    }

    if (_hasHierarchyMove) {
      _syncHierarchySelectionFromDropdowns();
      final ro = _effectiveRevisionsobjekt?.trim();
      if (ro != null && ro.isNotEmpty) {
        final rfKey = widget.revisionsfeldGroupingKey?.trim();
        final rf = rfKey != null && rfKey.isNotEmpty
            ? _effectiveRevisionsfeld?.trim()
            : null;
        final hierarchy = csvSettings.buildHierarchyLocationParams(
          revisionsfeld: rf?.isNotEmpty == true ? rf : null,
          revisionsobjekt: ro,
        );
        hierarchy.forEach((key, value) {
          if (!csvSettings.isLeafNameParamKey(key)) {
            params[key] = value;
          }
        });
      }
    }
    return params;
  }

  Future<void> _executePlacement() async {
    if (_selectedDiscipline == null) return;
    if (_hasHierarchyMove && !_canExecuteHierarchyMove) return;

    setState(() => _isMoving = true);

    try {
      final params = await _buildHierarchyParamsForSelection();
      if (!mounted) return;
      Navigator.of(context).pop(
        AnlagePlacementResult(
          discipline: _disciplineForMove(),
          initialParams: params,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMoving = false);
      }
    }
  }

  Disziplin _disciplineForMove() {
    var discipline = _selectedDiscipline!;
    final ro = _effectiveRevisionsobjekt?.trim();
    if (_hasHierarchyMove && ro != null && ro.isNotEmpty) {
      discipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
        discipline: discipline,
        revisionsobjekt: ro,
      );
    }
    return discipline;
  }

  Future<void> _executeMove() async {
    if (widget.placementMode) {
      await _executePlacement();
      return;
    }
    if (_selectedDiscipline == null) return;
    if (!_canExecuteHierarchyMove) return;

    setState(() {
      _isMoving = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);

      // Bei gemischter Auswahl: Nur Gewerk ändern, Hierarchie bleibt unverändert
      String? targetParentId;
      if (!_areAllAnlagen && !_areAllBauteile) {
        targetParentId = null; // null bedeutet: nicht ändern
      } else {
        // Anlagen und Bauteile: Parent-Hierarchie bleibt unverändert
        targetParentId = null;
      }

      // Schema-Kompatibilität prüfen
      if (_selectedDiscipline!.label != widget.currentDiscipline.label) {
        final isCompatible = _areSchemasCompatible(
          widget.currentDiscipline,
          _selectedDiscipline!,
        );

        if (!isCompatible) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Schema-Unterschiede'),
              content: const Text(
                'Das Ziel-Gewerk hat ein anderes Schema. '
                'Einige Parameter könnten verloren gehen. Fortfahren?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Fortfahren'),
                ),
              ],
            ),
          );
          if (confirmed != true) {
            setState(() {
              _isMoving = false;
            });
            return;
          }
        }
      }

      // --- Parameter (Eingabefelder) präzise aktualisieren ---
      final projectId = await db.getProjectIdByBuildingId(widget.currentBuildingId);
      Map<String, dynamic> paramsToUpdate = {};

      if (projectId != null) {
        final csvSettings = await CsvSettings.loadForProject(projectId);

        // 1. Feld für Ebene 1 (Gewerk-Tab): Disziplin-Label
        final gewerkKey = csvSettings.resolveGewerkGroupingParamKey();
        if (gewerkKey.isNotEmpty && !csvSettings.isLeafNameParamKey(gewerkKey)) {
          paramsToUpdate[gewerkKey] = _selectedDiscipline!.label;
        }

        // 2. Listen-Blätter (parentId == null): Ziel aus Dropdown, Blatt-Name unangetastet
        if (_hasHierarchyMove && _areAllAnlagen) {
          _syncHierarchySelectionFromDropdowns();
          final ro = _effectiveRevisionsobjekt?.trim();
          if (ro != null && ro.isNotEmpty) {
            final rfKey = widget.revisionsfeldGroupingKey?.trim();
            final rf = rfKey != null && rfKey.isNotEmpty
                ? _effectiveRevisionsfeld?.trim()
                : null;
            final hierarchy = csvSettings.buildHierarchyLocationParams(
              revisionsfeld: rf,
              revisionsobjekt: ro,
            );
            hierarchy.forEach((key, value) {
              if (!csvSettings.isLeafNameParamKey(key)) {
                paramsToUpdate[key] = value;
              }
            });
          }
        }
      }

      // Verschiebe alle Anlagen (inkl. Kinder) - Stockwerk bleibt gleich
      if (!_areAllAnlagen && !_areAllBauteile) {
        // Gemischte Auswahl: Jede Anlage behält ihre aktuelle parentId
        for (final anlage in widget.anlagenToMove) {
          await db.moveAnlagen(
            [anlage.id],
            newFloorId: null, // Stockwerk bleibt unverändert
            newParentId: anlage.parentId, // Behalte aktuelle parentId
            newDiscipline: _disciplineForMove(),
            paramsToUpdate: paramsToUpdate.isNotEmpty ? paramsToUpdate : null,
          );
        }
      } else {
        // Einheitliche Auswahl: Alle bekommen die gleiche parentId
        await db.moveAnlagen(
          widget.anlagenToMove.map((a) => a.id).toList(),
          newFloorId: null, // Stockwerk bleibt unverändert
          newParentId: targetParentId,
          newDiscipline: _disciplineForMove(),
          paramsToUpdate: paramsToUpdate.isNotEmpty ? paramsToUpdate : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMoving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rfKey = widget.revisionsfeldGroupingKey?.trim();
    final showRevisionsfeldPicker =
        _hasHierarchyMove && rfKey != null && rfKey.isNotEmpty;
    final revisionsobjekte = _revisionsobjekteForSelectedFeld;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.placementMode
                      ? Icons.add_location_alt
                      : Icons.drive_file_move,
                  color: AppPalette.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.placementMode
                      ? 'Neue Anlage anlegen'
                      : '${widget.anlagenToMove.length} Element(e) verschieben',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            DropdownButtonFormField<Disziplin>(
              isExpanded: true,
              value: _availableDisciplines.firstWhere(
                (d) => d.label == _selectedDiscipline?.label,
                orElse: () => _availableDisciplines.first,
              ),
              decoration: InputDecoration(
                labelText: widget.placementMode ? 'Gewerk' : 'Ziel-Gewerk',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.category),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              selectedItemBuilder: (context) {
                return _availableDisciplines.map((d) {
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      d.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList();
              },
              items: _availableDisciplines.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (val) async {
                setState(() => _selectedDiscipline = val);
                if (_hasHierarchyMove && val != null) {
                  await _loadHierarchyTargets(
                    ref.read(databaseServiceProvider),
                    disciplineLabel: val.label,
                    disciplines: _availableDisciplines,
                  );
                }
              },
            ),
            if (_hasHierarchyMove) ...[
              const SizedBox(height: 16),
              if (showRevisionsfeldPicker) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _effectiveRevisionsfeld,
                  decoration: InputDecoration(
                    labelText: widget.placementMode
                        ? _revisionsfeldLabel
                        : 'Ziel-$_revisionsfeldLabel',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.folder_outlined),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  selectedItemBuilder: (context) {
                    return _sortedRevisionsfelder.map((rf) {
                      final label =
                          rf.isEmpty ? '(Ohne $_revisionsfeldLabel)' : rf;
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList();
                  },
                  items: _sortedRevisionsfelder.map((rf) {
                    final label = rf.isEmpty ? '(Ohne $_revisionsfeldLabel)' : rf;
                    return DropdownMenuItem(
                      value: rf,
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedRevisionsfeld = val;
                      final ros = _revisionsobjekteForSelectedFeld;
                      _selectedRevisionsobjekt =
                          ros.isNotEmpty ? ros.first : null;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (revisionsobjekte.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _effectiveRevisionsobjekt,
                  decoration: InputDecoration(
                    labelText: widget.placementMode
                        ? _revisionsobjektLabel
                        : 'Ziel-$_revisionsobjektLabel',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.account_tree_outlined),
                    helperText: widget.placementMode
                        ? 'Anschließend öffnet sich der Erfassungsdialog.'
                        : '$_revisionsfeldLabel und $_revisionsobjektLabel werden in den Datensätzen automatisch gesetzt.',
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  selectedItemBuilder: (context) {
                    return revisionsobjekte.map((ro) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          ro,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList();
                  },
                  items: revisionsobjekte
                      .map(
                        (ro) => DropdownMenuItem(
                          value: ro,
                          child: Text(
                            ro,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedRevisionsobjekt = val);
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Keine $_revisionsobjektLabel in den Gewerkevorlagen vorhanden.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (!_areAllAnlagen && !_areAllBauteile) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.warningSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppPalette.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gemischte Auswahl: Es kann nur das Gewerk geändert werden. Die Hierarchie bleibt unverändert.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_hasHierarchyMove && _areAllAnlagen) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.successSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppPalette.primaryDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anlagen bleiben auf der Hauptebene und können nicht unter andere Anlagen verschoben werden.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isMoving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isMoving || !_canExecuteHierarchyMove)
                        ? null
                        : _executeMove,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isMoving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.placementMode ? 'Erstellen' : 'Verschieben'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
