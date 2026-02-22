/// lib/pages/systems_page.dart


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/anlage.dart';
import '../models/building.dart';
import '../models/floor_plan.dart';
import '../models/marker.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/database_provider.dart';
import '../services/anlage_validation_service.dart';

// Widgets für Anlage-Dialoge (relativ zu lib/pages/)
import 'widgets/generic_anlage_dialog.dart';
import 'widgets/move_anlagen_dialog.dart';
import 'widgets/template_anlage_dialog.dart';
import 'widgets/anlage_hierarchical_item.dart';
import 'widgets/systems_anlage_list.dart';
import 'systems_ui_store.dart';
import '../utils/app_log.dart';
import '../navigation/route_observer.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

class SystemsPage extends ConsumerStatefulWidget {
  final Building building; // Das Gebäude, für das die Anlagen angezeigt werden sollen
  final FloorPlan floor;   // Der Plan des Floors, auf dem die Anlagen zu finden sind
  final Disziplin discipline; // Die Disziplin, für die Anlagen angezeigt werden

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

  const SystemsPage({
    Key? key,
    required this.building,
    required this.floor,
    required this.discipline,
    this.onSelectionChanged,
    this.isAnySelectionActive,
    this.onExitDisciplineSelectionMode,
    this.onAnlageCreated,
    this.onBauteilCreated,
    this.onAnlagenMoved,
  }) : super(key: key);

  @override
  ConsumerState<SystemsPage> createState() => SystemsPageState();
}

class SystemsPageState extends ConsumerState<SystemsPage>
    with RouteAware, TickerProviderStateMixin {
  List<Anlage> _alleAnlagen = [];  // Liste aller Anlagen im aktuellen Gebäude und auf dem aktuellen Floor
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

      // Wenn Gruppierung aktiv ist und die Anlage in einer Gruppe ist, klappe die Gruppe auf
      final disc = widget.discipline;
      if (disc.groupingKey != null && disc.groupingKey!.isNotEmpty) {
        final groupValue = anlage.params[disc.groupingKey]?.toString() ?? '';
        setState(() {
          _expandedGroups.add(groupValue);
        });
      }

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
      
      // Lade alle Anlagen für dieses Gebäude und diese Disziplin
      final loaded = await dbService.getAnlagenByBuildingIdAndDiscipline(buildingId, label);
      debugPrint('SystemsPage._loadAnlagen: Geladen ${loaded.length} Anlagen für Building $buildingId, Discipline $label, Floor ${widget.floor.id}');

      // Filtere nach floorId, wenn nicht global
      final filtered = widget.floor.id == 'global'
          ? loaded
          : loaded.where((a) => a.floorId == widget.floor.id).toList();
      debugPrint('SystemsPage._loadAnlagen: Gefiltert auf ${filtered.length} Anlagen');
      
      setState(() {
        _alleAnlagen = filtered;
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
      debugPrint('Fehler beim Laden der Anlagen: $e');
      
      setState(() {
        _alleAnlagen = [];
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

    // Speichere jede Anlage einzeln
    for (final anlage in toPersist) {
      try {
        final existing = await dbService.getAnlageById(anlage.id);
        if (existing != null) {
          await dbService.updateAnlage(anlage);
        } else {
          await dbService.insertAnlage(anlage);
        }
      } catch (e) {
        debugPrint('Fehler beim Speichern der Anlage ${anlage.id}: $e');
      }
    }
  }

  /// Für globale (Marker-basierte) oder für text-basierte Anzeige unterscheiden.
  /// Gibt nur Haupt-Anlagen zurück (ohne parentId).
  List<Anlage> get _anzeigeAnlagen {
    final label = widget.discipline.label;
    final baseAnlagen = widget.floor.id == 'global'
        ? _alleAnlagen.where((a) =>
            a.buildingId == widget.building.id &&
            a.discipline.label == label)
        : _alleAnlagen.where((a) =>
            a.buildingId == widget.building.id &&
            a.floorId == widget.floor.id &&
            a.discipline.label == label);

    // Nur Haupt-Anlagen zurückgeben (die ohne parentId)
    return baseAnlagen.where((a) => a.parentId == null).toList();
  }

  /// Gibt die Kinder einer Anlage zurück
  List<Anlage> _getChildren(Anlage parent) {
    return _alleAnlagen.where((a) =>
        a.parentId == parent.id &&
        a.buildingId == widget.building.id &&
        a.discipline.label == widget.discipline.label &&
        (widget.floor.id == 'global' || a.floorId == widget.floor.id)
    ).toList();
  }


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

    // Alle ausgewählten Anlagen aus der Datenbank löschen
    // deleteAnlage löscht rekursiv alle Kinder (Bauteile) automatisch
    for (final id in toDeleteIds) {
      await dbService.deleteAnlage(id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Anlagen ausgewählt'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${toMoveIds.length} Element(e) verschoben'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }



  /// Öffnet den Dialog zum Hinzufügen eines neuen Bauteils für alle selektierten Haupt-Anlagen.
  /// Der Dialog wird einmal ausgefüllt; anschließend wird das Bauteil unter jede selektierte Anlage dupliziert.
  Future<void> openAddBauteilDialogForSelection() async {
    // Selektierte IDs -> nur Haupt-Anlagen (parentId == null)
    final selectedParents = _alleAnlagen
        .where((a) => _selectedAnlagenIds.contains(a.id) && a.parentId == null)
        .toList();

    // Wenn nur Bauteile ausgewählt sind, wird diese Methode nicht aufgerufen
    // (Button wird nicht angezeigt), daher ist die Meldung obsolet
    if (selectedParents.isEmpty) {
      if (!mounted) return;
      return;
    }

    final firstParent = selectedParents.first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: widget.discipline,
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        parentId: firstParent.id,
        existingAnlage: null,
        index: null,
        onSave: (createdBauteil, _) async {
          final copies = <Anlage>[];

          // 1) Das vom Dialog erstellte Objekt nutzen wir für den ersten Parent.
          copies.add(createdBauteil);

          // 2) Für alle weiteren Parents neue Objekte erzeugen.
          if (selectedParents.length > 1) {
            // Flache Kopie der Params. Falls photoPaths eine Liste ist, ebenfalls kopieren.
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
                  discipline: widget.discipline,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bauteil zu ${selectedParents.length} Anlage${selectedParents.length > 1 ? 'n' : ''} hinzugefügt',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          widget.onBauteilCreated?.call();
          _exitSelectionMode(); // AppBar schließen (Auswahlmodus beenden)
        },
      ),
    );
  }

  /// Öffnet den Dialog zum Hinzufügen einer neuen Anlage (ohne Marker).
  Future<void> _showAddDialog() async {
    final dbService = ref.read(databaseServiceProvider);
    final projectId = await dbService.getProjectIdByBuildingId(widget.building.id);
    if (!mounted) return;

    void openManual() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => GenericAnlageDialog(
          discipline: widget.discipline,
          buildingId: widget.building.id,
          floorId: widget.floor.id,
          existingAnlage: null,
          index: null,
          onSave: (newAnlage, _) async {
            setState(() => _alleAnlagen.add(newAnlage));
            await _saveAnlagen();
            await _loadAnlagen();
            widget.onAnlageCreated?.call();
          },
        ),
      );
    }

    if (projectId == null || projectId.isEmpty) {
      openManual();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TemplateAnlageDialog(
        dbService: ref.read(databaseServiceProvider),
        projectId: projectId,
        discipline: widget.discipline,
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        onCreate: (created) async {
          setState(() {
            _alleAnlagen.addAll(created);
            for (final parent in created.where((a) => a.parentId == null)) {
              _expandedAnlagenIds.add(parent.id);
            }
          });
          await _saveAnlagen();
          await _loadAnlagen();
          widget.onAnlageCreated?.call();
        },
        onCreateManual: openManual,
      ),
    );
  }

  /// Von außen aufrufbar, um den Hinzufügen-Dialog zu öffnen.
  void openAddDialog() {
    _showAddDialog();
  }

  /// Öffnet den Dialog zum Bearbeiten einer bestehenden Anlage.
  void _showEditDialog(Anlage a) {
    // Speichere die zuletzt geöffnete Anlage-ID
    _saveLastOpenedAnlage(a.id);
    
    final idx = _alleAnlagen.indexWhere((x) => x.id == a.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: a.discipline,
        buildingId: a.buildingId,
        floorId: a.floorId,
        existingAnlage: a,
        index: idx,
        onSave: (editedAnlage, index) async {
          setState(() {
            _alleAnlagen[index!] = editedAnlage;
          });
          await _saveAnlagen();
          await _loadAnlagen();
        },
      ),
    );
  }

  /// Wandelt ein Marker-Objekt in eine [Anlage] um und fügt sie hinzu.
  Future<void> addMarkerAnlage(Marker marker) async {
    final params = marker.params != null
        ? Map<String, dynamic>.from(marker.params!)
        : <String, dynamic>{};

    // Etage automatisch in Params setzen (damit sie im Anlagen-Dialog/CSV sichtbar ist)
    final floorLabel = widget.floor.name.trim().isNotEmpty
        ? widget.floor.name.trim()
        : (widget.floor.pdfName?.trim().isNotEmpty == true
            ? widget.floor.pdfName!.trim()
            : '');
    if (floorLabel.isNotEmpty) {
      final existing = params['Etage']?.toString().trim() ?? '';
      if (existing.isEmpty) {
        params['Etage'] = floorLabel;
      }
    }

    final newAnlage = Anlage(
      id: marker.id,
      name: marker.title,
      params: params,
      floorId: widget.floor.id,
      buildingId: widget.building.id,
      isMarker: true,
      markerInfo: {
        'x': marker.x,
        'y': marker.y,
        'pageNumber': marker.pageNumber,
      },
      markerType: widget.discipline.label,
      discipline: widget.discipline,
    );

    setState(() {
      _alleAnlagen.add(newAnlage);  // Fügt die neue Marker-Anlage hinzu
    });
    await _saveAnlagen();  // Speichert die Anlage
    await _loadAnlagen();  // Lädt die Liste neu
  }

  @override
  Widget build(BuildContext context) {
    // Aktualisiere die Markierung gewerkeübergreifend, wenn die Anlagen bereits geladen sind
    // (nur wenn nicht gerade geladen wird, um unnötige Updates zu vermeiden)
    // Verwende WidgetsBinding.instance.addPostFrameCallback, um Updates nach dem Build durchzuführen
    if (!_isLoading && _alleAnlagen.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Lade die Markierung asynchron, ohne setState während des Builds zu blockieren
        _loadLastOpenedAnlage();
      });
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 12),
      child: _buildList(widget.discipline),  // Baut die Liste der Anlagen
    );
  }

  Widget _buildList(Disziplin disc) {
    final parents = _anzeigeAnlagen.where((a) => a.discipline.label == disc.label).toList();

    return SystemsAnlageList(
      isLoading: _isLoading,
      hasLoadedOnce: _hasLoadedOnce,
      disc: disc,
      parents: parents,
      getChildren: _getChildren,
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
      itemBuilder: _buildHierarchicalAnlageItem,
    );
  }

  Widget _buildHierarchicalAnlageItem(
    Anlage a,
    Disziplin disc, {
    bool isChild = false,
    bool hasChildren = false,
    bool isExpanded = false,
    VoidCallback? onToggleExpanded,
  }) {
    final isSelected = _selectedAnlagenIds.contains(a.id);
    final isValidated = AnlageValidationService.getValidatedStatus(a);
    final isLastOpened = _lastOpenedAnlageId == a.id;

    // Stelle sicher, dass ein GlobalKey für diese Anlage existiert
    _anlageKeys.putIfAbsent(a.id, () => GlobalKey());
    final itemKey = _anlageKeys[a.id]!;

    // Prüfe, ob irgendwo ein Selection-Mode aktiv ist (gewerkeübergreifend)
    final anySelectionActive = widget.isAnySelectionActive?.call() ?? false;
    final showSelectionCircles = _isSelectionMode || anySelectionActive;

    return AnlageHierarchicalItem(
      anlage: a,
      discipline: disc,
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
