/// Tab „Technik“: Gewerke-Übersicht mit eingebetteten [SystemsPage]-Instanzen.
///
/// Expand-Zustand der Disziplinen wird in SharedPreferences gemerkt.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';
import 'package:bestandsaufnahme_01/features/systems/pages/systems_page.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/systems_list_tile_styles.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_manager.dart';
import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';

/// Haupt-Tab der Anlagenübersicht (Gewerke → [SystemsPage]).
class TechnikMainTab extends StatefulWidget {
  final DatabaseService dbService;
  final Building building;
  final int index;
  final Map<Disziplin, GlobalKey<SystemsPageState>> systemsPageKeys;
  final Function(bool, int, Disziplin)? onSelectionChanged;
  /// Callback, wenn ein Gewerk aufgeklappt wird.
  final Function(Disziplin?)? onDisciplineExpanded;
  /// Long-Press auf Gewerk → AppBar-Aktionsmodus.
  final Function(Disziplin)? onDisciplineLongPress;
  /// Beendet die Gewerk-Mehrfachauswahl.
  final VoidCallback? onExitDisciplineSelectionMode;
  final VoidCallback? onSchemaUpdated;
  final Future<void> Function()? onImportCsv;
  /// Neue Anlage anlegen (Verortung + Formular), auch wenn noch keine Gewerke in der DB sind.
  final Future<void> Function()? onAddAnlage;
  /// Gewerkevorlagen wurden im Projekt importiert (leere Übersicht mit + ermöglichen).
  final bool hasImportedTemplates;
  /// true, wenn bereits eine Selection in einem anderen Gewerk aktiv ist.
  final bool Function()? isAnySelectionActive;
  final bool disciplineSelectionMode;
  final Set<String> selectedDisciplineLabels;
  final Function(Disziplin)? onDisciplineSelectionToggle;
  final VoidCallback? onAnlageCreated;
  final VoidCallback? onBauteilCreated;
  final VoidCallback? onAnlagenMoved;
  /// Wird bei Long-Press auf einen Gruppen-Header aufgerufen.
  final void Function(
    Disziplin discipline,
    String groupingKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
  )? onGroupLongPress;

  /// Gruppierungs-Key Ebene 2 (Revisionsfeld) aus CSV-Einstellungen.
  final String? systemsGroupingKey;

  /// Unter-Gruppierungs-Key (Revisionsobjekt) innerhalb der oberen Gruppierung.
  final String? systemsSubGroupingKey;

  /// Param-Key für Anzeigenamen einzelner Anlagen.
  final String? systemsDisplayNameParamKey;

  /// Anzeige-Labels aus CSV-Einstellungen (Gewerk / Blatt-Ebene).
  final String labelGewerk;
  final String labelLeafLevel;
  final String labelGewerkPlural;
  final String labelLeafLevelPlural;

  const TechnikMainTab({
    Key? key,
    required this.dbService,
    required this.building,
    required this.index,
    required this.systemsPageKeys,
    this.onSelectionChanged,
    this.onDisciplineExpanded,
    this.onDisciplineLongPress,
    this.onExitDisciplineSelectionMode,
    this.onSchemaUpdated,
    this.onImportCsv,
    this.onAddAnlage,
    this.hasImportedTemplates = false,
    this.isAnySelectionActive,
    this.disciplineSelectionMode = false,
    this.selectedDisciplineLabels = const {},
    this.onDisciplineSelectionToggle,
    this.onAnlageCreated,
    this.onBauteilCreated,
    this.onAnlagenMoved,
    this.onGroupLongPress,
    this.systemsGroupingKey,
    this.systemsSubGroupingKey,
    this.systemsDisplayNameParamKey,
    this.labelGewerk = 'Gewerk',
    this.labelLeafLevel = 'Anlage',
    this.labelGewerkPlural = 'Gewerke',
    this.labelLeafLevelPlural = 'Anlagen',
  }) : super(key: key);

  @override
  State<TechnikMainTab> createState() => _TechnikMainTabState();
}

/// State: Disziplin-Expand und Einbettung der SystemsPages.
class _TechnikMainTabState extends State<TechnikMainTab> {
  final Set<String> _expandedDisciplines = {}; // Verfolgt alle geöffneten Disziplinen

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
      appLog('Fehler beim Laden des Expansion-Zustands: $e');
    }
  }

  Future<void> _saveExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'expanded_disciplines_${widget.building.id}';
      await prefs.setStringList(key, _expandedDisciplines.toList());
    } catch (e) {
      appLog('Fehler beim Speichern des Expansion-Zustands: $e');
    }
  }

  Future<void> _addDisziplin() async {
    final newDisziplin = await showDialog<Disziplin>(
      context: context,
      builder: (_) => const DisziplinEditDialog(),
    );

    if (newDisziplin != null) {
      try {
        await widget.dbService.upsertDiscipline(widget.building.id, newDisziplin);
        
        // Callback aufrufen, um Disziplinen neu zu laden
        widget.onSchemaUpdated?.call();
      } catch (e) {
        appLog('Fehler beim Speichern der neuen Disziplin: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Keine ${widget.labelGewerkPlural} vorhanden',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                widget.hasImportedTemplates
                    ? 'Gewerkevorlagen sind importiert.\nLegen Sie eine ${widget.labelLeafLevel} an oder importieren Sie Bestand per CSV.'
                    : 'Erstelle ein neues ${widget.labelGewerk} oder\nimportiere ${widget.labelLeafLevelPlural} über CSV',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),
              if (widget.onAddAnlage != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('${widget.labelLeafLevel} hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SystemsOverviewPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: widget.onAddAnlage,
                ),
              if (widget.onAddAnlage != null) const SizedBox(height: 16),
              if (!widget.hasImportedTemplates)
                ElevatedButton.icon(
                  icon: Icon(Icons.add_circle_outline),
                  label: Text('${widget.labelGewerk} erstellen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _addDisziplin,
                ),
              if (!widget.hasImportedTemplates) const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.download),
                label: Text('CSV importieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SystemsOverviewPalette.surface,
                  foregroundColor: SystemsOverviewPalette.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: widget.onImportCsv,
              ),
            ],
          ),
        ),
      );
    }

    // Ebene 1 immer als Knoten zeigen (auch bei nur einem Gewerk),
    // damit gemeinsame Ebene-1-Werte (z. B. gleiches Revisionsfeld) sichtbar sind.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88, top: 4),
      itemCount: disziplinen.length,
      itemBuilder: (context, index) {
              final discipline = disziplinen[index];
              final isOnlyDiscipline = disziplinen.length == 1;
              final isExpanded = isOnlyDiscipline ||
                  _expandedDisciplines.contains(discipline.label);

              final isSelected =
                  widget.selectedDisciplineLabels.contains(discipline.label);

              return GestureDetector(
                behavior: widget.disciplineSelectionMode
                    ? HitTestBehavior.opaque
                    : HitTestBehavior.deferToChild,
                onTap: widget.disciplineSelectionMode
                    ? () =>
                        widget.onDisciplineSelectionToggle?.call(discipline)
                    : null,
                onLongPress: widget.disciplineSelectionMode
                    ? null
                    : () => widget.onDisciplineLongPress?.call(discipline),
                child: SystemsListTileStyles.groupShell(
                  context: context,
                  isExpanded: isExpanded || isSelected,
                  level: SystemsOverviewLevel.discipline,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  borderSide: widget.disciplineSelectionMode && isSelected
                      ? const BorderSide(
                          color: SystemsOverviewPalette.borderExpanded,
                          width: 1.5,
                        )
                      : null,
                  child: ExpansionTile(
                    key: ValueKey('discipline_${discipline.label}'),
                    enabled: !widget.disciplineSelectionMode,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: SystemsListTileStyles.disciplineLeading(
                      discipline,
                      expanded: isExpanded,
                    ),
                    title: Text(
                      _capitalize(discipline.label),
                      style: SystemsListTileStyles.titleStyleEmphasized.copyWith(
                        color: isExpanded
                            ? SystemsOverviewPalette.primaryDark
                            : SystemsOverviewPalette.textPrimary,
                      ),
                    ),
                    trailing: widget.disciplineSelectionMode
                        ? Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? SystemsOverviewPalette.primary
                                : SystemsOverviewPalette.iconMuted,
                            size: SystemsListTileStyles.chevronSize,
                          )
                        : SystemsListTileStyles.expandIcon(
                            isExpanded: isExpanded,
                            level: SystemsOverviewLevel.discipline,
                          ),
                    onExpansionChanged: widget.disciplineSelectionMode
                        ? null
                        : (expanded) {
                            setState(() {
                              if (expanded) {
                                _expandedDisciplines.add(discipline.label);
                                widget.onDisciplineExpanded?.call(discipline);
                              } else {
                                _expandedDisciplines.remove(discipline.label);
                                widget.onDisciplineExpanded?.call(null);
                              }
                            });
                            _saveExpandedState();
                          },
                    initiallyExpanded: isExpanded,
                    children: [
                      SystemsPage(
                        key: widget.systemsPageKeys[discipline],
                        building: widget.building,
                        floor: FloorPlan(id: 'global', name: 'Global'),
                        discipline: discipline,
                        groupingKey: widget.systemsGroupingKey,
                        subGroupingKey: widget.systemsSubGroupingKey,
                        displayNameParamKey:
                            widget.systemsDisplayNameParamKey,
                        onSelectionChanged: (isActive, count) {
                          widget.onSelectionChanged
                              ?.call(isActive, count, discipline);
                        },
                        isAnySelectionActive: widget.isAnySelectionActive,
                        onExitDisciplineSelectionMode:
                            widget.onExitDisciplineSelectionMode,
                        onAnlageCreated: widget.onAnlageCreated,
                        onBauteilCreated: widget.onBauteilCreated,
                        onAnlagenMoved: widget.onAnlagenMoved,
                        onGroupLongPress: widget.onGroupLongPress,
                      ),
                    ],
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
