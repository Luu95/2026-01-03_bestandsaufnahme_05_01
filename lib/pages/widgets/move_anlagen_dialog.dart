// lib/pages/widgets/move_anlagen_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/csv_settings_provider.dart';
import '../../database/database_service.dart';
import '../../providers/database_provider.dart';
import '../../services/template_service.dart';

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

  const MoveAnlagenDialog({
    Key? key,
    required this.anlagenToMove,
    required this.currentBuildingId,
    required this.currentFloorId,
    required this.currentDiscipline,
    this.projectId,
    this.revisionsfeldGroupingKey,
    this.revisionsobjektGroupingKey,
  }) : super(key: key);

  @override
  ConsumerState<MoveAnlagenDialog> createState() => _MoveAnlagenDialogState();
}

class _MoveAnlagenDialogState extends ConsumerState<MoveAnlagenDialog> {
  String? _selectedParentId; // "root" bedeutet oberste Ebene, null ist initial
  Disziplin? _selectedDiscipline;

  List<Anlage> _potentialParents = [];
  List<Disziplin> _availableDisciplines = [];

  CsvSettings? _csvSettings;
  String? _selectedRevisionsfeld;
  String? _selectedRevisionsobjekt;
  /// Revisionsfeld → bekannte Revisionsobjekte im Gebäude.
  Map<String, Set<String>> _locationTargets = {};

  bool _isLoading = true;
  bool _isMoving = false;

  bool get _areAllAnlagen {
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
    if (_areAllAnlagen) {
      _selectedParentId = 'root';
    } else if (_areAllBauteile) {
      _selectedParentId = null;
    } else {
      _selectedParentId = 'root';
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
      if (_areAllAnlagen || _areAllBauteile) {
        await _loadPotentialParents();
      }
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

    // Aktuelle Verortung der zu verschiebenden Elemente als Vorauswahl
    String? initialRf;
    String? initialRo;
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

  Future<void> _loadPotentialParents() async {
    if (_selectedDiscipline == null) return;

    final db = ref.read(databaseServiceProvider);
    final allInScope = await db.getAnlagenByBuildingIdAndDiscipline(
      widget.currentBuildingId,
      _selectedDiscipline!.label,
    );

    final onFloor = (widget.currentFloorId == 'global')
        ? allInScope
        : allInScope.where((a) => a.floorId == widget.currentFloorId).toList();

    final movingIds = widget.anlagenToMove.map((a) => a.id).toSet();
    final validParents = <Anlage>[];

    for (final potentialParent in onFloor) {
      final wouldCreateCircular = await _wouldCreateCircularReference(
        potentialParent.id,
        movingIds,
      );

      if (!wouldCreateCircular && !movingIds.contains(potentialParent.id)) {
        if (potentialParent.parentId == null) {
          validParents.add(potentialParent);
        }
      }
    }

    setState(() {
      _potentialParents = validParents;
      if (_areAllAnlagen) {
        _selectedParentId = 'root';
      } else if (_areAllBauteile) {
        if (_selectedParentId == null ||
            _selectedParentId == 'root' ||
            !validParents.any((p) => p.id == _selectedParentId)) {
          _selectedParentId =
              validParents.isNotEmpty ? validParents.first.id : null;
        }
      }
    });
  }

  Future<bool> _wouldCreateCircularReference(
    String potentialParentId,
    Set<String> movingIds,
  ) async {
    if (movingIds.contains(potentialParentId)) return true;

    String? currentParentId = potentialParentId;
    final visited = <String>{};
    final db = ref.read(databaseServiceProvider);

    while (currentParentId != null && !visited.contains(currentParentId)) {
      visited.add(currentParentId);
      if (movingIds.contains(currentParentId)) return true;
      final parent = await db.getAnlageById(currentParentId);
      currentParentId = parent?.parentId;
    }

    return false;
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

  /// Param-Updates für Eingabefelder (Revisionsfeld / Revisionsobjekt / Aliase).
  Map<String, dynamic>? _buildParamsToUpdate({String? targetParentId}) {
    final csv = _csvSettings;
    if (csv == null) return null;

    if (_hasHierarchyMove) {
      final ro = _effectiveRevisionsobjekt?.trim();
      if (ro == null || ro.isEmpty) return null;
      final rfKey = widget.revisionsfeldGroupingKey?.trim();
      final rf = rfKey != null && rfKey.isNotEmpty
          ? _effectiveRevisionsfeld?.trim()
          : null;
      return csv.buildHierarchyLocationParams(
        revisionsfeld: rf,
        revisionsobjekt: ro,
      );
    }

    // Bauteile mit parentId: Verortung vom Ziel-Parent übernehmen.
    if (_areAllBauteile &&
        targetParentId != null &&
        targetParentId != 'root') {
      try {
        final parent =
            _potentialParents.firstWhere((p) => p.id == targetParentId);
        final ro = csv.revisionsobjektValueFromParams(parent.params)?.trim();
        if (ro == null || ro.isEmpty) return null;
        final rf = csv.revisionsfeldValueFromParams(parent.params);
        return csv.buildHierarchyLocationParams(
          revisionsfeld: rf,
          revisionsobjekt: ro,
        );
      } catch (_) {}
    }

    return null;
  }

  Future<void> _executeMove() async {
    if (_selectedDiscipline == null) return;
    if (!_canExecuteHierarchyMove) return;

    if (_areAllAnlagen && _selectedParentId != null && _selectedParentId != 'root') {
      return;
    }

    if (_areAllBauteile &&
        (_selectedParentId == null ||
            _selectedParentId == 'root' ||
            !_potentialParents.any((p) => p.id == _selectedParentId))) {
      return;
    }

    setState(() {
      _isMoving = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      _syncHierarchySelectionFromDropdowns();

      String? targetParentId;
      if (!_areAllAnlagen && !_areAllBauteile) {
        targetParentId = null;
      } else if (_areAllAnlagen) {
        targetParentId = null;
      } else {
        targetParentId = _selectedParentId;
      }

      final targetDiscipline = _disciplineForMove();
      final paramsToUpdate = _buildParamsToUpdate(targetParentId: targetParentId);

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

      if (!_areAllAnlagen && !_areAllBauteile) {
        for (final anlage in widget.anlagenToMove) {
          await db.moveAnlagen(
            [anlage.id],
            newFloorId: null,
            newParentId: anlage.parentId,
            newDiscipline: targetDiscipline,
            paramsToUpdate: paramsToUpdate,
          );
        }
      } else {
        await db.moveAnlagen(
          widget.anlagenToMove.map((a) => a.id).toList(),
          newFloorId: null,
          newParentId: targetParentId,
          newDiscipline: targetDiscipline,
          paramsToUpdate: paramsToUpdate,
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.drive_file_move,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.anlagenToMove.length} Element(e) verschieben',
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
              value: _availableDisciplines.firstWhere(
                (d) => d.label == _selectedDiscipline?.label,
                orElse: () => _availableDisciplines.first,
              ),
              decoration: InputDecoration(
                labelText: 'Ziel-Gewerk',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.category),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _availableDisciplines.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Row(
                    children: [
                      Icon(d.icon, color: d.color, size: 20),
                      const SizedBox(width: 12),
                      Text(d.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) async {
                setState(() {
                  _selectedDiscipline = val;
                  if (_areAllAnlagen) {
                    _selectedParentId = 'root';
                  } else if (_areAllBauteile) {
                    _selectedParentId = null;
                  }
                });
                if (_hasHierarchyMove && val != null) {
                  await _loadHierarchyTargets(
                    ref.read(databaseServiceProvider),
                    disciplineLabel: val.label,
                    disciplines: _availableDisciplines,
                  );
                }
                if (_areAllAnlagen || _areAllBauteile) {
                  await _loadPotentialParents();
                }
              },
            ),
            if (_hasHierarchyMove) ...[
              const SizedBox(height: 16),
              if (showRevisionsfeldPicker) ...[
                DropdownButtonFormField<String>(
                  value: _effectiveRevisionsfeld,
                  decoration: InputDecoration(
                    labelText: 'Ziel-$_revisionsfeldLabel',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.folder_outlined),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: _sortedRevisionsfelder.map((rf) {
                    final label = rf.isEmpty ? '(Ohne $_revisionsfeldLabel)' : rf;
                    return DropdownMenuItem(value: rf, child: Text(label));
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
              DropdownButtonFormField<String>(
                value: _effectiveRevisionsobjekt,
                decoration: InputDecoration(
                  labelText: 'Ziel-$_revisionsobjektLabel',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.account_tree_outlined),
                  helperText:
                      '$_revisionsfeldLabel und $_revisionsobjektLabel werden in den Datensätzen automatisch gesetzt.',
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: revisionsobjekte.isEmpty
                      ? 'Keine Ziele vorhanden'
                      : null,
                ),
                items: revisionsobjekte
                    .map((ro) => DropdownMenuItem(value: ro, child: Text(ro)))
                    .toList(),
                onChanged: revisionsobjekte.isEmpty
                    ? null
                    : (val) {
                        setState(() => _selectedRevisionsobjekt = val);
                      },
              ),
            ],
            const SizedBox(height: 16),
            if (!_areAllAnlagen && !_areAllBauteile) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gemischte Auswahl: Es kann nur das Gewerk geändert werden. Die Hierarchie bleibt unverändert.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_areAllBauteile) ...[
              DropdownButtonFormField<String>(
                value: _potentialParents.any((p) => p.id == _selectedParentId)
                    ? _selectedParentId
                    : (_potentialParents.isNotEmpty
                        ? _potentialParents.first.id
                        : null),
                decoration: InputDecoration(
                  labelText: 'Zuordnen zu (Parent)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.account_tree),
                  helperText: 'Bauteile müssen einer Anlage zugeordnet werden.',
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: _selectedParentId == null ||
                          _selectedParentId == 'root' ||
                          !_potentialParents
                              .any((p) => p.id == _selectedParentId)
                      ? 'Bitte wähle eine Anlage aus'
                      : null,
                ),
                items: _potentialParents
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedParentId = val;
                  });
                },
              ),
            ] else if (!_hasHierarchyMove) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anlagen bleiben auf der Hauptebene und können nicht unter andere Anlagen verschoben werden.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
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
                      backgroundColor: Colors.blue[600],
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
                        : const Text('Verschieben'),
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
