import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/building.dart';
import '../../models/floor_plan.dart';
import '../systems_page.dart';
import '../widgets/systems_list_tile_styles.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../models/disziplin_manager.dart';
import '../../database/database_service.dart';
import '../../utils/app_log.dart';

class TechnikMainTab extends StatefulWidget {
  final DatabaseService dbService;
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
  /// Neue Anlage anlegen (Verortung + Formular), auch wenn noch keine Gewerke in der DB sind.
  final Future<void> Function()? onAddAnlage;
  /// Gewerkevorlagen wurden im Projekt importiert (leere Übersicht mit + ermöglichen).
  final bool hasImportedTemplates;
  final bool Function()? isAnySelectionActive; // Callback um zu prüfen, ob bereits eine Selection aktiv ist
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
    required this.tabController,
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

    // Bei genau einem Gewerk: Anlagen direkt anzeigen, ohne aufklappbaren Reiter
    if (disziplinen.length == 1) {
      final discipline = disziplinen.first;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        child: SystemsPage(
          key: widget.systemsPageKeys[discipline],
          building: widget.building,
          floor: FloorPlan(id: 'global', name: 'Global'),
          discipline: discipline,
          groupingKey: widget.systemsGroupingKey,
          subGroupingKey: widget.systemsSubGroupingKey,
          displayNameParamKey: widget.systemsDisplayNameParamKey,
          usePrimaryScroll: true,
          onSelectionChanged: (isActive, count) {
            widget.onSelectionChanged?.call(isActive, count, discipline);
          },
          isAnySelectionActive: widget.isAnySelectionActive,
          onExitDisciplineSelectionMode: widget.onExitDisciplineSelectionMode,
          onAnlageCreated: widget.onAnlageCreated,
          onBauteilCreated: widget.onBauteilCreated,
          onAnlagenMoved: widget.onAnlagenMoved,
          onGroupLongPress: widget.onGroupLongPress,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88, top: 4),
      itemCount: disziplinen.length,
      itemBuilder: (context, index) {
        final discipline = disziplinen[index];
        final isExpanded = _expandedDisciplines.contains(discipline.label);

        final isSelected = widget.selectedDisciplineLabels.contains(discipline.label);

        final headerDecoration = SystemsListTileStyles.groupContainer(
          isExpanded: isExpanded || isSelected,
          level: SystemsOverviewLevel.discipline,
        );

        return GestureDetector(
          behavior: widget.disciplineSelectionMode
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onTap: widget.disciplineSelectionMode
              ? () => widget.onDisciplineSelectionToggle?.call(discipline)
              : null,
          onLongPress: widget.disciplineSelectionMode
              ? null
              : () => widget.onDisciplineLongPress?.call(discipline),
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: widget.disciplineSelectionMode && isSelected
              ? headerDecoration.copyWith(
                  border: Border.all(
                    color: SystemsOverviewPalette.borderExpanded,
                    width: 1.5,
                  ),
                )
              : headerDecoration,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey('discipline_${discipline.label}'),
              enabled: !widget.disciplineSelectionMode,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              leading: SystemsListTileStyles.disciplineLeading(
                discipline,
                expanded: isExpanded,
              ),
              title: Text(
                _capitalize(discipline.label),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isExpanded
                      ? SystemsOverviewPalette.primaryDark
                      : SystemsOverviewPalette.textPrimary,
                ),
              ),
              trailing: widget.disciplineSelectionMode
                  ? Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? SystemsOverviewPalette.primary
                          : SystemsOverviewPalette.iconMuted,
                      size: 24,
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
                  displayNameParamKey: widget.systemsDisplayNameParamKey,
                  onSelectionChanged: (isActive, count) {
                    widget.onSelectionChanged?.call(isActive, count, discipline);
                  },
                  isAnySelectionActive: widget.isAnySelectionActive,
                  onExitDisciplineSelectionMode: widget.onExitDisciplineSelectionMode,
                  onAnlageCreated: widget.onAnlageCreated,
                  onBauteilCreated: widget.onBauteilCreated,
                  onAnlagenMoved: widget.onAnlagenMoved,
                  onGroupLongPress: widget.onGroupLongPress,
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
