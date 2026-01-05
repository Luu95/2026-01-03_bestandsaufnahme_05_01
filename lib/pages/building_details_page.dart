// lib/pages/building_details_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/disziplin_manager.dart';
import '../models/project.dart';
import '../models/building.dart';
import '../models/envelope.dart';
import '../models/floor_plan.dart';
import '../models/disziplin_schnittstelle.dart';
import '../models/anlage.dart';
import '../services/floor_plan_service.dart';
import '../services/csv_service.dart';
import '../services/anlage_validation_service.dart';
import '../utils/delete_utils.dart';
import '../providers/projects_provider.dart';
import '../providers/database_provider.dart';
import 'widgets/validation_progress_widget.dart';
import 'widgets/generic_anlage_dialog.dart';

// Import der Fullscreen-Version
import 'floor_plan_page.dart';

// Tabs importieren
import 'tabs/edit_tab.dart';
import 'tabs/verbrauch_tab.dart';
import 'tabs/floorplans_tab.dart';
import 'tabs/technik_main_tab.dart';


// SystemsPage importieren
import 'systems_page.dart';
import 'csv_settings_page.dart';

class BuildingDetailsPage extends ConsumerStatefulWidget {
  const BuildingDetailsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<BuildingDetailsPage> createState() => _BuildingDetailsPageState();
}

class _BuildingDetailsPageState extends ConsumerState<BuildingDetailsPage>
    with RouteAware, TickerProviderStateMixin {
  late int _currentProjectIndex;
  late Project _currentProject;
  late int _currentBuildingIndex;
  late Building _building;
  late TabController _tabController;

  bool _isSelectionMode = false;
  final Set<int> _selectedFloorIndexes = {};

  bool _systemsSelectionMode = false;
  int _systemsSelectedCount = 0;

  late TabController _technikTabController;
  final Map<Disziplin, GlobalKey<SystemsPageState>> _systemsPageKeys = {};
  final Map<String, int> _activeSelections = {}; // Verfolgt alle aktiven Selections: Disziplin-Label -> Anzahl
  Key _technikTabKey = UniqueKey();

  bool _projectSelectionMode = false;
  final Set<int> _selectedProjectIndexes = {};

  bool _buildingSelectionMode = false;
  final Set<int> _selectedBuildingIndexes = {};

  late final AnimationController _drawerIconController;
  late final Animation<double> _drawerIconAnimation;

  int _previousTabIndex = 0;

  List<Disziplin> _disciplines = [];
  bool _disciplineSelectionMode = false;
  final Set<String> _selectedDisciplineLabels = {};
  
  // Fortschritts-Tracking für alle Anlagen
  ValidationProgress? _validationProgress;

  @override
  void initState() {
    super.initState();

    _technikTabController = TabController(length: 0, vsync: this)
      ..addListener(_onTechnikTabChanged);
    _drawerIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _drawerIconAnimation = CurvedAnimation(
      parent: _drawerIconController,
      curve: Curves.easeInOut,
    );

    // Initialisiere Projekte und Gebäude aus Provider-State
    // Diese werden später aus dem Provider-State aktualisiert
    final projectsState = ref.read(projectsProvider);
    final projects = projectsState.projects;
    final selectedProjectIndex = projectsState.selectedProjectIndex ?? -1;
    final selectedBuildingIndex = projectsState.selectedBuildingIndex ?? -1;
    
    _currentProjectIndex = selectedProjectIndex;
    if (projects.isNotEmpty && selectedProjectIndex >= 0 && selectedProjectIndex < projects.length) {
      _currentProject = projects[_currentProjectIndex];
    } else {
      _currentProject = Project(id: '', name: '', description: '', customer: '', buildings: []);
    }
    _currentBuildingIndex = selectedBuildingIndex;
    if (_currentProject.buildings.isNotEmpty && selectedBuildingIndex >= 0 && selectedBuildingIndex < _currentProject.buildings.length) {
      _building = _currentProject.buildings[_currentBuildingIndex];
    } else {
      _building = Building(
        id: '',
        name: '',
        address: '',
        postalCode: '',
        city: '',
        type: '',
        bgf: 0.0,
        constructionYear: 0,
        renovationYears: [],
        protectedMonument: false,
        units: 0,
        floorArea: 0.0,
        envelope: Envelope(
          walls: [],
          roof: Roof(type: '', uValue: 0.0, area: 0.0, insulation: false),
          floor: FloorSurface(type: '', uValue: 0.0, area: 0.0, insulated: false),
          windows: [],
        ),
        systems: BuildingSystems(),
        floors: [],
      );
    }

    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (_isSelectionMode && _tabController.index != 1) _exitFloorplansSelectionMode();
        if (_systemsSelectionMode && _tabController.index != 2) {
          // Beende alle aktiven Selections in allen Gewerken
          final activeDisciplines = _activeSelections.keys.toList();
          for (final label in activeDisciplines) {
            try {
              final discipline = _systemsPageKeys.keys.firstWhere(
                (d) => d.label == label,
              );
              _systemsPageKeys[discipline]?.currentState?.exitSelectionMode();
            } catch (e) {
              // Disziplin nicht gefunden, ignorieren
              debugPrint('Disziplin $label nicht gefunden beim Tab-Wechsel');
            }
          }
          setState(() {
            _systemsSelectionMode = false;
            _systemsSelectedCount = 0;
            _activeSelections.clear();
          });
          _drawerIconController.reverse();
        }
        if (_previousTabIndex != _tabController.index) {
          _previousTabIndex = _tabController.index;
          // Aktualisiere Fortschritt beim Tab-Wechsel
          _loadAllAnlagenForProgress();
          setState(() {});
        }
      });

    // Lade Disziplinen beim Start
    _loadDisciplines();
    // Lade alle Anlagen für Fortschrittsanzeige
    _loadAllAnlagenForProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Abonniere den RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    _technikTabController.dispose();
    _drawerIconController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Wird aufgerufen, wenn von DisziplinManager zurückgekehrt wird
    _loadDisciplines();
    // Aktualisiere auch Fortschritt
    _loadAllAnlagenForProgress();
  }
  
  /// Lädt alle Anlagen für dieses Gebäude, um den Gesamtfortschritt zu berechnen
  Future<void> _loadAllAnlagenForProgress() async {
    final dbService = ref.read(databaseServiceProvider);
    try {
      final allAnlagen = await dbService.getAnlagenByBuildingId(_building.id);
      setState(() {
        _validationProgress = AnlageValidationService.calculateProgress(allAnlagen);
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der Anlagen für Fortschritt: $e');
      setState(() {
        _validationProgress = null;
      });
    }
  }
  
  /// Zeigt das große Fortschrittsinfofeld als Dialog
  void _showProgressDialog() {
    if (_validationProgress == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: ValidationProgressWidget(
          progress: _validationProgress!,
          title: 'Gesamtfortschritt - ${_building.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDisciplines({bool clearExpandedState = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (clearExpandedState) {
      final expandedKey = 'expanded_disciplines_${_building.id}';
      await prefs.remove(expandedKey);
      _technikTabKey = UniqueKey();
    }

    final dbService = ref.read(databaseServiceProvider);
    var disciplines = await dbService.getDisciplinesByBuildingId(_building.id);
    var initialized = await dbService.isDisciplinesInitialized(_building.id);

    // Migration: alte SharedPreferences-Disziplinen einmalig nach Drift übernehmen
    final legacyKey = 'disziplinen_${_building.id}';
    final legacyJson = prefs.getString(legacyKey);
    if (!initialized && legacyJson != null) {
      try {
        final data = json.decode(legacyJson) as List<dynamic>;
        final migrated = data
            .map((e) => Disziplin.fromJson(e as Map<String, dynamic>))
            .toList();
        await dbService.replaceDisciplines(_building.id, migrated);
        await prefs.remove(legacyKey);
        disciplines = await dbService.getDisciplinesByBuildingId(_building.id);
        initialized = true;
      } catch (e) {
        debugPrint('Fehler bei Disziplinen-Migration aus SharedPreferences: $e');
      }
    }

    // Nur wenn Disziplinen noch nie initialisiert wurden, aus Anlagen extrahieren
    if (!initialized && disciplines.isEmpty) {
      try {
        final anlagen = await dbService.getAnlagenByBuildingId(_building.id);
        if (anlagen.isNotEmpty) {
          final disciplineMap = <String, Disziplin>{};
          for (final anlage in anlagen) {
            final label = anlage.discipline.label.toLowerCase();
            disciplineMap.putIfAbsent(label, () => anlage.discipline);
          }
          disciplines = disciplineMap.values.toList();
          await dbService.replaceDisciplines(_building.id, disciplines);
        }
      } catch (e) {
        debugPrint('Fehler beim Extrahieren von Disziplinen aus Anlagen: $e');
      }
    }
    
    setState(() {
      _disciplines = disciplines;
    });
    _reinitTechnikTabController();
    // SystemsPages neu laden
    _refreshSystemsPages();
  }

  void _refreshSystemsPages() {
    // Alle SystemsPages neu laden
    for (final key in _systemsPageKeys.values) {
      key.currentState?.didPopNext();
    }
    // Fortschritt aktualisieren
    _loadAllAnlagenForProgress();
  }

  Future<void> _importCsv() async {
    try {
      // Zeige Lade-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // CSV importieren
      debugPrint('Starte CSV-Import für Building: ${_building.id}');
      final anlagen = await CsvService.importAnlagenCsvForDisciplines(
        buildingId: _building.id,
        projectId: _currentProject.id,
      );

      debugPrint('CSV-Import abgeschlossen: ${anlagen.length} Anlagen gefunden');

      // Debug: Zeige Details der importierten Anlagen (inkl. Parent-LfdNummer)
      for (final anlage in anlagen) {
        debugPrint(
          'Importierte Anlage: ${anlage.name}, '
          'Lfd=${anlage.params['lfdNummer']}, '
          'ParentLfd=${anlage.params['__parentLfdNummer']}, '
          'Building: ${anlage.buildingId}, Floor: ${anlage.floorId}, '
          'Discipline: ${anlage.discipline.label}, MarkerType: ${anlage.markerType}',
        );
      }

      // Anlagen in Datenbank speichern (mit hierarchischer Struktur)
      // WICHTIG: Es werden nur neue Anlagen hinzugefügt (wenn lfdNummer nicht existiert)
      // Bestehende Anlagen werden nicht gelöscht, um Datenverlust zu vermeiden
      final dbService = ref.read(databaseServiceProvider);
      int savedCount = 0;
      int skippedCount = 0;
      final Map<String, String> lfdToId = {}; // lfdNummer -> finale DB-ID (für parentId)
      for (final anlage in anlagen) {
          try {
            // Prüfe, ob eine lfdNummer in den Params vorhanden ist
            final lfdNummer = anlage.params['lfdNummer']?.toString();
            if (lfdNummer != null && lfdNummer.isNotEmpty) {
              // Suche nach bestehender Anlage mit derselben lfdNummer
              final existingAnlage = await dbService.getAnlageByLfdNummer(lfdNummer, _building.id);
              if (existingAnlage != null) {
                // Anlage mit dieser lfdNummer existiert bereits - überspringen
                skippedCount++;
                debugPrint('Anlage übersprungen (existiert bereits): ${anlage.name} (lfd Nummer: $lfdNummer)');
                // ID für parentId-Auflösung trotzdem speichern
                lfdToId[lfdNummer] = existingAnlage.id;
              } else {
                // parentId über __parentLfdNummer auflösen (Bauteil)
                final parentLfd = anlage.params['__parentLfdNummer']?.toString();
                String? resolvedParentId;
                if (parentLfd != null && parentLfd.isNotEmpty) {
                  resolvedParentId = lfdToId[parentLfd];
                  resolvedParentId ??= (await dbService.getAnlageByLfdNummer(parentLfd, _building.id))?.id;
                }

                final cleanedParams = Map<String, dynamic>.from(anlage.params);
                cleanedParams.remove('__parentLfdNummer');

                final toInsert = Anlage(
                  id: anlage.id,
                  parentId: resolvedParentId,
                  name: anlage.name,
                  params: cleanedParams,
                  floorId: anlage.floorId,
                  buildingId: anlage.buildingId,
                  isMarker: anlage.isMarker,
                  markerInfo: anlage.markerInfo,
                  markerType: anlage.markerType,
                  discipline: anlage.discipline,
                );

                // Neue Anlage einfügen
                await dbService.insertAnlage(toInsert);
                savedCount++;
                debugPrint('Anlage gespeichert: ${anlage.name} (lfd Nummer: $lfdNummer, ID: ${anlage.id})');

                lfdToId[lfdNummer] = anlage.id;
              }
            } else {
              // Keine lfdNummer vorhanden - normale Einfügung
              await dbService.insertAnlage(anlage);
              savedCount++;
              debugPrint('Anlage gespeichert: ${anlage.name} (${anlage.id})');
            }
          } catch (e) {
            debugPrint('Fehler beim Speichern der Anlage ${anlage.name} (${anlage.id}): $e');
          }
        }

        debugPrint('CSV-Import: $savedCount neue Anlagen hinzugefügt, $skippedCount Anlagen übersprungen (existierten bereits)');

      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Disziplinen neu laden (wichtig, da Schema aktualisiert wurde)
      debugPrint('Lade Disziplinen neu...');
      await _loadDisciplines(clearExpandedState: true);
      // SystemsPages neu laden, damit importierte Anlagen angezeigt werden
      _refreshSystemsPages();

      // Erfolgsmeldung anzeigen
      if (mounted) {
        final message = skippedCount > 0
            ? '$savedCount neue Anlagen hinzugefügt, $skippedCount übersprungen (existierten bereits)'
            : '$savedCount neue Anlagen erfolgreich importiert';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('CSV-Import Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Fehlermeldung anzeigen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim CSV-Import: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      // Zeige Auswahl-Dialog: CSV oder ZIP mit Fotos
      final exportType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export-Typ wählen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.blue),
                title: const Text('Nur CSV exportieren'),
                subtitle: const Text('Exportiert nur die CSV-Datei ohne Fotos'),
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              ListTile(
                leading: const Icon(Icons.archive, color: Colors.green),
                title: const Text('ZIP mit Fotos exportieren'),
                subtitle: const Text('Exportiert CSV + Fotos in ZIP-Archiv'),
                onTap: () => Navigator.of(context).pop('zip'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      );

      if (exportType == null) return;

      // Zeige Lade-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Alle Anlagen für dieses Gebäude laden
      debugPrint('Starte Export für Building: ${_building.id}');
      final dbService = ref.read(databaseServiceProvider);
      final anlagen = await dbService.getAnlagenByBuildingId(_building.id);

      debugPrint('Export: ${anlagen.length} Anlagen gefunden');

      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (anlagen.isEmpty) {
        // Fehlermeldung anzeigen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Anlagen zum Exportieren vorhanden'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (exportType == 'csv') {
        // Nur CSV exportieren
        await CsvService.exportAnlagenCsvForDisciplines(
          anlagen: anlagen,
          projectId: _currentProject.id,
        );

        debugPrint('CSV-Export abgeschlossen');

        // Erfolgsmeldung anzeigen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${anlagen.length} Anlagen erfolgreich exportiert'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (exportType == 'zip') {
        // ZIP mit Fotos exportieren - zeige Dialog für Ordnerstruktur
        final structure = await showDialog<PhotoExportStructure>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ordnerstruktur wählen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue),
                  title: const Text('Nach Anlagen'),
                  subtitle: const Text('Jede Anlage hat einen eigenen Ordner'),
                  onTap: () => Navigator.of(context).pop(PhotoExportStructure.byAnlage),
                ),
                ListTile(
                  leading: const Icon(Icons.category, color: Colors.green),
                  title: const Text('Nach Gewerken'),
                  subtitle: const Text('Fotos nach Gewerken gruppiert'),
                  onTap: () => Navigator.of(context).pop(PhotoExportStructure.byGewerk),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open, color: Colors.orange),
                  title: const Text('Alle in einem Ordner'),
                  subtitle: const Text('Alle Fotos in einem Ordner'),
                  onTap: () => Navigator.of(context).pop(PhotoExportStructure.allInOne),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        );

        if (structure == null) return;

        // Zeige Lade-Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // ZIP mit Fotos exportieren
        await CsvService.exportAnlagenWithPhotos(
          anlagen: anlagen,
          projectId: _currentProject.id,
          structure: structure,
        );

        // Dialog schließen
        if (mounted) {
          Navigator.of(context).pop();
        }

        debugPrint('ZIP-Export abgeschlossen');

        // Erfolgsmeldung anzeigen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${anlagen.length} Anlagen mit Fotos erfolgreich exportiert'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Export Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Fehlermeldung anzeigen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim CSV-Export: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _reinitTechnikTabController() {
    _technikTabController.dispose();
    _technikTabController = TabController(length: _disciplines.length, vsync: this)
      ..addListener(_onTechnikTabChanged);
    _systemsPageKeys.clear();
    for (var d in _disciplines) {
      _systemsPageKeys[d] = GlobalKey<SystemsPageState>();
    }
  }

  void _onTechnikTabChanged() {
    // Wird nicht mehr verwendet, da wir ExpansionTiles statt Tabs haben
    // Behalten für Kompatibilität, aber keine Aktion
  }

  void _onDisciplineExpanded(Disziplin? discipline) {
    // Falls gerade eine Auswahl aktiv ist, merken wir uns alle aktiven Disziplinen,
    // damit wir die zugehörigen SystemsPages nach dem State-Update sauber beenden können.
    final activeDisciplines = _systemsSelectionMode 
        ? _activeSelections.keys.toList() 
        : <String>[];

    setState(() {
      // Beende Auswahlmodus wenn Disziplin gewechselt wird
      if (_systemsSelectionMode) {
        _systemsSelectionMode = false;
        _systemsSelectedCount = 0;
        _activeSelections.clear();
        _drawerIconController.reverse();
      }
    });

    // Wichtig: Wenn noch SystemsPages im Selection-Mode hängen, sauber beenden.
    // (Kann passieren, wenn mehrere Gewerke gleichzeitig aufgeklappt sind.)
    if (activeDisciplines.isNotEmpty) {
      for (final label in activeDisciplines) {
        try {
          final disc = _systemsPageKeys.keys.firstWhere(
            (d) => d.label == label,
          );
          _systemsPageKeys[disc]?.currentState?.exitSelectionMode();
        } catch (e) {
          // Disziplin nicht gefunden, ignorieren
          debugPrint('Disziplin $label nicht gefunden beim Discipline-Expand');
        }
      }
    }
  }

  void _exitFloorplansSelectionMode() {
    // 1) State sofort ändern, Header-Farbe wechselt direkt
    setState(() {
      _isSelectionMode = false;
      _selectedFloorIndexes.clear();
    });
    // 2) Icon zurückdrehen
    _drawerIconController.reverse();
  }


  Future<void> _deleteSelectedFloors() async {
    final toDelete = _selectedFloorIndexes.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final idx in toDelete) {
      await FloorPlanService.deleteFloor(
        buildingId: _building.id,
        floorId: _building.floors[idx].id,
        floorList: _building.floors,
        indexInList: idx,
      );
    }
    await ref.read(projectsProvider.notifier).updateBuilding(_building);
    _exitFloorplansSelectionMode();
    if (mounted) setState(() {});
  }

  void _onFloorTap(int idx) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedFloorIndexes.contains(idx)) {
          _selectedFloorIndexes.remove(idx);
          if (_selectedFloorIndexes.isEmpty) {
            _exitFloorplansSelectionMode();
          }
        } else {
          _selectedFloorIndexes.add(idx);
        }
      });
    } else {
      final floor = _building.floors[idx];
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FloorPlanFullScreen(
            building: _building,
            floor: floor,
          ),
          transitionsBuilder: (_, animation, __, child) {
            final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      ).then((_) {
        ref.read(projectsProvider.notifier).updateBuilding(_building);
      });
    }
  }

  void _onFloorLongPress(int idx) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedFloorIndexes.add(idx);
      });
      _drawerIconController.forward();
    }
  }

  Future<void> _onDeleteSingleFloor(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.zero,
        title: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: const Text(
            'Grundriss löschen?',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        content: const Text(
          'Möchtest du den ausgewählten Grundriss wirklich löschen?',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FloorPlanService.deleteFloor(
        buildingId: _building.id,
        floorId: _building.floors[idx].id,
        floorList: _building.floors,
        indexInList: idx,
      );
      await ref.read(projectsProvider.notifier).updateBuilding(_building);
      if (mounted) setState(() {});
    }
  }

  void _showAddProjectDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Projekt erstellen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name des Projekts'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final neueId = DateTime.now().millisecondsSinceEpoch.toString();
      final newProject = Project(
        id: neueId,
        name: nameController.text.trim(),
        description: '',
        customer: '',
        buildings: [],
      );

      await ref.read(projectsProvider.notifier).addProject(newProject);
      final projectsState = ref.read(projectsProvider);
      if (projectsState.projects.length == 1) {
        ref.read(projectsProvider.notifier).selectProject(0);
      }
    }
  }

  // ignore: unused_element
  Future<void> _deleteSelectedProjects() async {
    final count = _selectedProjectIndexes.length;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 28,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Projekte löschen?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Möchtest du $count ausgewählte Projekt${count > 1 ? 'e' : ''} wirklich löschen?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Diese Aktion kann nicht rückgängig gemacht werden',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Abbrechen',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Löschen',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      final toDeleteProjects = _selectedProjectIndexes.toList()..sort((a, b) => b.compareTo(a));
      
      // Lösche zuerst alle Gebäude in den Projekten
      final projectsState = ref.read(projectsProvider);
      for (var projIdx in toDeleteProjects) {
        if (projIdx >= 0 && projIdx < projectsState.projects.length) {
          final project = projectsState.projects[projIdx];
          if (project.buildings.isNotEmpty) {
            final buildingIndexes = List<int>.generate(project.buildings.length, (i) => i);
            await ref.read(projectsProvider.notifier).deleteBuildings(buildingIndexes);
          }
        }
      }
      
      await ref.read(projectsProvider.notifier).deleteProjects(toDeleteProjects);
      
      setState(() {
        _projectSelectionMode = false;
        _selectedProjectIndexes.clear();
      });
      
      Navigator.of(context).pop();
    }
  }

  void _showAddBuildingDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Gebäude erstellen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name des Gebäudes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final neueId = DateTime.now().millisecondsSinceEpoch.toString();
      final neuesBuilding = Building(
        id: neueId,
        name: nameController.text.trim(),
        address: '',
        postalCode: '',
        city: '',
        type: '',
        bgf: 0.0,
        constructionYear: 0,
        renovationYears: <int>[],
        protectedMonument: false,
        units: 0,
        floorArea: 0.0,
        envelope: Envelope(
          walls: [],
          roof: Roof(type: '', uValue: 0.0, area: 0.0, insulation: false),
          floor: FloorSurface(type: '', uValue: 0.0, area: 0.0, insulated: false),
          windows: [],
        ),
        systems: BuildingSystems(),
        floors: <FloorPlan>[],
      );

      await ref.read(projectsProvider.notifier).addBuilding(neuesBuilding);
    }
  }

  Future<void> _deleteSelectedBuildingsInDrawer() async {
    final count = _selectedBuildingIndexes.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 28,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gebäude löschen?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Möchtest du $count ausgewählte Gebäude wirklich löschen?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Diese Aktion kann nicht rückgängig gemacht werden',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Abbrechen',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Löschen',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final toDelete = _selectedBuildingIndexes.toList()..sort((a, b) => b.compareTo(a));

    /*setState(() {
      for (final idx in toDelete) {
        if (idx >= 0 && idx < _currentProject.buildings.length) {
          _currentProject.buildings.removeAt(idx);
        }
      }

      if (_currentProject.buildings.isEmpty) {
        _currentBuildingIndex = -1;
        _building = Building(
          id: '',
          name: '',
          address: '',
          postalCode: '',
          city: '',
          type: '',
          bgf: 0.0,
          constructionYear: 0,
          renovationYears: <int>[],
          protectedMonument: false,
          units: 0,
          floorArea: 0.0,
          envelope: Envelope(
            walls: [],
            roof: Roof(type: '', uValue: 0.0, area: 0.0, insulation: false),
            floor: FloorSurface(type: '', uValue: 0.0, area: 0.0, insulated: false),
            windows: [],
          ),
          systems: BuildingSystems(),
          floors: <FloorPlan>[],
        );
      } else {
        if (_currentBuildingIndex >= _currentProject.buildings.length) {
          _currentBuildingIndex = _currentProject.buildings.length - 1;
        }
        if (_currentBuildingIndex >= 0) {
          _building = _currentProject.buildings[_currentBuildingIndex];
        }
      }

      _drawerIconController.reverse();
      _buildingSelectionMode = false;
      _selectedBuildingIndexes.clear();
    });*/

    await ref.read(projectsProvider.notifier).deleteBuildings(toDelete);
    
    setState(() {
      _buildingSelectionMode = false;
      _selectedBuildingIndexes.clear();
    });
  }

  void _switchProject(int idx) {
    if (_projectSelectionMode) {
      setState(() {
        if (_selectedProjectIndexes.contains(idx)) {
          _selectedProjectIndexes.remove(idx);
          if (_selectedProjectIndexes.isEmpty) {
            _drawerIconController.reverse();
            _projectSelectionMode = false;
          }
        } else {
          _drawerIconController.reset();
          _buildingSelectionMode = false;
          _selectedBuildingIndexes.clear();

          _selectedProjectIndexes.add(idx);
          _drawerIconController.forward();
        }
      });
      return;
    }

    if (idx == _currentProjectIndex) return;

    ref.read(projectsProvider.notifier).selectProject(idx);
    // Disziplinen für das neue Projekt/Gebäude laden
    _loadDisciplines();
  }

  void _switchBuilding(int idx) {
    if (_buildingSelectionMode) {
      setState(() {
        if (_selectedBuildingIndexes.contains(idx)) {
          _selectedBuildingIndexes.remove(idx);
          if (_selectedBuildingIndexes.isEmpty) {
            _drawerIconController.reverse();
            _buildingSelectionMode = false;
          }
        } else {
          _drawerIconController.reset();
          _projectSelectionMode = false;
          _selectedProjectIndexes.clear();

          _selectedBuildingIndexes.add(idx);
          _drawerIconController.forward();
        }
      });
      return;
    }

    if (idx == _currentBuildingIndex) return;

    setState(() {
      _currentBuildingIndex = idx;
      _building = _currentProject.buildings[_currentBuildingIndex];
    });
    ref.read(projectsProvider.notifier).selectBuilding(idx);
    // Disziplinen für das neue Gebäude laden
    _loadDisciplines();
  }

  void _onDrawerChanged(bool isOpen) {
    if (isOpen) {
      _drawerIconController.forward();
    } else {
      _drawerIconController.reverse();
      setState(() {
        _projectSelectionMode = false;
        _selectedProjectIndexes.clear();
        _buildingSelectionMode = false;
        _selectedBuildingIndexes.clear();
      });
    }
  }


  void _onSystemsSelectionChanged(bool isActive, int selectedCount, Disziplin discipline) {
    // Aktualisiere die Map der aktiven Selections
    if (isActive) {
      _activeSelections[discipline.label] = selectedCount;
    } else {
      _activeSelections.remove(discipline.label);
    }

    // Berechne die Gesamtzahl der ausgewählten Anlagen über alle Gewerke
    final totalCount = _activeSelections.values.fold(0, (sum, count) => sum + count);
    final hasAnySelection = _activeSelections.isNotEmpty;

    // 1) State sofort ändern, Header-Farbe wechselt direkt
    setState(() {
      _systemsSelectionMode = hasAnySelection;
      _systemsSelectedCount = totalCount;
    });

    // 2) Icon danach drehen
    if (hasAnySelection) {
      _drawerIconController.forward();
    } else {
      _drawerIconController.reverse();
    }
  }

  Future<void> _openAddAnlageDialogDirect(Disziplin discipline) async {
    // Direkter Dialog, funktioniert auch wenn das Gewerk zugeklappt ist (SystemsPageState ist dann null).
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: discipline,
        buildingId: _building.id,
        floorId: 'global',
        existingAnlage: null,
        index: null,
        onSave: (newAnlage, _) async {
          final dbService = ref.read(databaseServiceProvider);
          final existing = await dbService.getAnlageById(newAnlage.id);
          if (existing != null) {
            await dbService.updateAnlage(newAnlage);
          } else {
            await dbService.insertAnlage(newAnlage);
          }

          if (!mounted) return;
          await _loadAllAnlagenForProgress();
          _refreshSystemsPages();
          _exitDisciplineSelectionMode(); // AppBar schließen nach Erstellung
        },
      ),
    );
  }

  void _enterDisciplineSelectionMode(Disziplin discipline) {
    // Beende ggf. Systems-Selection (Anlagen-Auswahl) in allen Gewerken
    if (_systemsSelectionMode) {
      final activeDisciplines = _activeSelections.keys.toList();
      for (final label in activeDisciplines) {
        try {
          final disc = _systemsPageKeys.keys.firstWhere((d) => d.label == label);
          _systemsPageKeys[disc]?.currentState?.exitSelectionMode();
        } catch (_) {}
      }
    }

    setState(() {
      _systemsSelectionMode = false;
      _systemsSelectedCount = 0;
      _activeSelections.clear();
      _disciplineSelectionMode = true;
      _selectedDisciplineLabels
        ..clear()
        ..add(discipline.label);
    });
    _drawerIconController.forward();
  }

  void _exitDisciplineSelectionMode() {
    setState(() {
      _disciplineSelectionMode = false;
      _selectedDisciplineLabels.clear();
    });
    _drawerIconController.reverse();
  }

  void _toggleDisciplineSelection(Disziplin discipline) {
    setState(() {
      if (!_disciplineSelectionMode) {
        _disciplineSelectionMode = true;
        _selectedDisciplineLabels
          ..clear()
          ..add(discipline.label);
        _drawerIconController.forward();
        return;
      }

      if (_selectedDisciplineLabels.contains(discipline.label)) {
        _selectedDisciplineLabels.remove(discipline.label);
        if (_selectedDisciplineLabels.isEmpty) {
          _disciplineSelectionMode = false;
          _drawerIconController.reverse();
        }
      } else {
        _selectedDisciplineLabels.add(discipline.label);
      }
    });
  }

  Disziplin? _getSingleSelectedDiscipline() {
    if (_selectedDisciplineLabels.length != 1) return null;
    final label = _selectedDisciplineLabels.first;
    try {
      return _systemsPageKeys.keys.firstWhere((d) => d.label == label);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onAnlageCreatedFromSystemsPage() async {
    // Wenn wir gerade im Gewerk-Auswahlmodus waren: danach wieder schließen
    if (_disciplineSelectionMode) {
      _exitDisciplineSelectionMode();
    }
    await _loadAllAnlagenForProgress();
  }

  Future<void> _onBauteilCreatedFromSystemsPage() async {
    // SystemsPage beendet den SelectionMode bereits selbst; hier nur Progress aktualisieren.
    await _loadAllAnlagenForProgress();
  }

  Future<void> _editSelectedDiscipline() async {
    final d = _getSingleSelectedDiscipline();
    if (d == null) return;

    final edited = await showDialog<Disziplin>(
      context: context,
      builder: (_) => DisziplinEditDialog(disziplin: d),
    );
    if (edited == null) return;

    final success = await updateDiscipline(
      context,
      d,
      edited,
      _building.id,
    );
    if (success) {
      await _loadDisciplines();
      _exitDisciplineSelectionMode();
    }
  }

  Future<void> _deleteSelectedDiscipline() async {
    if (_selectedDisciplineLabels.isEmpty) return;

    final dbService = ref.read(databaseServiceProvider);
    // Sammle Anlagen für alle selektierten Disziplinen
    final labels = _selectedDisciplineLabels.toList();
    final anlagenPerLabel = <String, List<Anlage>>{};
    int totalAnlagen = 0;
    for (final label in labels) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(_building.id, label);
      anlagenPerLabel[label] = anlagen;
      totalAnlagen += anlagen.length;
    }

    if (totalAnlagen > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 28,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Gewerk${labels.length > 1 ? 'e' : ''} hat noch Anlagen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$totalAnlagen Anlage${totalAnlagen > 1 ? 'n' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels.length == 1 ? 'in "${labels.first}"' : 'in ${labels.length} Gewerken',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Wenn du die Disziplin löschst, werden auch alle zugehörigen Anlagen unwiderruflich gelöscht.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Diese Aktion kann nicht rückgängig gemacht werden',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Abbrechen',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Alles löschen',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;

      // Anlagen aus der Datenbank löschen
      for (final entry in anlagenPerLabel.entries) {
        for (final a in entry.value) {
          await dbService.deleteAnlage(a.id);
        }
      }
    } else {
      final name = labels.length == 1 ? labels.first : '${labels.length} Gewerke';
      final confirmed = await showDeleteConfirmationDialog(context, 'Disziplin', name);
      if (!confirmed) return;
    }

    for (final label in labels) {
      await dbService.deleteDiscipline(_building.id, label);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${labels.length == 1 ? labels.first : '${labels.length} Gewerke'} gelöscht')),
    );

    await _loadDisciplines();
    _exitDisciplineSelectionMode();
  }

  Future<void> _openBulkAddBauteilForSystemsSelection() async {
    final activeLabels = _activeSelections.keys.toList();
    if (activeLabels.isEmpty) return;

    // Da der Button nur angezeigt wird, wenn genau ein Gewerk ausgewählt ist,
    // können wir direkt öffnen ohne Zwischenauswahl
    if (activeLabels.length == 1) {
      try {
        final discipline = _systemsPageKeys.keys.firstWhere((d) => d.label == activeLabels.first);
        _systemsPageKeys[discipline]?.currentState?.openAddBauteilDialogForSelection();
      } catch (e) {
        debugPrint('Disziplin ${activeLabels.first} nicht gefunden beim Bauteil-Hinzufügen');
      }
    }
  }

  Future<void> _openMoveDialogForSystemsSelection() async {
    final activeLabels = _activeSelections.keys.toList();
    if (activeLabels.isEmpty) return;

    // Da der Button nur angezeigt wird, wenn genau ein Gewerk ausgewählt ist,
    // können wir direkt öffnen ohne Zwischenauswahl
    if (activeLabels.length == 1) {
      try {
        final discipline = _systemsPageKeys.keys.firstWhere((d) => d.label == activeLabels.first);
        _systemsPageKeys[discipline]?.currentState?.moveSelectedAnlagen();
      } catch (e) {
        debugPrint('Disziplin ${activeLabels.first} nicht gefunden beim Verschieben');
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    // Aktualisiere lokale Variablen aus Provider-State
    final projectsState = ref.watch(projectsProvider);
    final projects = projectsState.projects;
    final selectedProjectIndex = projectsState.selectedProjectIndex ?? -1;
    final selectedBuildingIndex = projectsState.selectedBuildingIndex ?? -1;
    
    if (selectedProjectIndex >= 0 && selectedProjectIndex < projects.length) {
      _currentProjectIndex = selectedProjectIndex;
      _currentProject = projects[selectedProjectIndex];
    }
    
    if (_currentProject.buildings.isNotEmpty && selectedBuildingIndex >= 0 && selectedBuildingIndex < _currentProject.buildings.length) {
      final newBuilding = _currentProject.buildings[selectedBuildingIndex];
      // Prüfe, ob sich das Gebäude geändert hat
      if (_building.id != newBuilding.id) {
        _currentBuildingIndex = selectedBuildingIndex;
        _building = newBuilding;
        // Disziplinen für das neue Gebäude laden
        _loadDisciplines();
      } else {
        _currentBuildingIndex = selectedBuildingIndex;
        _building = newBuilding;
      }
    }
    
    if (projects.isEmpty) {
      return Scaffold(
        drawer: _buildDrawer(context),
        onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            'Keine Projekte vorhanden',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Es sind derzeit keine Projekte hinterlegt.\nLege über das Menü (☰) ein neues Projekt an.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ),
      );
    }

    if (_currentProject.buildings.isEmpty) {
      return Scaffold(
        drawer: _buildDrawer(context),
        onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Color(0xFFEEEEEE),
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Text(
            '„${_currentProject.name}“: Keine Gebäude',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Dieses Projekt enthält momentan keine Gebäude.\nLege über das Menü (☰) ein neues Gebäude an.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ),
      );
    }

    final isFloorplansTab = _tabController.index == 1;
    final inFloorplansSelection = isFloorplansTab && _isSelectionMode;

    final isTechnikTab = _tabController.index == 2;
    final inSystemsSelection = isTechnikTab && _systemsSelectionMode;
    final inDisciplineSelection = isTechnikTab && _disciplineSelectionMode;

    final inSelectionMode = inFloorplansSelection || inSystemsSelection || inDisciplineSelection;

    String appBarTitle;
    if (inFloorplansSelection) {
      appBarTitle = '${_selectedFloorIndexes.length} ausgewählt';
    } else if (inSystemsSelection) {
      appBarTitle = '$_systemsSelectedCount ausgewählt';
    } else if (inDisciplineSelection) {
      appBarTitle = '${_selectedDisciplineLabels.length} ausgewählt';
    } else {
      appBarTitle = _building.name;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFFEEEEEE),
        systemNavigationBarDividerColor: Color(0xFFEEEEEE),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFEEEEEE),
        drawer: _buildDrawer(context),
      onDrawerChanged: _onDrawerChanged,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: inSelectionMode 
            ? const Color(0xFF4B5563) // Edles, professionelles Grau statt Blau
            : Colors.white,
        iconTheme: IconThemeData(
          color: inSelectionMode ? Colors.white : Colors.black87,
        ),
        leading: Builder(
          builder: (innerContext) {
            return IconButton(
              onPressed: () {
                if (inSelectionMode) {
                  if (inFloorplansSelection) {
                    _exitFloorplansSelectionMode();
                  } else if (inSystemsSelection) {
                    // Beende alle aktiven Selections in allen Gewerken
                    final activeDisciplines = _activeSelections.keys.toList();
                    for (final label in activeDisciplines) {
                      try {
                        final discipline = _systemsPageKeys.keys.firstWhere(
                          (d) => d.label == label,
                        );
                        _systemsPageKeys[discipline]?.currentState?.exitSelectionMode();
                      } catch (e) {
                        // Disziplin nicht gefunden, ignorieren
                        debugPrint('Disziplin $label nicht gefunden beim Exit');
                      }
                    }
                    setState(() {
                      _systemsSelectionMode = false;
                      _systemsSelectedCount = 0;
                      _activeSelections.clear();
                    });
                    _drawerIconController.reverse();
                  } else if (inDisciplineSelection) {
                    _exitDisciplineSelectionMode();
                  }
                } else {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _drawerIconAnimation,
                color: inSelectionMode ? Colors.white : Colors.black87,
              ),
            );
          },
        ),

        title: Row(
          children: [
            Expanded(
              child: Text(
                appBarTitle,
                style: TextStyle(
                  color: inSelectionMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Kompakter Fortschrittsbalken (nur wenn nicht im Selection Mode)
            if (!inSelectionMode && _validationProgress != null && _validationProgress!.total > 0)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: GestureDetector(
                  onTap: _showProgressDialog,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 60,
                      maxWidth: 90,
                      minHeight: 4,
                      maxHeight: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _validationProgress!.percentage / 100,
                        minHeight: 4,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _validationProgress!.percentage >= 100
                              ? Colors.green[400]!
                              : _validationProgress!.percentage >= 80
                                  ? Colors.orange[400]!
                                  : Colors.blue[400]!,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: inSelectionMode
            ? [] // Buttons werden jetzt als Floating Action Buttons rechts unten angezeigt
            : [],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 0. EDIT‐Tab
          EditTab(
            building: _building,
            index: _currentBuildingIndex,
          ),

          // 1. FLOORPLANS‐Tab
          FloorPlansTab(
            building: _building,
            index: _currentBuildingIndex,
            onAddFloor: _addNewFloorAndUpload,
            isSelectionMode: _isSelectionMode,
            selectedFloorIndexes: _selectedFloorIndexes,
            onFloorTap: _onFloorTap,
            onFloorLongPress: _onFloorLongPress,
            onDeleteSingleFloor: _onDeleteSingleFloor,
          ),

          // 2. TECHNIK‐Tab
          // neu: mit controller & keys
          TechnikMainTab(
            key: _technikTabKey,
            building: _building,
            index: _currentBuildingIndex,
            tabController: _technikTabController,
            systemsPageKeys: _systemsPageKeys,
            onSelectionChanged: _onSystemsSelectionChanged,
            onDisciplineExpanded: _onDisciplineExpanded,
            onDisciplineLongPress: _enterDisciplineSelectionMode,
            disciplineSelectionMode: _tabController.index == 2 && _disciplineSelectionMode,
            selectedDisciplineLabels: _selectedDisciplineLabels,
            onDisciplineSelectionToggle: _toggleDisciplineSelection,
            onAnlageCreated: () {
              _onAnlageCreatedFromSystemsPage();
            },
            onBauteilCreated: () {
              _onBauteilCreatedFromSystemsPage();
            },
            onAnlagenMoved: () {
              // Alle SystemsPages neu laden, nachdem Anlagen verschoben wurden
              _refreshSystemsPages();
            },
            onSchemaUpdated: () async {
              // Disziplinen neu laden, nachdem das Schema bearbeitet wurde
              await _loadDisciplines();
            },
            onImportCsv: _importCsv,
            isAnySelectionActive: () => _systemsSelectionMode,
          ),


          // 3. VERBRAUCH‐Tab
          VerbrauchTab(building: _building),
        ],
      ),

      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEEE),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom * 0.4,
            top: 4.0,
            left: 10.0,
            right: 10.0,
          ),
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              return TabBar(
                controller: _tabController,
                indicator: const BoxDecoration(color: Colors.transparent),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black,
                labelStyle:
                const TextStyle(fontSize: 9, fontWeight: FontWeight.w400),
                unselectedLabelStyle: const TextStyle(fontSize: 9),
                tabs: [
                  _buildTabWithIconBackground(
                    icon: Icons.edit,
                    text: 'Bearbeiten',
                    index: 0,
                  ),
                  _buildTabWithIconBackground(
                    icon: Icons.map,
                    text: 'Grundrisse',
                    index: 1,
                  ),
                  _buildTabWithIconBackground(
                    icon: Icons.settings,
                    text: 'Technik',
                    index: 2,
                  ),
                  _buildTabWithIconBackground(
                    icon: Icons.bar_chart,
                    text: 'Verbrauch',
                    index: 3,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  /// Erstellt elegante Floating Action Buttons rechts unten basierend auf dem Selection-Mode
  Widget? _buildFloatingActionButtons() {
    final inSelectionMode = _isSelectionMode || _systemsSelectionMode || _disciplineSelectionMode;
    final inFloorplansSelection = _isSelectionMode && _tabController.index == 1;
    final inSystemsSelection = _systemsSelectionMode && _tabController.index == 2;
    final inDisciplineSelection = _disciplineSelectionMode && _tabController.index == 2;

    // Grundriss-Tab: Button zum Hochladen (wenn nicht im Selection Mode)
    if (_tabController.index == 1 && !inSelectionMode) {
      return FloatingActionButton(
        onPressed: _addNewFloorAndUpload,
        tooltip: 'Grundriss hochladen',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.download, color: Colors.white),
      );
    }

    // Selection Mode: Zeige mehrere Buttons vertikal angeordnet
    if (inSelectionMode) {
      final List<Widget> buttons = [];

      if (inDisciplineSelection) {
        // Gewerk-Auswahl: Bearbeiten, Hinzufügen, Löschen
        if (_selectedDisciplineLabels.length == 1) {
          buttons.add(
            _buildFloatingActionButton(
              icon: Icons.edit,
              tooltip: 'Gewerk bearbeiten',
              onPressed: _editSelectedDiscipline,
              backgroundColor: Colors.blue,
            ),
          );
          buttons.add(
            _buildFloatingActionButton(
              icon: Icons.add,
              tooltip: 'Anlage hinzufügen',
              onPressed: () async {
                final d = _getSingleSelectedDiscipline();
                if (d != null) {
                  await _openAddAnlageDialogDirect(d);
                }
              },
              backgroundColor: Colors.green,
            ),
          );
        }
        buttons.add(
          _buildFloatingActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Gewerk löschen',
            onPressed: _deleteSelectedDiscipline,
            backgroundColor: Colors.red,
          ),
        );
      } else if (inSystemsSelection) {
        // Anlagen-Auswahl: Bauteil hinzufügen, Verschieben, Löschen
        if (_activeSelections.keys.length == 1) {
          buttons.add(
            _buildFloatingActionButton(
              icon: Icons.add,
              tooltip: 'Bauteil hinzufügen',
              onPressed: _openBulkAddBauteilForSystemsSelection,
              backgroundColor: Colors.green,
            ),
          );
          buttons.add(
            _buildFloatingActionButton(
              icon: Icons.drive_file_move,
              tooltip: 'Verschieben',
              onPressed: _openMoveDialogForSystemsSelection,
              backgroundColor: Colors.orange,
            ),
          );
        }
        buttons.add(
          _buildFloatingActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Ausgewählte Anlagen löschen',
            onPressed: _handleDeleteSelectedAnlagen,
            backgroundColor: Colors.red,
          ),
        );
      } else if (inFloorplansSelection) {
        // Grundriss-Auswahl: Löschen
        buttons.add(
          _buildFloatingActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Ausgewählte Grundrisse löschen',
            onPressed: _handleDeleteSelectedFloors,
            backgroundColor: Colors.red,
          ),
        );
      }

      if (buttons.isEmpty) return null;

      // Zeige Buttons vertikal angeordnet
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buttons.reversed.toList(),
      );
    }

    return null;
  }

  /// Erstellt einen einzelnen eleganten Floating Action Button
  Widget _buildFloatingActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: backgroundColor,
        elevation: 4,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  /// Handler für das Löschen ausgewählter Anlagen
  Future<void> _handleDeleteSelectedAnlagen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 28,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Anlagen löschen?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$_systemsSelectedCount Anlage${_systemsSelectedCount > 1 ? 'n' : ''} ausgewählt',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Möchtest du diese wirklich löschen?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Diese Aktion kann nicht rückgängig gemacht werden',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Abbrechen',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Löschen',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      // Lösche alle ausgewählten Anlagen aus allen aktiven Gewerken
      final activeDisciplines = _activeSelections.keys.toList();
      for (final label in activeDisciplines) {
        try {
          final discipline = _systemsPageKeys.keys.firstWhere(
            (d) => d.label == label,
          );
          _systemsPageKeys[discipline]?.currentState?.deleteSelectedAnlagen();
        } catch (e) {
          // Disziplin nicht gefunden, ignorieren
          debugPrint('Disziplin $label nicht gefunden beim Löschen');
        }
      }
    }
  }

  /// Handler für das Löschen ausgewählter Grundrisse
  Future<void> _handleDeleteSelectedFloors() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.zero,
        title: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: const Text(
            'Grundrisse löschen?',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        content: Text(
          'Möchtest du ${_selectedFloorIndexes.length} ausgewählte Grundrisse wirklich löschen?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteSelectedFloors();
    }
  }

  Widget _buildTabWithIconBackground({
    required IconData icon,
    required String text,
    required int index,
  }) {
    final isSelected = _tabController.index == index;
    return Tab(
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewFloorAndUpload() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newFloor = FloorPlan(id: newId, name: '');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final originalPath = result.files.single.path!;
    final originalName = result.files.single.name;

    final appDir = await getApplicationDocumentsDirectory();
    final newPath = path.join(appDir.path, '${_building.id}_$newId.pdf');
    final newFile = await File(originalPath).copy(newPath);

    newFloor.pdfPath = newFile.path;
    newFloor.pdfName = originalName;

    // PDF-Pfade werden jetzt in Drift gespeichert, keine SharedPreferences mehr nötig
    setState(() {
      _building.floors.add(newFloor);
    });
    await ref.read(projectsProvider.notifier).updateBuilding(_building);

    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FloorPlanFullScreen(
          building: _building,
          floor: newFloor,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    await ref.read(projectsProvider.notifier).updateBuilding(_building);
  }

  Widget _buildDrawer(BuildContext context) {
    final projectsState = ref.read(projectsProvider);
    final projects = projectsState.projects;
    
    return Drawer(
      width: 320,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: SafeArea(
          child: Column(
            children: [

            if (_projectSelectionMode)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _drawerIconController.reverse();
                          setState(() {
                            _projectSelectionMode = false;
                            _selectedProjectIndexes.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: RotationTransition(
                            turns: _drawerIconAnimation,
                            child: const Icon(Icons.close, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedProjectIndexes.length} ausgewählt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                        if (_selectedProjectIndexes.isEmpty) return;
                        final count = _selectedProjectIndexes.length;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.5),
                          builder: (ctx) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 48,
                                      color: Colors.red[600],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Projekte löschen?',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[900],
                                      letterSpacing: -0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Möchtest du $count ausgewählte Projekt${count > 1 ? 'e' : ''} wirklich löschen?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: Colors.orange[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Diese Aktion kann nicht rückgängig gemacht werden',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            'Abbrechen',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.delete, size: 20),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Löschen',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        if (confirmed != true) return;

                        final toDeleteProjects = _selectedProjectIndexes
                            .toList()
                          ..sort((a, b) => b.compareTo(a));

                        // Lösche zuerst alle Gebäude in den Projekten
                        final projectsState = ref.read(projectsProvider);
                        for (var projIdx in toDeleteProjects) {
                          if (projIdx >= 0 && projIdx < projectsState.projects.length) {
                            final project = projectsState.projects[projIdx];
                            if (project.buildings.isNotEmpty) {
                              final buildingIndexes = List<int>.generate(project.buildings.length, (i) => i);
                              await ref.read(projectsProvider.notifier).deleteBuildings(buildingIndexes);
                            }
                          }
                        }
                        
                        await ref.read(projectsProvider.notifier).deleteProjects(toDeleteProjects);
                        
                        setState(() {
                          _projectSelectionMode = false;
                          _selectedProjectIndexes.clear();
                        });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Projekte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showAddProjectDialog,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 22,
                            color: Colors.blue[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Flexible(
              flex: 2,
              child: projects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keine Projekte',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: projects.length,
                      itemBuilder: (ctx, idx) {
                        final proj = projects[idx];
                        final isSelected = idx == _currentProjectIndex;
                        final isChecked = _selectedProjectIndexes.contains(idx);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                if (!_projectSelectionMode) {
                                  _drawerIconController.reset();
                                  _buildingSelectionMode = false;
                                  _selectedBuildingIndexes.clear();

                                  setState(() {
                                    _projectSelectionMode = true;
                                    _selectedProjectIndexes.add(idx);
                                  });
                                  _drawerIconController.forward();
                                }
                              },
                              onTap: () => _switchProject(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor.withOpacity(0.15)
                                            : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.folder,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.blue[700],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        proj.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[900],
                                        ),
                                      ),
                                    ),
                                    if (_projectSelectionMode)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isChecked
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                          color: isChecked
                                              ? Theme.of(context).primaryColor
                                              : Colors.transparent,
                                        ),
                                        child: isChecked
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      )
                                    else if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).primaryColor,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (_buildingSelectionMode)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _drawerIconController.reverse();
                          setState(() {
                            _buildingSelectionMode = false;
                            _selectedBuildingIndexes.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: RotationTransition(
                            turns: _drawerIconAnimation,
                            child: const Icon(Icons.close, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedBuildingIndexes.length} ausgewählt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _deleteSelectedBuildingsInDrawer,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentProjectIndex < 0
                            ? 'Keine Projekte'
                            : 'Gebäude',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_currentProjectIndex >= 0)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _showAddBuildingDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 22,
                              color: Colors.orange[600],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            Flexible(
              flex: 3,
              child: _currentProject.buildings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keine Gebäude',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: _currentProject.buildings.length,
                      itemBuilder: (ctx, idx) {
                        final bldg = _currentProject.buildings[idx];
                        final isBldgSelected = idx == _currentBuildingIndex;
                        final isChecked = _selectedBuildingIndexes.contains(idx);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isBldgSelected
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBldgSelected
                                  ? Colors.orange.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                if (!_buildingSelectionMode) {
                                  _drawerIconController.reset();
                                  _projectSelectionMode = false;
                                  _selectedProjectIndexes.clear();

                                  setState(() {
                                    _buildingSelectionMode = true;
                                    _selectedBuildingIndexes.add(idx);
                                  });
                                  _drawerIconController.forward();
                                }
                              },
                              onTap: () => _switchBuilding(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isBldgSelected
                                            ? Colors.orange.withOpacity(0.15)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.location_city,
                                        color: isBldgSelected
                                            ? Colors.orange[700]
                                            : Colors.orange[600],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        bldg.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isBldgSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isBldgSelected
                                              ? Colors.orange[700]
                                              : Colors.grey[900],
                                        ),
                                      ),
                                    ),
                                    if (_buildingSelectionMode)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isChecked
                                                ? Colors.orange[600]!
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                          color: isChecked
                                              ? Colors.orange[600]
                                              : Colors.transparent,
                                        ),
                                        child: isChecked
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      )
                                    else if (isBldgSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.orange[700],
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.download_rounded,
                    label: 'CSV importieren',
                    color: Colors.green,
                    onTap: () => _importCsv(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.upload_rounded,
                    label: 'CSV exportieren',
                    color: Colors.blue,
                    onTap: () => _exportCsv(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.settings_rounded,
                    label: 'CSV-Einstellungen',
                    color: Colors.purple,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CsvSettingsPage(
                            projectId: _currentProject.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.tune_rounded,
                    label: 'Disziplinen',
                    color: Colors.blueGrey,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DisziplinManagerWidget(
                            buildingId: _building.id,
                          ),
                        ),
                      );
                      await _loadDisciplines();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: _getColorShade700(color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getColorShade700(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorShade700(Color color) {
    if (color is MaterialColor) {
      return color.shade700;
    }
    // Für nicht-Material-Farben, verdunkle die Farbe leicht
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }
}

extension ListFirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}