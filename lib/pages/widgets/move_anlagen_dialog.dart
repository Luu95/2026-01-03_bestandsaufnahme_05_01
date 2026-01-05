// lib/pages/widgets/move_anlagen_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/database_provider.dart';

class MoveAnlagenDialog extends ConsumerStatefulWidget {
  final List<Anlage> anlagenToMove;
  final String currentBuildingId;
  final String currentFloorId;
  final Disziplin currentDiscipline;

  const MoveAnlagenDialog({
    Key? key,
    required this.anlagenToMove,
    required this.currentBuildingId,
    required this.currentFloorId,
    required this.currentDiscipline,
  }) : super(key: key);

  @override
  ConsumerState<MoveAnlagenDialog> createState() => _MoveAnlagenDialogState();
}

class _MoveAnlagenDialogState extends ConsumerState<MoveAnlagenDialog> {
  String? _selectedParentId; // "root" bedeutet oberste Ebene, null ist initial
  Disziplin? _selectedDiscipline;

  List<Anlage> _potentialParents = [];
  List<Disziplin> _availableDisciplines = [];

  bool _isLoading = true;
  bool _isMoving = false;

  // Prüfe, ob alle zu verschiebenden Elemente Anlagen (parentId == null) oder Bauteile sind
  bool get _areAllAnlagen {
    return widget.anlagenToMove.every((a) => a.parentId == null);
  }

  bool get _areAllBauteile {
    return widget.anlagenToMove.every((a) => a.parentId != null);
  }

  @override
  void initState() {
    super.initState();
    _selectedDiscipline = widget.currentDiscipline;
    // Wenn es nur Anlagen sind, müssen sie auf Hauptebene bleiben (root)
    // Wenn es nur Bauteile sind, müssen sie unter eine Anlage (kein root erlaubt)
    if (_areAllAnlagen) {
      _selectedParentId = 'root';
    } else if (_areAllBauteile) {
      _selectedParentId = null; // Muss später eine Anlage ausgewählt werden
    } else {
      // Gemischt - nicht erlaubt, aber setze trotzdem root
      _selectedParentId = 'root';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseServiceProvider);

    // Verfügbare Disziplinen laden
    final disciplines = await db.getDisciplinesByBuildingId(widget.currentBuildingId);

    if (mounted) {
      setState(() {
        _availableDisciplines = disciplines;
        _isLoading = false;
      });
      // Nur Parent-Liste laden, wenn es nicht gemischt ist
      if (_areAllAnlagen || _areAllBauteile) {
        await _loadPotentialParents();
      }
    }
  }

  Future<void> _loadPotentialParents() async {
    if (_selectedDiscipline == null) return;

    final db = ref.read(databaseServiceProvider);
    // Lade alle Anlagen des Ziel-Gewerks und des aktuellen Stockwerks
    final allInScope = await db.getAnlagenByBuildingIdAndDiscipline(
      widget.currentBuildingId,
      _selectedDiscipline!.label,
    );

    // Filtere nach aktuellem Stockwerk (bleibt gleich)
    final onFloor = (widget.currentFloorId == 'global')
        ? allInScope
        : allInScope.where((a) => a.floorId == widget.currentFloorId).toList();

    // Filtere Zirkelbezüge (inkl. rekursiver Prüfung)
    final movingIds = widget.anlagenToMove.map((a) => a.id).toSet();
    final validParents = <Anlage>[];

    for (final potentialParent in onFloor) {
      // Prüfe rekursiv, ob dieser Parent zu den zu verschiebenden gehört
      final wouldCreateCircular = await _wouldCreateCircularReference(
        potentialParent.id,
        movingIds,
      );

      if (!wouldCreateCircular && !movingIds.contains(potentialParent.id)) {
        // Nur Haupt-Anlagen (ohne parentId) können Eltern sein
        if (potentialParent.parentId == null) {
          validParents.add(potentialParent);
        }
      }
    }

    setState(() {
      _potentialParents = validParents;
      // Reset Parent, falls ungültig
      if (_areAllAnlagen) {
        // Anlagen müssen immer auf Hauptebene bleiben
        _selectedParentId = 'root';
      } else if (_areAllBauteile) {
        // Bauteile müssen unter eine Anlage - setze erste verfügbare, falls keine ausgewählt
        if (_selectedParentId == null ||
            _selectedParentId == 'root' ||
            !validParents.any((p) => p.id == _selectedParentId)) {
          _selectedParentId = validParents.isNotEmpty ? validParents.first.id : null;
        }
      }
      // Bei gemischter Auswahl wird _selectedParentId nicht verwendet
    });
  }

  Future<bool> _wouldCreateCircularReference(
    String potentialParentId,
    Set<String> movingIds,
  ) async {
    // Prüfe direkt: Ist das Parent selbst in der zu verschiebenden Liste?
    if (movingIds.contains(potentialParentId)) return true;

    // Rekursiv: Prüfe alle Vorfahren des potentialParent
    String? currentParentId = potentialParentId;
    final visited = <String>{};

    final db = ref.read(databaseServiceProvider);

    while (currentParentId != null && !visited.contains(currentParentId)) {
      visited.add(currentParentId);

      // Ist dieser Vorfahre in der zu verschiebenden Liste?
      if (movingIds.contains(currentParentId)) return true;

      // Lade Parent und gehe eine Ebene höher
      final parent = await db.getAnlageById(currentParentId);
      currentParentId = parent?.parentId;
    }

    return false;
  }

  bool _areSchemasCompatible(Disziplin source, Disziplin target) {
    final sourceKeys = source.schema.map((e) => e['key']).toSet();
    final targetKeys = target.schema.map((e) => e['key']).toSet();

    // Prüfe, ob alle belegten Parameter im Ziel-Schema existieren
    // (Vereinfacht: Hier könnte man auch eine Warnung statt Fehler zeigen)
    return targetKeys.containsAll(sourceKeys) ||
        sourceKeys.intersection(targetKeys).length > 0;
  }

  Future<void> _executeMove() async {
    if (_selectedDiscipline == null) return;

    // Validierung: Anlagen können nicht unter andere Anlagen
    if (_areAllAnlagen && _selectedParentId != null && _selectedParentId != 'root') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anlagen können nicht unter andere Anlagen verschoben werden.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validierung: Bauteile müssen unter eine Anlage
    if (_areAllBauteile &&
        (_selectedParentId == null ||
            _selectedParentId == 'root' ||
            !_potentialParents.any((p) => p.id == _selectedParentId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bauteile müssen einer Anlage zugeordnet werden.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isMoving = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      
      // Bei gemischter Auswahl: Nur Gewerk ändern, Hierarchie bleibt unverändert
      String? targetParentId;
      if (!_areAllAnlagen && !_areAllBauteile) {
        // Gemischte Auswahl: Behalte die aktuelle parentId jeder Anlage
        // (wird in moveAnlagen nicht gesetzt, wenn newParentId == null)
        targetParentId = null; // null bedeutet: nicht ändern
      } else if (_areAllAnlagen) {
        // Nur Anlagen: Immer auf Hauptebene (null)
        targetParentId = null;
      } else {
        // Nur Bauteile: Neue parentId setzen
        targetParentId = _selectedParentId;
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

      // Verschiebe alle Anlagen (inkl. Kinder) - Stockwerk bleibt gleich
      if (!_areAllAnlagen && !_areAllBauteile) {
        // Gemischte Auswahl: Jede Anlage behält ihre aktuelle parentId
        // Verschiebe jede Anlage einzeln mit ihrer aktuellen parentId
        for (final anlage in widget.anlagenToMove) {
          await db.moveAnlagen(
            [anlage.id],
            newFloorId: null, // Stockwerk bleibt unverändert
            newParentId: anlage.parentId, // Behalte aktuelle parentId
            newDiscipline: _selectedDiscipline,
          );
        }
      } else {
        // Einheitliche Auswahl: Alle bekommen die gleiche parentId
        await db.moveAnlagen(
          widget.anlagenToMove.map((a) => a.id).toList(),
          newFloorId: null, // Stockwerk bleibt unverändert
          newParentId: targetParentId,
          newDiscipline: _selectedDiscipline,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.anlagenToMove.length} Element(e) verschoben',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Verschieben: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isMoving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
            // 1. Ziel-Gewerk Auswahl
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
              onChanged: (val) {
                setState(() {
                  _selectedDiscipline = val;
                  // Reset Parent bei Gewerk-Wechsel entsprechend der Regeln
                  if (_areAllAnlagen) {
                    _selectedParentId = 'root';
                  } else if (_areAllBauteile) {
                    _selectedParentId = null; // Wird beim Laden der Parents gesetzt
                  }
                  // Bei gemischter Auswahl wird _selectedParentId nicht verwendet
                });
                // Nur Parent-Liste laden, wenn es nicht gemischt ist
                if (_areAllAnlagen || _areAllBauteile) {
                  _loadPotentialParents();
                }
              },
            ),
            const SizedBox(height: 16),

            // 2. Ziel-Übergeordnete Anlage (Parent)
            // Bei gemischter Auswahl: Nur Gewerk-Wechsel erlaubt, keine Parent-Auswahl
            if (!_areAllAnlagen && !_areAllBauteile) ...[
              // Warnung bei gemischter Auswahl
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
              // Nur Bauteile: Parent-Auswahl erforderlich
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
                          !_potentialParents.any((p) => p.id == _selectedParentId)
                      ? 'Bitte wähle eine Anlage aus'
                      : null,
                ),
                items: _potentialParents.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedParentId = val;
                  });
                },
              ),
            ] else ...[
              // Nur Anlagen: Zeige Info, dass sie auf Hauptebene bleiben
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
                    onPressed: _isMoving ? null : _executeMove,
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

