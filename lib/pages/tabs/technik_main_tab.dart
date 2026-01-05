import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/building.dart';
import '../../models/floor_plan.dart';
import '../systems_page.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../models/disziplin_manager.dart';
import '../../database/database_service.dart';

class TechnikMainTab extends StatefulWidget {
  final Building building;
  final int index;
  final TabController tabController; // Wird noch für Kompatibilität benötigt, aber nicht mehr verwendet
  final Map<Disziplin, GlobalKey<SystemsPageState>> systemsPageKeys;
  final Function(bool, int, Disziplin)? onSelectionChanged;
  final Function(Disziplin?)? onDisciplineExpanded; // Callback für geöffnete Disziplin
  final Function(Disziplin)? onDisciplineLongPress; // Long-Press auf Gewerk -> AppBar-Aktionsmodus
  final VoidCallback? onExitDisciplineSelectionMode; // Callback um Gewerk-Auswahl zu beenden
  final VoidCallback? onSchemaUpdated; // Callback für Schema-Update
  final Future<void> Function()? onImportCsv; // Callback für CSV-Import
  final bool Function()? isAnySelectionActive; // Callback um zu prüfen, ob bereits eine Selection aktiv ist
  final bool disciplineSelectionMode;
  final Set<String> selectedDisciplineLabels;
  final Function(Disziplin)? onDisciplineSelectionToggle;
  final VoidCallback? onAnlageCreated;
  final VoidCallback? onBauteilCreated;
  final VoidCallback? onAnlagenMoved;

  const TechnikMainTab({
    Key? key,
    required this.building,
    required this.index,
    required this.tabController,
    required this.systemsPageKeys,
    this.onSelectionChanged,
    this.onDisciplineExpanded,
    this.onDisciplineLongPress,
    this.onExitDisciplineSelectionMode,
    this.onSchemaUpdated,
    this.onImportCsv,
    this.isAnySelectionActive,
    this.disciplineSelectionMode = false,
    this.selectedDisciplineLabels = const {},
    this.onDisciplineSelectionToggle,
    this.onAnlageCreated,
    this.onBauteilCreated,
    this.onAnlagenMoved,
  }) : super(key: key);

  @override
  State<TechnikMainTab> createState() => _TechnikMainTabState();
}

class _TechnikMainTabState extends State<TechnikMainTab> with AutomaticKeepAliveClientMixin {
  final Set<String> _expandedDisciplines = {}; // Verfolgt alle geöffneten Disziplinen

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadExpandedState();
  }

  Future<void> _loadExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'expanded_disciplines_${widget.building.id}';
      final list = prefs.getStringList(key);
      if (list != null) {
        setState(() {
          _expandedDisciplines.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Expansion-Zustands: $e');
    }
  }

  Future<void> _saveExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'expanded_disciplines_${widget.building.id}';
      await prefs.setStringList(key, _expandedDisciplines.toList());
    } catch (e) {
      debugPrint('Fehler beim Speichern des Expansion-Zustands: $e');
    }
  }

  Future<void> _addDisziplin() async {
    final newDisziplin = await showDialog<Disziplin>(
      context: context,
      builder: (_) => const DisziplinEditDialog(),
    );

    if (newDisziplin != null) {
      try {
        final dbService = DatabaseService.instance;
        if (dbService == null) {
          throw Exception('DatabaseService nicht initialisiert');
        }
        await dbService.upsertDiscipline(widget.building.id, newDisziplin);
        
        // Callback aufrufen, um Disziplinen neu zu laden
        widget.onSchemaUpdated?.call();
      } catch (e) {
        debugPrint('Fehler beim Speichern der neuen Disziplin: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final disziplinen = widget.systemsPageKeys.keys.toList();

    // Wenn keine Disziplinen vorhanden sind, zeige leere Ansicht mit Buttons
    if (disziplinen.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Keine Gewerke vorhanden',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Erstelle ein neues Gewerk oder\nimportiere Anlagen über CSV',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline),
                label: Text('Gewerk erstellen'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _addDisziplin,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.download),
                label: Text('CSV importieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: widget.onImportCsv,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: disziplinen.length,
      itemBuilder: (context, index) {
        final discipline = disziplinen[index];
        final isExpanded = _expandedDisciplines.contains(discipline.label);

        final isSelected = widget.selectedDisciplineLabels.contains(discipline.label);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.disciplineSelectionMode
              ? () => widget.onDisciplineSelectionToggle?.call(discipline)
              : null,
          onLongPress: () {
            // Long-Press soll den AppBar-Aktionsmodus öffnen (Edit/Add/Delete)
            if (widget.onDisciplineLongPress != null) {
              widget.onDisciplineLongPress!(discipline);
            }
          },
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            // Feine Nuance für Gewerk: sehr subtiler bläulicher Ton
            color: Color.lerp(
              Colors.white,
              Color.lerp(discipline.color, Colors.blue.shade50, 0.3) ?? Colors.white,
              0.15,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.disciplineSelectionMode
                  ? (isSelected
                      ? discipline.color.withOpacity(0.6)
                      : Colors.grey.withOpacity(0.25))
                  : (isExpanded
                      ? discipline.color.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.15)),
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: discipline.color.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                key: ValueKey('${discipline.label}_$isExpanded'),
                enabled: !widget.disciplineSelectionMode,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isExpanded
                          ? [
                              discipline.color.withOpacity(0.2),
                              discipline.color.withOpacity(0.1),
                            ]
                          : [
                              discipline.color.withOpacity(0.15),
                              discipline.color.withOpacity(0.08),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: discipline.color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    discipline.icon,
                    color: discipline.color,
                    size: 24,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _capitalize(discipline.label),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? discipline.color : Colors.grey[900],
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: widget.disciplineSelectionMode
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? discipline.color.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? discipline.color : Colors.grey[500],
                          size: 22,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? discipline.color.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          color: isExpanded ? discipline.color : Colors.grey[600],
                          size: 24,
                        ),
                      ),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      // Füge die Disziplin hinzu, ohne andere zu schließen
                      _expandedDisciplines.add(discipline.label);
                      // Für FloatingActionButton: melde die zuletzt geöffnete Disziplin
                      widget.onDisciplineExpanded?.call(discipline);
                    } else {
                      _expandedDisciplines.remove(discipline.label);
                      // Wenn die Disziplin geschlossen wurde, null melden
                      widget.onDisciplineExpanded?.call(null);
                    }
                  });
                  _saveExpandedState();
                },
                children: [
                  Container(
                    decoration: BoxDecoration(
                      // Feine Nuance für Anlagen-Bereich: sehr subtiler gräulicher Ton
                      color: Color.lerp(
                        Colors.grey[50]!,
                        Color.lerp(discipline.color, Colors.grey.shade100, 0.2) ?? Colors.grey[50]!,
                        0.1,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: SystemsPage(
                      key: widget.systemsPageKeys[discipline],
                      building: widget.building,
                      floor: FloorPlan(id: 'global', name: 'Global'),
                      discipline: discipline,
                      onSelectionChanged: (isActive, count) {
                        if (widget.onSelectionChanged != null) {
                          widget.onSelectionChanged!(isActive, count, discipline);
                        }
                      },
                      isAnySelectionActive: widget.isAnySelectionActive,
                      onExitDisciplineSelectionMode: widget.onExitDisciplineSelectionMode,
                      onAnlageCreated: widget.onAnlageCreated,
                      onBauteilCreated: widget.onBauteilCreated,
                      onAnlagenMoved: widget.onAnlagenMoved,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
