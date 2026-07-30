/// lib/pages/systems_page.dart


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/anlage.dart';
import '../models/building.dart';
import '../models/floor_plan.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/database_provider.dart';
import '../providers/csv_settings_provider.dart';
import '../services/anlage_validation_service.dart';
import '../services/template_service.dart';

// Widgets für Anlage-Dialoge (relativ zu lib/pages/)
import 'widgets/generic_anlage_dialog.dart';
import 'widgets/move_anlagen_dialog.dart';
import 'widgets/anlage_hierarchical_item.dart';
import 'widgets/systems_anlage_list.dart';
import 'systems_ui_store.dart';
import '../utils/app_log.dart';
import '../navigation/route_observer.dart';

class SystemsPage extends ConsumerStatefulWidget {
  final Building building; // Das Gebäude, für das die Anlagen angezeigt werden sollen
  final FloorPlan floor;   // Der Plan des Floors, auf dem die Anlagen zu finden sind
  final Disziplin discipline; // Die Disziplin, für die Anlagen angezeigt werden

  /// Optionaler globaler Gruppierungs-Key, der von außen (Gebäude-Header) gesetzt wird.
  /// Wenn null oder leer, erfolgt keine Gruppierung.
  final String? groupingKey;

  /// Unter-Gruppierungs-Key (Revisionsobjekt) innerhalb der oberen Gruppierung.
  final String? subGroupingKey;

  /// Param-Key für Anzeigenamen einzelner Anlagen (Name-Spalte).
  final String? displayNameParamKey;

  /// Callback, um Selektion (aktiv, count) nach außen zu melden.
  final void Function(bool isActive, int selectedCount)? onSelectionChanged;
  
  /// Callback, um zu prüfen, ob bereits eine Selection in einem anderen Gewerk aktiv ist.
  final bool Function()? isAnySelectionActive;

  /// Callback, um die Gewerk-Auswahl zu beenden (wird aufgerufen, wenn eine Anlage gedrückt gehalten wird)
  final VoidCallback? onExitDisciplineSelectionMode;

  /// Wird aufgerufen, wenn eine neue Anlage (Parent) gespeichert wurde.
  final VoidCallback? onAnlageCreated;

  /// Wird aufgerufen, wenn ein neues Bauteil (Child) gespeichert wurde (auch bei Bulk-Add).
  final VoidCallback? onBauteilCreated;

  /// Wird aufgerufen, wenn Anlagen verschoben wurden (für Neuladen aller betroffenen Gewerke).
  final VoidCallback? onAnlagenMoved;
  /// Wird bei Long-Press auf einen Gruppen-Header aufgerufen (Disziplin, groupingKey, groupValue).
  final void Function(
    Disziplin discipline,
    String groupingKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
  )? onGroupLongPress;

  /// Eigene Scroll-Liste (statt shrinkWrap in übergeordnetem ScrollView).
  final bool usePrimaryScroll;

  const SystemsPage({
    Key? key,
    required this.building,
    required this.floor,
    required this.discipline,
    this.groupingKey,
    this.subGroupingKey,
    this.displayNameParamKey,
    this.usePrimaryScroll = false,
    this.onSelectionChanged,
    this.isAnySelectionActive,
    this.onExitDisciplineSelectionMode,
    this.onAnlageCreated,
    this.onBauteilCreated,
    this.onAnlagenMoved,
    this.onGroupLongPress,
  }) : super(key: key);

  @override
  ConsumerState<SystemsPage> createState() => SystemsPageState();
}

class SystemsPageState extends ConsumerState<SystemsPage>
    with RouteAware, TickerProviderStateMixin {
  List<Anlage> _alleAnlagen = [];  // Liste aller Anlagen im aktuellen Gebäude und auf dem aktuellen Floor
  List<Anlage> _parentAnlagen = [];
  Map<String, List<Anlage>> _childrenByParentId = {};
  CsvSettings? _cachedCsvSettings;
  String? _cachedProjectId;
  final Map<String, bool> _validationByAnlageId = {};
  bool _isSelectionMode = false;    // Gibt an, ob sich die Seite im Auswahlmodus befindet
  bool _isLoading = false;           // Gibt an, ob die Anlagen gerade geladen werden
  bool _hasLoadedOnce = false;       // Gibt an, ob die Daten bereits einmal geladen wurden
  final Set<String> _selectedAnlagenIds = {};  // Enthält die IDs der selektierten Anlagen
  final Set<String> _expandedGroups = {}; // Verfolgt geöffnete Untergruppen
  final Set<String> _expandedAnlagenIds = {}; // Verfolgt geöffnete Anlagen (für Bauteile)
  String? _lastOpenedAnlageId; // ID der zuletzt geöffneten Anlage
  final Map<String, GlobalKey> _anlageKeys = {}; // GlobalKeys für jedes Anlage-Item zum Scrollen
  bool _hasScrolledToLastOpened = false; // Verfolgt, ob bereits zur zuletzt angesehenen Anlage gescrollt wurde

  late final AnimationController _rotationController;  // Controller für die Rotation bei Auswahlmodus

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Dauer der Animation
    );

    _loadAnlagen(); // Lädt alle Anlagen, wenn die Seite geladen wird
    _loadExpandedGroups();
    _loadLastOpenedAnlage();
    _loadHasScrolledFlag();
  }

  Future<void> _loadExpandedGroups() async {
    // UI-State nur in-memory (keine SharedPreferences / keine DB)
    final loaded = SystemsUiStore.getExpandedGroups(
      widget.building.id,
      widget.discipline.label,
    );
    if (!mounted) return;
    setState(() {
      _expandedGroups
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _saveExpandedGroups() async {
    // UI-State nur in-memory (keine SharedPreferences / keine DB)
    SystemsUiStore.setExpandedGroups(
      widget.building.id,
      widget.discipline.label,
      _expandedGroups,
    );
  }

  /// Lädt die ID der zuletzt geöffneten Anlage (gewerkübergreifend, in-memory)
  Future<void> _loadLastOpenedAnlage() async {
    final lastOpenedId = SystemsUiStore.getLastOpenedAnlageId(
      widget.building.id,
      widget.floor.id,
    );
    if (!mounted) return;
    setState(() {
      // Prüfe, ob die Anlage in der aktuellen Liste existiert
      if (lastOpenedId != null && _alleAnlagen.any((a) => a.id == lastOpenedId)) {
        _lastOpenedAnlageId = lastOpenedId;
      } else {
        // Wenn die Anlage nicht in der aktuellen Liste existiert, entferne die Markierung
        // (z.B. weil sie zu einem anderen Gewerk gehört oder gelöscht wurde)
        _lastOpenedAnlageId = null;
      }
    });
  }

  /// Speichert die ID der zuletzt geöffneten Anlage (gewerkübergreifend, in-memory)
  Future<void> _saveLastOpenedAnlage(String anlageId) async {
    SystemsUiStore.setLastOpenedAnlageId(widget.building.id, widget.floor.id, anlageId);

    // Setze den Scroll-Flag für alle Gewerke zurück, wenn eine neue Anlage geöffnet wird
    await _resetHasScrolledFlagForAllDisciplines();

    if (!mounted) return;
    setState(() {
      _lastOpenedAnlageId = anlageId;
      _hasScrolledToLastOpened = false;
    });
  }

  /// Lädt den Flag, ob bereits zur zuletzt angesehenen Anlage gescrollt wurde
  Future<void> _loadHasScrolledFlag() async {
    final hasScrolled = SystemsUiStore.getHasScrolledToLast(
      widget.building.id,
      widget.discipline.label,
      widget.floor.id,
    );
    if (!mounted) return;
    setState(() {
      _hasScrolledToLastOpened = hasScrolled;
    });
  }

  /// Speichert den Flag, ob bereits zur zuletzt angesehenen Anlage gescrollt wurde
  Future<void> _saveHasScrolledFlag() async {
    SystemsUiStore.setHasScrolledToLast(
      widget.building.id,
      widget.discipline.label,
      widget.floor.id,
      true,
    );
    if (!mounted) return;
    setState(() {
      _hasScrolledToLastOpened = true;
    });
  }

  /// Setzt den Scroll-Flag für alle Gewerke zurück (wird aufgerufen, wenn eine neue Anlage geöffnet wird)
  Future<void> _resetHasScrolledFlagForAllDisciplines() async {
    SystemsUiStore.resetHasScrolledForBuildingFloor(widget.building.id, widget.floor.id);
  }

  /// Scrollt zur zuletzt geöffneten Anlage nach dem Build (nur beim ersten Öffnen)
  void _scrollToLastOpenedAnlage() {
    // Nur scrollen, wenn noch nicht gescrollt wurde
    if (_hasScrolledToLastOpened) {
      return;
    }
    
    if (_lastOpenedAnlageId != null) {
      // Prüfe, ob die Anlage noch in der Liste existiert
      final anlageExists = _alleAnlagen.any((a) => a.id == _lastOpenedAnlageId);
      if (!anlageExists) {
        // Anlage existiert nicht mehr, entferne die Markierung
        setState(() {
          _lastOpenedAnlageId = null;
        });
        return;
      }

      final anlage = _alleAnlagen.firstWhere((a) => a.id == _lastOpenedAnlageId);
      
      // Wenn die Anlage ein Parent hat, stelle sicher, dass der Parent aufgeklappt ist
      if (anlage.parentId != null) {
        setState(() {
          _expandedAnlagenIds.add(anlage.parentId!);
        });
      }

      // Gruppierung / Gruppenexpansion wird außerhalb der SystemsPage gesteuert

      final key = _anlageKeys[_lastOpenedAnlageId];
      if (key != null) {
        // Warte etwas länger, damit Gruppen/Expand-Animationen abgeschlossen sind
        Future.delayed(const Duration(milliseconds: 200), () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (key.currentContext != null && mounted) {
              Scrollable.ensureVisible(
                key.currentContext!,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: 0.2, // Zeigt die Anlage im oberen Drittel des Bildschirms
              );
              // Markiere, dass gescrollt wurde
              _saveHasScrolledFlag();
            }
          });
        });
      }
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!); // Beobachtet Routenwechsel
  }

  @override
  void didUpdateWidget(covariant SystemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn das Gebäude, die Disziplin oder der Floor sich ändern, wird die Liste neu geladen
    if (oldWidget.building.id != widget.building.id ||
        oldWidget.discipline.label != widget.discipline.label ||
        oldWidget.floor.id != widget.floor.id) {
      _hasLoadedOnce = false; // Reset, damit Platzhalter nicht während des Ladens angezeigt wird
      _loadAnlagen();
      _loadExpandedGroups();
      _loadLastOpenedAnlage(); // Lade die zuletzt geöffnete Anlage für den neuen Kontext
      _loadHasScrolledFlag(); // Lade den Scroll-Flag für das neue Gewerk
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // Aufräumen der Route-Beobachtung
    _rotationController.dispose(); // Aufräumen der Animation
    super.dispose();
  }

  @override
  void didPopNext() {
    // Beim Zurückkommen von Navigator.push, wird die Liste neu geladen
    _loadAnlagen().then((_) {
      // Markierung gewerkeübergreifend neu laden (falls sich in einem anderen Gewerk geändert)
      _loadLastOpenedAnlage().then((_) {
        // Nach dem Laden zur zuletzt geöffneten Anlage scrollen (nur beim ersten Öffnen)
        _scrollToLastOpenedAnlage();
      });
    });
  }

  @override
  void didPushNext() {
    // Wenn eine neue Route gepusht wird, aktualisiere die Markierung nicht
    // (die Markierung wird aktualisiert, wenn wir zurückkommen)
  }

  @override
  void didPush() {
    // Wenn diese Route gepusht wird, lade die Markierung neu (gewerkübergreifend)
    _loadLastOpenedAnlage();
  }

  /// Lädt alle Anlagen aus Drift-Datenbank, filtert nach Building und Disziplin.
  Future<void> _loadAnlagen() async {
    final dbService = ref.read(databaseServiceProvider);

    try {
      final buildingId = widget.building.id;
      final label = widget.discipline.label;

      final projectId = await dbService.getProjectIdByBuildingId(buildingId);
      CsvSettings? csvSettings;
      if (projectId != null) {
        await ref.read(csvSettingsProvider(projectId).notifier).load();
        csvSettings = ref.read(csvSettingsProvider(projectId));
      }
      
      // Lade alle Anlagen für dieses Gebäude und diese Disziplin
      final loaded = await dbService.getAnlagenByBuildingIdAndDiscipline(buildingId, label);
      appLog('SystemsPage._loadAnlagen: Geladen ${loaded.length} Anlagen für Building $buildingId, Discipline $label, Floor ${widget.floor.id}');

      // Filtere nach floorId, wenn nicht global
      final filtered = widget.floor.id == 'global'
          ? loaded
          : loaded.where((a) => a.floorId == widget.floor.id).toList();
      appLog('SystemsPage._loadAnlagen: Gefiltert auf ${filtered.length} Anlagen');
      
      _validationByAnlageId.clear();
      for (final a in filtered) {
        _validationByAnlageId[a.id] = AnlageValidationService.isAnlageValidated(a);
      }

      setState(() {
        _alleAnlagen = filtered;
        _cachedProjectId = projectId;
        _cachedCsvSettings = csvSettings;
        _rebuildAnlagenIndexes();
        _isLoading = false;
        _hasLoadedOnce = true;
        _selectedAnlagenIds.removeWhere(
            (id) => !_alleAnlagen.any((anlage) => anlage.id == id));
        if (_selectedAnlagenIds.isEmpty && _isSelectionMode) {
          _exitSelectionMode();
        }
        
        // Räume Keys für nicht mehr existierende Anlagen auf
        final existingIds = _alleAnlagen.map((a) => a.id).toSet();
        _anlageKeys.removeWhere((id, _) => !existingIds.contains(id));
      });

      // Lade die zuletzt geöffnete Anlage, falls noch nicht geladen
      await _loadLastOpenedAnlage();

      // Nach dem Laden zur zuletzt geöffneten Anlage scrollen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLastOpenedAnlage();
      });
    } catch (e) {
      appLog('Fehler beim Laden der Anlagen: $e');
      
      setState(() {
        _alleAnlagen = [];
        _parentAnlagen = [];
        _childrenByParentId = {};
        _isLoading = false;
        _hasLoadedOnce = true;
        _selectedAnlagenIds.clear();
        _isSelectionMode = false;
      });
    }

    widget.onSelectionChanged?.call(_isSelectionMode, _selectedAnlagenIds.length);
  }

  /// Speichert alle aktuellen Anlagen in der Drift-Datenbank.
  Future<void> _saveAnlagen() async {
    final dbService = ref.read(databaseServiceProvider);

    final buildingId = widget.building.id;
    final label = widget.discipline.label;

    final toPersist = _alleAnlagen
        .where((a) =>
            a.buildingId == buildingId &&
            a.discipline.label == label)
        .toList();

    try {
      await dbService.upsertAnlagenBatch(toPersist);
    } catch (e) {
      appLog('Fehler beim Speichern der Anlagen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anlagen konnten nicht gespeichert werden: $e')),
        );
      }
    }
  }

  /// Baut Index für Eltern-/Kinder-Beziehungen (einmal pro Laden, nicht pro Listeneintrag).
  void _rebuildAnlagenIndexes() {
    final label = widget.discipline.label;
    final buildingId = widget.building.id;
    final isGlobal = widget.floor.id == 'global';
    final floorId = widget.floor.id;

    final baseAnlagen = <Anlage>[];
    final childrenByParent = <String, List<Anlage>>{};

    for (final a in _alleAnlagen) {
      if (a.buildingId != buildingId || a.discipline.label != label) continue;
      if (!isGlobal && a.floorId != floorId) continue;
      baseAnlagen.add(a);
      final pid = a.parentId;
      if (pid != null && pid.isNotEmpty) {
        childrenByParent.putIfAbsent(pid, () => []).add(a);
      }
    }

    final existingIds = baseAnlagen.map((a) => a.id).toSet();
    var roots = baseAnlagen.where((a) {
      if (a.parentId == null || a.parentId!.isEmpty) return true;
      return !existingIds.contains(a.parentId!);
    }).toList();

    // Ebene 1 = Disziplin: synthetischen „Brandschutz“-Knoten nicht nochmal als Wurzel zeigen.
    final labelLower = label.trim().toLowerCase();
    final flattened = <Anlage>[];
    for (final a in roots) {
      final isRedundantDisciplineNode = a.params['__syntheticParent'] == true &&
          a.name.trim().toLowerCase() == labelLower;
      if (isRedundantDisciplineNode) {
        flattened.addAll(childrenByParent[a.id] ?? const []);
      } else {
        flattened.add(a);
      }
    }
    _parentAnlagen = flattened;
    _childrenByParentId = childrenByParent;
  }

  /// Gibt die Kinder einer Anlage zurück
  List<Anlage> _getChildren(Anlage parent) =>
      _childrenByParentId[parent.id] ?? const [];


  void _exitSelectionMode() {
    // 1) State sofort ändern, damit Header-Farbe direkt umspringt
    setState(() {
      _isSelectionMode = false;
      _selectedAnlagenIds.clear();
    });
    // 2) Parent informieren, dass Selection beendet ist
    widget.onSelectionChanged?.call(false, 0);
    // 3) Icon erst jetzt zurückdrehen
    _rotationController.reverse();
  }

  void exitSelectionMode() {
    _exitSelectionMode();
  }

  /// Prüft, ob nur Bauteile (keine Haupt-Anlagen) ausgewählt sind
  bool hasOnlyBauteileSelected() {
    if (_selectedAnlagenIds.isEmpty) return false;
    // Prüfe, ob alle selektierten Anlagen Bauteile sind (parentId != null)
    return _alleAnlagen
        .where((a) => _selectedAnlagenIds.contains(a.id))
        .every((a) => a.parentId != null);
  }


  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;  // Aktiviert den Auswahlmodus
      _selectedAnlagenIds.add(id);  // Fügt die Anlage der Auswahl hinzu
    });
    _rotationController.forward();  // Führt die Rotationsanimation aus
    widget.onSelectionChanged?.call(true, _selectedAnlagenIds.length); // Benachrichtigt, dass der Auswahlmodus aktiviert wurde
  }


  Future<void> deleteSelectedAnlagen() async {
    // Hier keine Bestätigung mehr, die kam schon oben im BuildingDetailsPage
    final dbService = ref.read(databaseServiceProvider);
    final toDeleteIds = _selectedAnlagenIds.toList();

    // Endgültig aus der DB (inkl. Kinder/Bauteile)
    for (final id in toDeleteIds) {
      await dbService.hardDeleteAnlage(id);
    }

    setState(() {
      _alleAnlagen.removeWhere((a) => toDeleteIds.contains(a.id));
      _selectedAnlagenIds.clear();
    });
    // Liste neu laden, um auch die gelöschten Kinder aus der UI zu entfernen
    await _loadAnlagen();
    _exitSelectionMode();
  }

  /// Öffnet den Dialog zum Verschieben der ausgewählten Anlagen.
  Future<void> moveSelectedAnlagen() async {
    final toMoveIds = _selectedAnlagenIds.toList();
    final objectsToMove = _alleAnlagen
        .where((a) => toMoveIds.contains(a.id))
        .toList();

    if (objectsToMove.isEmpty) {
      if (!mounted) return;
      return;
    }

    final dbService = ref.read(databaseServiceProvider);
    final projectId = await dbService.getProjectIdByBuildingId(widget.building.id);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => MoveAnlagenDialog(
        anlagenToMove: objectsToMove,
        currentBuildingId: widget.building.id,
        currentFloorId: widget.floor.id,
        currentDiscipline: widget.discipline,
        projectId: projectId,
        revisionsfeldGroupingKey: widget.groupingKey,
        revisionsobjektGroupingKey: widget.subGroupingKey,
      ),
    );

    if (result == true) {
      // Erfolgreich verschoben
      setState(() {
        _selectedAnlagenIds.clear();
        _isSelectionMode = false;
      });
      
      // Liste neu laden, da Elemente weg sein könnten (anderes Gewerk/Floor)
      await _loadAnlagen();
      _exitSelectionMode();

      // Callback aufrufen, um alle betroffenen Gewerke neu zu laden
      widget.onAnlagenMoved?.call();

      if (!mounted) return;
    }
  }



  /// Öffnet den Dialog zum Hinzufügen eines neuen Bauteils für alle selektierten Haupt-Anlagen.
  /// Der Dialog wird einmal ausgefüllt; anschließend wird das Bauteil unter jede selektierte Anlage dupliziert.
  Future<void> openAddBauteilDialogForSelection() async {
    // Selektierte IDs -> nur Haupt-Anlagen (parentId == null)
    final selectedParents = _alleAnlagen
        .where((a) => _selectedAnlagenIds.contains(a.id) && a.parentId == null)
        .toList();

    if (selectedParents.isEmpty) {
      if (!mounted) return;
      return;
    }

    // Hier nehmen wir die Anlage, die du gedrückt hältst (Eltern-Objekt)
    final firstParent = selectedParents.first;

    final dbService = ref.read(databaseServiceProvider);
    final projectId = await dbService.getProjectIdByBuildingId(widget.building.id);
    CsvSettings csvSettings = CsvSettings.defaults();
    if (projectId != null) {
      await ref.read(csvSettingsProvider(projectId).notifier).load();
      csvSettings = ref.read(csvSettingsProvider(projectId));
    }

    final schemaItemKey = csvSettings.resolveSchemaItemParamKey();
    final roValue = csvSettings.schemaItemValueFromParams(firstParent.params) ??
        firstParent.name;

    final initialParams = <String, dynamic>{};
    if (schemaItemKey != null && schemaItemKey.isNotEmpty) {
      initialParams[schemaItemKey] = roValue;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        // Disziplin und Felder des Parents an das Kind weitergeben
        discipline: firstParent.discipline,
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        parentId: firstParent.id,
        existingAnlage: null,
        index: null,
        // Explizit, welches Revisionsobjekt-Schema geladen werden soll
        initialRevisionsobjekt: roValue,
        initialParams: initialParams,
        onSave: (createdBauteil, _) async {
          final copies = <Anlage>[];

          // 1) Das vom Dialog erstellte Objekt nutzen wir für den ersten Parent.
          copies.add(createdBauteil);

          // 2) Für alle weiteren Parents neue Objekte erzeugen (falls mehrere ausgewählt wurden).
          if (selectedParents.length > 1) {
            final clonedParams = Map<String, dynamic>.from(createdBauteil.params);
            final pp = createdBauteil.params['photoPaths'];
            if (pp is List) {
              clonedParams['photoPaths'] = List<dynamic>.from(pp);
            }

            for (var i = 1; i < selectedParents.length; i++) {
              final p = selectedParents[i];
              copies.add(
                Anlage(
                  id: const Uuid().v4(),
                  parentId: p.id,
                  name: createdBauteil.name,
                  params: Map<String, dynamic>.from(clonedParams),
                  floorId: createdBauteil.floorId,
                  buildingId: createdBauteil.buildingId,
                  isMarker: false,
                  markerInfo: null,
                  markerType: widget.discipline.label,
                  // Kopien erben die Disziplin des Parents
                  discipline: firstParent.discipline,
                ),
              );
            }
          }

          if (!mounted) return;
          setState(() {
            _alleAnlagen.addAll(copies);
            for (final p in selectedParents) {
              _expandedAnlagenIds.add(p.id);
            }
          });
          await _saveAnlagen();
          await _loadAnlagen();

          if (!mounted) return;
          widget.onBauteilCreated?.call();
          _exitSelectionMode(); // Auswahlmodus beenden
        },
      ),
    );
  }

  Future<AnlagePlacementResult?> _pickPlacementForNewAnlage() async {
    final subKey = widget.subGroupingKey?.trim();
    if (subKey == null || subKey.isEmpty) return null;

    final dbService = ref.read(databaseServiceProvider);
    final projectId = await dbService.getProjectIdByBuildingId(widget.building.id);
    if (!mounted) return null;

    return showModalBottomSheet<AnlagePlacementResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MoveAnlagenDialog.forPlacement(
        discipline: widget.discipline,
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        projectId: projectId,
        revisionsfeldGroupingKey: widget.groupingKey,
        revisionsobjektGroupingKey: widget.subGroupingKey,
      ),
    );
  }

  Future<void> _openAnlageErfassungAfterPlacement({
    required Disziplin discipline,
    required Map<String, dynamic> placementParams,
    required String? projectId,
  }) async {
    final params = Map<String, dynamic>.from(placementParams);

    if (projectId == null || projectId.isEmpty) {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => GenericAnlageDialog(
          discipline: discipline,
          buildingId: widget.building.id,
          floorId: widget.floor.id,
          existingAnlage: null,
          index: null,
          initialParams: params.isNotEmpty ? params : null,
          onSave: (newAnlage, _) async {
            setState(() => _alleAnlagen.add(newAnlage));
            await _saveAnlagen();
            await _loadAnlagen();
            widget.onAnlageCreated?.call();
          },
        ),
      );
      return;
    }

    await ref.read(csvSettingsProvider(projectId).notifier).load();
    final csvSettings = ref.read(csvSettingsProvider(projectId));
    final ro = (csvSettings.revisionsobjektValueFromParams(params) ??
            csvSettings.schemaItemValueFromParams(params) ??
            '')
        .trim();

    final dbService = ref.read(databaseServiceProvider);
    final gewerkTemplates = await TemplateService.loadTemplatesFromDatabase(
      dbService,
      projectId,
      gewerk: discipline.label,
    );

    final matched = ro.isNotEmpty && gewerkTemplates.isNotEmpty
        ? TemplateService.findTemplateForRevisionsobjekt(gewerkTemplates, ro)
        : null;
    final schemaRo = ro.isNotEmpty
        ? (TemplateService.resolveRevisionsobjektKeyForValue(
              discipline,
              ro,
              templates: gewerkTemplates,
            ) ??
            matched?.anlagentyp.trim() ??
            ro)
        : '';

    final parentTemplate = matched ??
        Template(
          gewerk: discipline.label,
          anlageBauteil: '',
          anlagentyp: schemaRo.isNotEmpty ? schemaRo : 'Neu',
          bezeichnung: schemaRo.isNotEmpty ? schemaRo : 'Neu',
        );

    final effectiveDiscipline = schemaRo.isNotEmpty
        ? TemplateService.disciplineWithSchemaForRevisionsobjekt(
            discipline: discipline,
            revisionsobjekt: schemaRo,
            template: parentTemplate,
            templatesForLookup: gewerkTemplates,
          )
        : discipline;

    final formParams = TemplateService.buildInitialParamsForSchemaItem(
      parentTemplate: parentTemplate,
      selectedAnlagentyp: schemaRo.isNotEmpty ? schemaRo : ro,
      schemaItemParamKey: csvSettings.resolveSchemaItemParamKey(),
    );
    formParams.addAll(params);

    final initialName = csvSettings.displayNameValueFromParams(formParams) ?? '';

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: effectiveDiscipline,
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        initialParams: formParams,
        initialName: initialName.isNotEmpty ? initialName : null,
        initialRevisionsobjekt: schemaRo.isNotEmpty ? schemaRo : null,
        onSave: (newAnlage, _) async {
          setState(() => _alleAnlagen.add(newAnlage));
          await _saveAnlagen();
          await _loadAnlagen();
          widget.onAnlageCreated?.call();
        },
      ),
    );
  }

  /// Öffnet den Dialog zum Hinzufügen einer neuen Anlage (ohne Marker).
  Future<void> _showAddDialog() async {
    final dbService = ref.read(databaseServiceProvider);
    final projectId = await dbService.getProjectIdByBuildingId(widget.building.id);
    if (!mounted) return;

    final placement = await _pickPlacementForNewAnlage();
    if (widget.subGroupingKey != null &&
        widget.subGroupingKey!.trim().isNotEmpty &&
        placement == null) {
      return;
    }

    await _openAnlageErfassungAfterPlacement(
      discipline: placement?.discipline ?? widget.discipline,
      placementParams: placement?.initialParams ?? const {},
      projectId: projectId,
    );
  }

  /// Von außen aufrufbar, um den Hinzufügen-Dialog zu öffnen.
  void openAddDialog() {
    _showAddDialog();
  }

  /// Öffnet den Dialog zum Bearbeiten einer bestehenden Anlage.
  Future<void> _showEditDialog(Anlage a) async {
    _saveLastOpenedAnlage(a.id);

    final dbService = ref.read(databaseServiceProvider);
    final fullAnlage = await dbService.getAnlageById(a.id) ?? a;
    final idx = _alleAnlagen.indexWhere((x) => x.id == a.id);
    if (!mounted) return;

    Disziplin editDiscipline = fullAnlage.discipline;
    String? initialRo;

    final projectId = await dbService.getProjectIdByBuildingId(fullAnlage.buildingId);
    if (projectId != null && projectId.isNotEmpty) {
      await ref.read(csvSettingsProvider(projectId).notifier).load();
      final csvSettings = ref.read(csvSettingsProvider(projectId));
      final ro = (csvSettings.revisionsobjektValueFromParams(fullAnlage.params) ??
              csvSettings.schemaItemValueFromParams(fullAnlage.params) ??
              '')
          .trim();

      if (ro.isNotEmpty) {
        final gewerkTemplates = await TemplateService.loadTemplatesFromDatabase(
          dbService,
          projectId,
          gewerk: fullAnlage.discipline.label,
        );
        final matched = gewerkTemplates.isNotEmpty
            ? TemplateService.findTemplateForRevisionsobjekt(gewerkTemplates, ro)
            : null;
        final schemaRo = TemplateService.resolveRevisionsobjektKeyForValue(
              fullAnlage.discipline,
              ro,
              templates: gewerkTemplates,
            ) ??
            matched?.anlagentyp.trim() ??
            ro;

        initialRo = schemaRo;
        editDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
          discipline: fullAnlage.discipline,
          revisionsobjekt: schemaRo,
          template: matched,
          templatesForLookup: gewerkTemplates,
        );
      }
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: editDiscipline,
        buildingId: fullAnlage.buildingId,
        floorId: fullAnlage.floorId,
        existingAnlage: fullAnlage,
        initialRevisionsobjekt: initialRo,
        index: idx,
        onSave: (editedAnlage, index) async {
          final gk = widget.groupingKey;
          if (gk != null && gk.isNotEmpty) {
            final oldValue = fullAnlage.params[gk]?.toString() ?? '';
            final newValue = editedAnlage.params[gk]?.toString() ?? '';
            if (oldValue != newValue && newValue.isNotEmpty) {
              setState(() {
                _expandedGroups.add(newValue);
              });
              _saveExpandedGroups();
            }
          }

          setState(() {
            _alleAnlagen[index!] = editedAnlage;
          });
          await _saveAnlagen();
          await _loadAnlagen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _buildList(widget.discipline);
    if (widget.usePrimaryScroll) {
      return list;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 4),
      child: list,
    );
  }

  Widget _buildList(Disziplin disc) {
    return SystemsAnlageList(
      isLoading: _isLoading,
      hasLoadedOnce: _hasLoadedOnce,
      disc: disc,
      parents: _parentAnlagen,
      getChildren: _getChildren,
      usePrimaryScroll: widget.usePrimaryScroll,
      groupingKey: widget.groupingKey,
      subGroupingKey: widget.subGroupingKey,
      displayNameParamKey: widget.displayNameParamKey,
      resolveListDisplayName: _resolveListDisplayName,
      expandedGroups: _expandedGroups,
      expandedAnlagenIds: _expandedAnlagenIds,
      onGroupExpansionChanged: (groupKey, expanded) {
        setState(() {
          if (expanded) {
            _expandedGroups.add(groupKey);
          } else {
            _expandedGroups.remove(groupKey);
          }
        });
        _saveExpandedGroups();
      },
      onToggleAnlageExpanded: (anlageId) {
        setState(() {
          if (_expandedAnlagenIds.contains(anlageId)) {
            _expandedAnlagenIds.remove(anlageId);
          } else {
            _expandedAnlagenIds.add(anlageId);
          }
        });
      },
      onGroupLongPress: widget.onGroupLongPress != null
          ? (gk, gv, extra) =>
              widget.onGroupLongPress!(widget.discipline, gk, gv, extra)
          : null,
      itemBuilder: _buildHierarchicalAnlageItem,
    );
  }

  CsvSettings? _liveCsvSettings() {
    final projectId = _cachedProjectId;
    if (projectId != null && projectId.isNotEmpty) {
      return ref.read(csvSettingsProvider(projectId));
    }
    return _cachedCsvSettings;
  }

  String? _resolveDisplayNameValue(Anlage anlage, Disziplin disc) {
    final csv = _liveCsvSettings();
    if (csv == null) return null;

    final explicitKey =
        widget.displayNameParamKey?.trim() ?? csv.displayNameParamKey.trim();
    if (explicitKey.isNotEmpty) {
      final direct = csv.paramValueForKey(anlage.params, explicitKey);
      if (direct != null && direct.isNotEmpty) return direct;
      for (final field in disc.schema) {
        final fieldKey = (field['key'] ?? '').toString();
        final fieldLabel = (field['label'] ?? fieldKey).toString();
        if (fieldKey.isEmpty) continue;
        if (!CsvSettings.paramKeysMatch(fieldKey, explicitKey) &&
            !CsvSettings.paramKeysMatch(fieldLabel, explicitKey)) {
          continue;
        }
        final fromField = csv.paramValueForKey(anlage.params, fieldKey);
        if (fromField != null && fromField.isNotEmpty) return fromField;
      }
    }

    return csv.displayNameValueFromParams(
      anlage.params,
      schemaFields: disc.schema,
    );
  }

  bool _isHierarchyLevelLabel(String text, CsvSettings csv) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t == csv.labelGewerk || t == csv.labelAnlage || t == csv.labelBauteil) {
      return true;
    }
    for (var level = 1; level <= 3; level++) {
      if (t == csv.hierarchyLevelHeaderLabel(level)) return true;
    }
    return false;
  }

  String _resolveListDisplayName(Anlage anlage) {
    final csv = _liveCsvSettings();
    final fromParams = _resolveDisplayNameValue(anlage, anlage.discipline);
    if (fromParams != null && fromParams.isNotEmpty) {
      return fromParams;
    }

    final name = anlage.name.trim();
    if (csv != null && _isHierarchyLevelLabel(name, csv)) {
      for (final field in anlage.discipline.schema) {
        final fieldKey = (field['key'] ?? '').toString();
        if (fieldKey.isEmpty) continue;
        if (csv.isUpperHierarchyParamKey(fieldKey)) continue;
        final v = csv.paramValueForKey(anlage.params, fieldKey);
        if (v != null && v.isNotEmpty && v.trim() != name) return v;
      }
    }
    return name;
  }

  String? _resolvePreviewText(
    Anlage anlage,
    Disziplin disc, {
    required bool isChild,
    required bool hasChildren,
  }) {
    if (!isChild && hasChildren) return null;
    return _resolveDisplayNameValue(anlage, disc);
  }

  String? _resolveTypeHint(Anlage anlage) => null;

  Widget _buildHierarchicalAnlageItem(
    Anlage a,
    Disziplin disc, {
    bool isChild = false,
    bool hasChildren = false,
    bool isExpanded = false,
    VoidCallback? onToggleExpanded,
  }) {
    final isSelected = _selectedAnlagenIds.contains(a.id);
    final isValidated = _validationByAnlageId[a.id] ?? false;
    final isLastOpened = _lastOpenedAnlageId == a.id;

    Key? itemKey;
    if (isLastOpened) {
      _anlageKeys.putIfAbsent(a.id, () => GlobalKey());
      itemKey = _anlageKeys[a.id]!;
    }

    // Prüfe, ob irgendwo ein Selection-Mode aktiv ist (gewerkeübergreifend)
    final anySelectionActive = widget.isAnySelectionActive?.call() ?? false;
    final showSelectionCircles = _isSelectionMode || anySelectionActive;

    return AnlageHierarchicalItem(
      anlage: a,
      discipline: disc,
      typeHint: _resolveTypeHint(a),
      previewText: _resolvePreviewText(
        a,
        disc,
        isChild: isChild,
        hasChildren: hasChildren,
      ),
      isChild: isChild,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
      isSelected: isSelected,
      showSelectionCircles: showSelectionCircles,
      isValidated: isValidated,
      isLastOpened: isLastOpened,
      scrollKey: itemKey,
      onTap: () {
        if (showSelectionCircles) {
          // Wenn Selection-Mode aktiv ist (eigener oder gewerkeübergreifend)
          if (!_isSelectionMode) {
            // Aktiviere Selection-Mode für diese SystemsPage
            _enterSelectionMode(a.id);
          } else {
            // Toggle Selection
            setState(() {
              if (isSelected) {
                _selectedAnlagenIds.remove(a.id);
                if (_selectedAnlagenIds.isEmpty) {
                  _exitSelectionMode();
                } else {
                  // Aktualisiere die Anzahl auch beim Abwählen
                  widget.onSelectionChanged?.call(true, _selectedAnlagenIds.length);
                }
              } else {
                _selectedAnlagenIds.add(a.id);
                widget.onSelectionChanged?.call(true, _selectedAnlagenIds.length);
              }
            });
          }
        } else {
          // Hier öffnet sich wieder Dein GenericAnlageDialog:
          _showEditDialog(a);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          // Wenn eine Gewerk-Auswahl aktiv ist, beende diese zuerst
          if (widget.onExitDisciplineSelectionMode != null) {
            widget.onExitDisciplineSelectionMode!();
          }
          _enterSelectionMode(a.id);
        }
      },
    );
  }

}
