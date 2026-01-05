/// lib/pages/systems_page.dart

// lib/pages/systems_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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



/// Vollständige RouteObserver-Instanz, in main.dart einbinden:
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

class SystemsPage extends ConsumerStatefulWidget {
  final Building building; // Das Gebäude, für das die Anlagen angezeigt werden sollen
  final FloorPlan floor;   // Der Plan des Floors, auf dem die Anlagen zu finden sind
  final Disziplin discipline; // Die Disziplin, für die Anlagen angezeigt werden

  /// Callback, um Selektion (aktiv, count) nach außen zu melden.
  final void Function(bool isActive, int selectedCount)? onSelectionChanged;
  
  /// Callback, um zu prüfen, ob bereits eine Selection in einem anderen Gewerk aktiv ist.
  final bool Function()? isAnySelectionActive;

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
  bool _isLoading = true;           // Gibt an, ob die Anlagen gerade geladen werden
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'expanded_groups_${widget.building.id}_${widget.discipline.label}';
      final list = prefs.getStringList(key);
      if (list != null) {
        setState(() {
          _expandedGroups.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppen-Expansion: $e');
    }
  }

  Future<void> _saveExpandedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'expanded_groups_${widget.building.id}_${widget.discipline.label}';
      await prefs.setStringList(key, _expandedGroups.toList());
    } catch (e) {
      debugPrint('Fehler beim Speichern der Gruppen-Expansion: $e');
    }
  }

  /// Lädt die ID der zuletzt geöffneten Anlage aus SharedPreferences (gewerkübergreifend)
  Future<void> _loadLastOpenedAnlage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Gewerkübergreifender Key (ohne discipline.label)
      final key = 'last_opened_anlage_${widget.building.id}_${widget.floor.id}';
      final lastOpenedId = prefs.getString(key);
      if (lastOpenedId != null && mounted) {
        // Prüfe, ob die Anlage in der aktuellen Liste existiert
        final anlageExists = _alleAnlagen.any((a) => a.id == lastOpenedId);
        if (anlageExists) {
          setState(() {
            _lastOpenedAnlageId = lastOpenedId;
          });
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der zuletzt geöffneten Anlage: $e');
    }
  }

  /// Speichert die ID der zuletzt geöffneten Anlage in SharedPreferences (gewerkübergreifend)
  Future<void> _saveLastOpenedAnlage(String anlageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Gewerkübergreifender Key (ohne discipline.label)
      final key = 'last_opened_anlage_${widget.building.id}_${widget.floor.id}';
      await prefs.setString(key, anlageId);
      
      // Setze den Scroll-Flag für alle Gewerke zurück, wenn eine neue Anlage geöffnet wird
      await _resetHasScrolledFlagForAllDisciplines();
      
      setState(() {
        _lastOpenedAnlageId = anlageId;
        _hasScrolledToLastOpened = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Speichern der zuletzt geöffneten Anlage: $e');
    }
  }

  /// Lädt den Flag, ob bereits zur zuletzt angesehenen Anlage gescrollt wurde
  Future<void> _loadHasScrolledFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_scrolled_to_last_${widget.building.id}_${widget.discipline.label}_${widget.floor.id}';
      final hasScrolled = prefs.getBool(key) ?? false;
      setState(() {
        _hasScrolledToLastOpened = hasScrolled;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden des Scroll-Flags: $e');
    }
  }

  /// Speichert den Flag, ob bereits zur zuletzt angesehenen Anlage gescrollt wurde
  Future<void> _saveHasScrolledFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_scrolled_to_last_${widget.building.id}_${widget.discipline.label}_${widget.floor.id}';
      await prefs.setBool(key, true);
      setState(() {
        _hasScrolledToLastOpened = true;
      });
    } catch (e) {
      debugPrint('Fehler beim Speichern des Scroll-Flags: $e');
    }
  }

  /// Setzt den Scroll-Flag für alle Gewerke zurück (wird aufgerufen, wenn eine neue Anlage geöffnet wird)
  Future<void> _resetHasScrolledFlagForAllDisciplines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Lade alle Keys, die mit 'has_scrolled_to_last_' beginnen und zum gleichen Building/Floor gehören
      final keys = prefs.getKeys().where((k) => 
        k.startsWith('has_scrolled_to_last_${widget.building.id}_') && 
        k.endsWith('_${widget.floor.id}')
      ).toList();
      
      for (final key in keys) {
        await prefs.setBool(key, false);
      }
    } catch (e) {
      debugPrint('Fehler beim Zurücksetzen der Scroll-Flags: $e');
    }
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
      // Nach dem Laden zur zuletzt geöffneten Anlage scrollen (nur beim ersten Öffnen)
      _scrollToLastOpenedAnlage();
    });
  }

  /// Lädt alle Anlagen aus Drift-Datenbank, filtert nach Building und Disziplin.
  Future<void> _loadAnlagen() async {
    setState(() {
      _isLoading = true;
    });

    final dbService = ref.read(databaseServiceProvider);
    final startTime = DateTime.now();

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
      
      // Warte mindestens 0.5 Sekunden, damit der Ladekreis flüssig angezeigt wird
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsed.inMilliseconds));
      }
      
      setState(() {
        _alleAnlagen = filtered;
        _isLoading = false;
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
      
      // Warte auch bei Fehler mindestens 0.5 Sekunden
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsed.inMilliseconds));
      }
      
      setState(() {
        _alleAnlagen = [];
        _isLoading = false;
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

    if (selectedParents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle mindestens eine Anlage (keine Bauteile) aus.'),
          duration: Duration(seconds: 2),
        ),
      );
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
  void _showAddDialog() {
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
    final newAnlage = Anlage(
      id: marker.id,
      name: marker.title,
      params: marker.params ?? {},
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
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 12),
      child: _buildList(widget.discipline),  // Baut die Liste der Anlagen
    );
  }

  Widget _buildList(Disziplin disc) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Anlagen werden geladen...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final liste = _anzeigeAnlagen
        .where((a) => a.discipline.label == disc.label)
        .toList();

    if (liste.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  disc.icon,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Keine ${disc.label} Anlagen vorhanden',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tippen Sie oben auf das + Symbol, um eine neue Anlage hinzuzufügen',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Gruppierung: Wenn groupingKey gesetzt ist, nach diesem Key gruppieren
    if (disc.groupingKey != null && disc.groupingKey!.isNotEmpty) {
      // Gruppiere Anlagen nach dem Wert des groupingKey Parameters
      final Map<String, List<Anlage>> grouped = {};
      for (final anlage in liste) {
        final groupValue = anlage.params[disc.groupingKey]?.toString() ?? '';
        if (!grouped.containsKey(groupValue)) {
          grouped[groupValue] = [];
        }
        grouped[groupValue]!.add(anlage);
      }

      // Sortiere Gruppen nach Key (leerer String kommt zuletzt)
      final sortedGroupKeys = grouped.keys.toList()..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });

      final List<Widget> items = [];
      for (final groupKey in sortedGroupKeys) {
        final groupAnlagen = grouped[groupKey]!;
        final groupDisplayName = groupKey.isEmpty ? '(Ohne ${disc.groupingKey})' : groupKey;
        final isGroupExpanded = _expandedGroups.contains(groupKey);

        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              // Feine Nuance für Gruppierung: sehr subtiler lila/grauer Ton
              color: Color.lerp(
                Colors.white,
                Color.lerp(disc.color, Colors.purple.shade50, 0.25) ?? Colors.white,
                0.12,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGroupExpanded
                    ? disc.color.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.15),
                width: isGroupExpanded ? 1.5 : 1,
              ),
              boxShadow: isGroupExpanded
                  ? [
                      BoxShadow(
                        color: disc.color.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
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
                key: ValueKey('group_$groupKey'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isGroupExpanded
                          ? [
                              disc.color.withOpacity(0.2),
                              disc.color.withOpacity(0.1),
                            ]
                          : [
                              disc.color.withOpacity(0.15),
                              disc.color.withOpacity(0.08),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: disc.color,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupDisplayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isGroupExpanded
                              ? disc.color
                              : Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: disc.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${groupAnlagen.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: disc.color,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isGroupExpanded
                        ? disc.color.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isGroupExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: isGroupExpanded ? disc.color : Colors.grey[600],
                    size: 22,
                  ),
                ),
                initiallyExpanded: isGroupExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedGroups.add(groupKey);
                    } else {
                      _expandedGroups.remove(groupKey);
                    }
                  });
                  _saveExpandedGroups();
                },
                children: [
                  Container(
                    decoration: BoxDecoration(
                      // Feine Nuance für Anlagen in Gruppierung: sehr subtiler grünlicher Ton
                      color: Color.lerp(
                        Colors.grey[50]!,
                        Color.lerp(disc.color, Colors.green.shade50, 0.2) ?? Colors.grey[50]!,
                        0.08,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: groupAnlagen.expand((parent) {
                        final children = _getChildren(parent);
                        final hasChildren = children.isNotEmpty;
                        final isExpanded = _expandedAnlagenIds.contains(parent.id);

                        final widgets = <Widget>[
                          _buildHierarchicalAnlageItem(
                            parent,
                            disc,
                            isChild: false,
                            hasChildren: hasChildren,
                            isExpanded: isExpanded,
                            onToggleExpanded: hasChildren
                                ? () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedAnlagenIds.remove(parent.id);
                                      } else {
                                        _expandedAnlagenIds.add(parent.id);
                                      }
                                    });
                                  }
                                : null,
                          ),
                        ];

                        if (hasChildren && isExpanded) {
                          widgets.addAll(
                            children.map((child) => Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: _buildHierarchicalAnlageItem(child, disc, isChild: true),
                            )),
                          );
                        }

                        return widgets;
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: items,
      );
    }

    // Aufklappbare Darstellung: Eltern-Anlage + Bauteile erst bei Expand anzeigen (ohne Gruppierung)
    final List<Widget> items = [];
    for (final parent in liste) {
      final children = _getChildren(parent);
      final hasChildren = children.isNotEmpty;
      final isExpanded = _expandedAnlagenIds.contains(parent.id);

      items.add(
        _buildHierarchicalAnlageItem(
          parent,
          disc,
          isChild: false,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onToggleExpanded: hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedAnlagenIds.remove(parent.id);
                    } else {
                      _expandedAnlagenIds.add(parent.id);
                    }
                  });
                }
              : null,
        ),
      );

      if (hasChildren && isExpanded) {
        for (final child in children) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _buildHierarchicalAnlageItem(child, disc, isChild: true),
            ),
          );
        }
      }
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: items,
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
    if (!_anlageKeys.containsKey(a.id)) {
      _anlageKeys[a.id] = GlobalKey();
    }
    final itemKey = _anlageKeys[a.id]!;

    final anlageBautel = a.params['Anlage/Bautel']?.toString() ?? '';
    
    // Prüfe, ob irgendwo ein Selection-Mode aktiv ist (gewerkeübergreifend)
    final anySelectionActive = widget.isAnySelectionActive?.call() ?? false;
    final showSelectionCircles = _isSelectionMode || anySelectionActive;

    final baseTrailing = showSelectionCircles
        ? (isSelected
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              )
            : Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ))
        : null;

    Widget? trailing;
    if (showSelectionCircles) {
      trailing = baseTrailing;
    } else {
      final actions = <Widget>[];

      // Expand-Arrow nur wenn Kinder vorhanden
      if (!isChild && hasChildren) {
        actions.add(
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleExpanded,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: isExpanded ? Theme.of(context).primaryColor : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (actions.isNotEmpty) {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        );
      }
    }

    // Bestimme die Hintergrundfarbe basierend auf dem Status und Typ
    Color? cardBackgroundColor;
    if (isSelected) {
      cardBackgroundColor = Theme.of(context).primaryColor.withOpacity(0.05);
    } else if (isLastOpened && !isChild) {
      // Zuletzt geöffnete Anlage: subtiler blauer Ton (hat Vorrang vor Validierung)
      cardBackgroundColor = Colors.blue.withOpacity(0.04);
    } else if (isValidated) {
      // Vollständige Anlage: keine grüne Färbung, nur Haken
      cardBackgroundColor = isChild
          ? Color.lerp(
              Colors.white,
              Color.lerp(disc.color, Colors.orange.shade50, 0.3) ?? Colors.white,
              0.1,
            )
          : Color.lerp(
              Colors.white,
              Color.lerp(disc.color, Colors.green.shade50, 0.25) ?? Colors.white,
              0.08,
            );
    } else {
      // Feine Nuancen für visuelle Unterscheidung:
      // Anlagen: sehr subtiler grünlicher Ton
      // Bauteile: sehr subtiler orange/beige Ton
      if (isChild) {
        // Bauteil: sehr subtiler orange/beige Ton
        cardBackgroundColor = Color.lerp(
          Colors.white,
          Color.lerp(disc.color, Colors.orange.shade50, 0.3) ?? Colors.white,
          0.1,
        );
      } else {
        // Anlage: sehr subtiler grünlicher Ton
        cardBackgroundColor = Color.lerp(
          Colors.white,
          Color.lerp(disc.color, Colors.green.shade50, 0.25) ?? Colors.white,
          0.08,
        );
      }
    }

    return Container(
      key: itemKey, // GlobalKey für Auto-Scrolling
      margin: EdgeInsets.only(
        bottom: 6,
        top: 2,
        left: isChild ? 12 : 0,
        right: isChild ? 12 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.15)
                : (isLastOpened && !isChild
                    ? Colors.blue.withOpacity(0.12)
                    : (isValidated
                        ? Colors.black.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05))),
            blurRadius: isValidated || (isLastOpened && !isChild) ? 8 : 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isChild
                // Bauteil: subtiler orange/beige Border
                ? Color.lerp(
                    Colors.blue.withOpacity(0.2),
                    Colors.orange.withOpacity(0.25),
                    0.4,
                  ) ?? Colors.blue.withOpacity(0.2)
                : (isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.4)
                    : (isLastOpened && !isChild
                        // Zuletzt geöffnete Anlage: blauer Border (hat Vorrang vor Validierung)
                        ? Colors.blue.withOpacity(0.5)
                        : (isValidated
                            // Vollständige Anlage: keine grüne Border-Farbe
                            ? Color.lerp(
                                Colors.grey.withOpacity(0.15),
                                Colors.green.withOpacity(0.1),
                                0.3,
                              ) ?? Colors.grey.withOpacity(0.15)
                            // Anlage: subtiler grünlicher Border
                            : Color.lerp(
                                Colors.grey.withOpacity(0.15),
                                Colors.green.withOpacity(0.1),
                                0.3,
                              ) ?? Colors.grey.withOpacity(0.15)))),
            width: isSelected || isValidated || (isLastOpened && !isChild) ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
              _enterSelectionMode(a.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Leading Icon mit verbessertem Design
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  Theme.of(context).primaryColor.withOpacity(0.1),
                                ]
                              : (isValidated
                                  // Vollständige Anlage: keine grüne Färbung im Icon-Container
                                  ? (isChild
                                      // Bauteil: subtiler orange/beige Gradient
                                      ? [
                                          Color.lerp(
                                            disc.color.withOpacity(0.15),
                                            Colors.orange.withOpacity(0.2),
                                            0.4,
                                          ) ?? disc.color.withOpacity(0.15),
                                          Color.lerp(
                                            disc.color.withOpacity(0.08),
                                            Colors.orange.withOpacity(0.1),
                                            0.4,
                                          ) ?? disc.color.withOpacity(0.08),
                                        ]
                                      // Anlage: subtiler grünlicher Gradient
                                      : [
                                          Color.lerp(
                                            disc.color.withOpacity(0.15),
                                            Colors.green.withOpacity(0.15),
                                            0.2,
                                          ) ?? disc.color.withOpacity(0.15),
                                          Color.lerp(
                                            disc.color.withOpacity(0.08),
                                            Colors.green.withOpacity(0.08),
                                            0.2,
                                          ) ?? disc.color.withOpacity(0.08),
                                        ])
                                  : isChild
                                      // Bauteil: subtiler orange/beige Gradient
                                      ? [
                                          Color.lerp(
                                            disc.color.withOpacity(0.15),
                                            Colors.orange.withOpacity(0.2),
                                            0.4,
                                          ) ?? disc.color.withOpacity(0.15),
                                          Color.lerp(
                                            disc.color.withOpacity(0.08),
                                            Colors.orange.withOpacity(0.1),
                                            0.4,
                                          ) ?? disc.color.withOpacity(0.08),
                                        ]
                                      // Anlage: subtiler grünlicher Gradient
                                      : [
                                          Color.lerp(
                                            disc.color.withOpacity(0.15),
                                            Colors.green.withOpacity(0.15),
                                            0.2,
                                          ) ?? disc.color.withOpacity(0.15),
                                          Color.lerp(
                                            disc.color.withOpacity(0.08),
                                            Colors.green.withOpacity(0.08),
                                            0.2,
                                          ) ?? disc.color.withOpacity(0.08),
                                        ]),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isChild
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.green.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isChild ? Icons.build : disc.icon,
                        color: isChild
                            ? Color.lerp(disc.color, Colors.orange.shade700, 0.3) ?? disc.color
                            : disc.color,
                        size: isChild ? 20 : 24,
                      ),
                    ),
                    if (isValidated)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Titel und Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    a.name,
                                    style: TextStyle(
                                      fontWeight: isChild ? FontWeight.w500 : FontWeight.w600,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[900],
                                      fontSize: isChild ? 15 : 16,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLastOpened && !isChild) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Zuletzt angesehen',
                                    child: Icon(
                                      Icons.visibility,
                                      size: 16,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              () {
                                final herstellerEntries = a.params.entries
                                    .where((e) => e.key.toLowerCase() == 'hersteller')
                                    .toList();
                                return herstellerEntries.isEmpty
                                    ? (anlageBautel.isNotEmpty ? 'Typ: $anlageBautel' : '')
                                    : herstellerEntries.first.value.toString();
                              }(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}
