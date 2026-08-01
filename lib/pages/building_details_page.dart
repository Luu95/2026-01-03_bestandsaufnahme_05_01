// lib/pages/building_details_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/disziplin_manager.dart';
import '../theme/app_palette.dart';
import '../models/project.dart';
import '../models/building.dart';
import '../models/floor_plan.dart';
import '../models/disziplin_schnittstelle.dart';
import '../models/anlage.dart';
import '../services/floor_plan_service.dart';
import '../services/anlagen_csv_import_service.dart';
import '../services/csv_service.dart';
import '../services/template_service.dart';
import '../utils/delete_utils.dart';
import '../utils/app_log.dart';
import '../providers/projects_provider.dart';
import '../providers/database_provider.dart';
import '../providers/csv_settings_provider.dart';
import '../utils/csv_column_layout.dart';
import '../navigation/route_observer.dart';
import '../theme/app_theme.dart';
import 'widgets/generic_anlage_dialog.dart';
import 'widgets/move_anlagen_dialog.dart';

// Import der Fullscreen-Version
import 'floor_plan_page.dart';

// Tabs importieren
import 'tabs/floorplans_tab.dart';
import 'tabs/technik_main_tab.dart';


// SystemsPage importieren
import 'systems_page.dart';
import 'app_settings_page.dart';
import 'csv_settings_page.dart';
import 'recycle_bin_page.dart';
import 'widgets/confirm_delete_dialog.dart';
import 'widgets/systems_list_tile_styles.dart';
import 'widgets/building_details_fab.dart';

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

  bool _groupSelectionMode = false;
  ({
    Disziplin discipline,
    String groupKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
    bool isSchemaItemLevel,
  })? _groupSelectionContext;

  /// Zuletzt aufgeklapptes Gewerk (für Add-FAB bei mehreren Gewerken).
  Disziplin? _lastExpandedDiscipline;

  /// Gewerkevorlagen im aktuellen Projekt importiert.
  bool _hasProjectTemplates = false;

  /// Listen-Ansicht: null = Hierarchie laut CSV-Settings, sonst Param-Key.
  String? _listViewGroupingKey;
  List<String> _listViewParamKeys = [];

  /// Sentinel für PopupMenu: `value: null` wird von Flutter als Abbruch
  /// gewertet und ruft `onSelected` nicht auf.
  static const _listViewStandardGroupingValue = '__standard__';

  void _showProviderError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fehler: $e')),
    );
  }

  void _syncFromProjectsState(ProjectsState projectsState) {
    final projects = projectsState.projects;
    final selectedProjectIndex = projectsState.selectedProjectIndex ?? -1;
    final selectedBuildingIndex = projectsState.selectedBuildingIndex ?? -1;

    Project newProject = _currentProject;
    if (selectedProjectIndex >= 0 && selectedProjectIndex < projects.length) {
      newProject = projects[selectedProjectIndex];
    } else if (projects.isEmpty) {
      newProject = Project(
        id: '',
        name: '',
        description: '',
        customer: '',
        buildings: [],
      );
    }

    Building newBuilding = _building;
    if (newProject.buildings.isNotEmpty &&
        selectedBuildingIndex >= 0 &&
        selectedBuildingIndex < newProject.buildings.length) {
      newBuilding = newProject.buildings[selectedBuildingIndex];
    } else if (newProject.buildings.isEmpty) {
      newBuilding = Building(
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
        systems: BuildingSystems(),
        floors: [],
      );
    }

    final buildingChanged = _building.id != newBuilding.id;
    final projectChanged = _currentProject.id != newProject.id;

    if (!buildingChanged &&
        !projectChanged &&
        _currentProjectIndex == selectedProjectIndex &&
        _currentBuildingIndex == selectedBuildingIndex &&
        identical(_currentProject, newProject) &&
        identical(_building, newBuilding)) {
      return;
    }

    setState(() {
      _currentProjectIndex = selectedProjectIndex;
      _currentProject = newProject;
      _currentBuildingIndex = selectedBuildingIndex;
      _building = newBuilding;
    });

    if (buildingChanged && newBuilding.id.isNotEmpty) {
      _loadDisciplines();
    }
  }

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
        systems: BuildingSystems(),
        floors: [],
      );
    }

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_isSelectionMode && _tabController.index != 0) _exitFloorplansSelectionMode();
        if (_systemsSelectionMode && _tabController.index != 1) {
          // Beende alle aktiven Selections in allen Gewerken
          final activeDisciplines = _activeSelections.keys.toList();
          for (final label in activeDisciplines) {
            try {
              final discipline = _systemsPageKeys.keys.firstWhere(
                (d) => d.label == label,
              );
              _systemsPageKeys[discipline]?.currentState?.exitSelectionMode();
            } catch (e) {
              appLog('Disziplin $label nicht gefunden beim Tab-Wechsel', error: e);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentProject.id.isNotEmpty) {
        ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
      }
    });
  }

  /// Ebene 1 = Gewerk/Disziplin-Tab; Listen-Gruppierung darunter über Ebene 2.
  /// Bei „Auflisten nach“-Override: freie Spalte statt Hierarchie in der Liste.
  String? _resolveSystemsGroupingParamKey() {
    final override = _listViewGroupingKey?.trim();
    if (override != null && override.isNotEmpty) return override;
    return _resolveHierarchyGroupingParamKey();
  }

  String? _resolveSystemsSubGroupingParamKey() {
    // Freie Spalten-Ansicht ersetzt die Hierarchie-Untergruppierung in der Liste.
    final override = _listViewGroupingKey?.trim();
    if (override != null && override.isNotEmpty) return null;
    return _resolveHierarchySubGroupingParamKey();
  }

  /// Hierarchie-Keys für Platzierung/Schema – unabhängig von „Auflisten nach“.
  String? _resolveHierarchyGroupingParamKey() {
    if (_currentProject.id.isEmpty) return null;
    final settings = ref.read(csvSettingsProvider(_currentProject.id));
    return settings.resolveRevisionsfeldListGroupingParamKey();
  }

  String? _resolveHierarchySubGroupingParamKey() {
    if (_currentProject.id.isEmpty) return null;
    final settings = ref.read(csvSettingsProvider(_currentProject.id));
    return settings.resolveRevisionsobjektGroupingParamKey();
  }

  String? _resolveSystemsDisplayNameParamKey() {
    if (_currentProject.id.isEmpty) return null;
    final settings = ref.read(csvSettingsProvider(_currentProject.id));
    return settings.resolveDisplayNameParamKey();
  }

  Future<void> _refreshListViewParamKeys() async {
    final dbService = ref.read(databaseServiceProvider);
    final anlagen = await dbService.getAnlagenByBuildingId(_building.id);
    final keys = <String>{};

    bool isUsableListViewKey(String raw) {
      final k = raw.trim();
      if (k.isEmpty) return false;
      if (isInternalExportParamKey(k)) return false;
      if (CsvSettings.isAnlagenCsvColumnParamKey(k)) return false;
      if (CsvSettings.isAttSlotParamKey(k)) return false;
      if (k.startsWith('_')) return false;
      if (k == 'lfdNummer' || k == 'photoPaths') return false;
      if (k == CsvSettings.qrCodeNummerParamKey) return false;
      // Options-/Typ-Listen als Key (z. B. "ausgebaut| außer Betrieb|") ausblenden.
      if (k.contains('|')) return false;
      return true;
    }

    if (_currentProject.id.isNotEmpty) {
      final csv = ref.read(csvSettingsProvider(_currentProject.id));
      for (var level = 1; level <= 3; level++) {
        if (!csv.hierarchyLevelConfigAlways(level).enabled) continue;
        final k = csv.resolveHierarchyLevelParamKey(level)?.trim() ?? '';
        if (isUsableListViewKey(k)) keys.add(k);
        final header = csv.hierarchyLevelHeaderLabel(level).trim();
        if (isUsableListViewKey(header)) keys.add(header);
      }
      for (final h in csv.importHeaderRow) {
        if (isUsableListViewKey(h)) keys.add(h.trim());
      }
    }

    for (final d in _disciplines) {
      for (final field in d.schema) {
        final label = (field['label'] ?? field['key'] ?? '').toString().trim();
        if (isUsableListViewKey(label)) keys.add(label);
      }
      for (final fields in d.revisionsobjektSchemas.values) {
        for (final field in fields) {
          final label =
              (field['label'] ?? field['key'] ?? '').toString().trim();
          if (isUsableListViewKey(label)) keys.add(label);
        }
      }
    }

    for (final a in anlagen) {
      if (a.params['__syntheticParent'] == true) continue;
      for (final entry in a.params.entries) {
        final k = entry.key.trim();
        if (!isUsableListViewKey(k)) continue;
        final v = entry.value?.toString().trim() ?? '';
        if (v.isEmpty) continue;
        keys.add(k);
      }
    }

    final sorted = keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _listViewParamKeys = sorted;
      // Ungültige Auswahl zurücksetzen (z. B. alter _att_slot_-Key).
      if (_listViewGroupingKey != null &&
          !sorted.contains(_listViewGroupingKey)) {
        _listViewGroupingKey = null;
      }
    });
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
    // Nur Disziplinen-Metadaten nachladen, keine vollständigen Anlagen-Reloads
    _loadDisciplines(refreshSystemsPages: false);
  }
  
  /// Lädt alle Anlagen für dieses Gebäude (für ggf. spätere Fortschrittsnutzung).
  Future<void> _loadAllAnlagenForProgress() async {
    // Fortschrittsanzeige entfernt – Methode bleibt für konsistente Aufrufstellen.
  }

  Future<void> _loadDisciplines({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (clearExpandedState) {
      final expandedKey = 'expanded_disciplines_${_building.id}';
      await prefs.remove(expandedKey);
      _technikTabKey = UniqueKey();
    }

    final dbService = ref.read(databaseServiceProvider);
    var disciplines = await dbService.getDisciplinesByBuildingId(_building.id);
    var hasTemplates = false;
    if (_currentProject.id.isNotEmpty) {
      final templates =
          await dbService.getTemplatesByProjectId(_currentProject.id);
      hasTemplates = templates.isNotEmpty;
      // Vorlagen erzeugen keine leeren Gewerk-Shells mehr – nur Schema-Merge
      // auf bereits vorhandene Disziplinen (aus Anlagen-Import / Plus).
      if (hasTemplates && disciplines.isNotEmpty) {
        disciplines = await TemplateService.ensureDisciplinesFromTemplates(
          dbService,
          _building.id,
          _currentProject.id,
        );
      }
    }
    var initialized = await dbService.isDisciplinesInitialized(_building.id);

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
        appLog('Fehler beim Extrahieren von Disziplinen aus Anlagen: $e');
      }
    }
    
    // Prüfe, ob sich die Anzahl der Disziplinen geändert hat
    final previousCount = _disciplines.length;
    // Technik-Liste: keine leeren Vorlagen-Gewerke (nur Anlagen oder manuell).
    if (_currentProject.id.isNotEmpty) {
      try {
        final anlagen = await dbService.getAnlagenByBuildingId(_building.id);
        final withAnlagen = {
          for (final a in anlagen) a.discipline.label.trim().toLowerCase(),
        };
        final templateGewerke = {
          for (final t
              in await dbService.getTemplatesByProjectId(_currentProject.id))
            if (t.gewerk.trim().isNotEmpty) t.gewerk.trim().toLowerCase(),
        };
        disciplines = disciplines.where((d) {
          final key = d.label.trim().toLowerCase();
          if (withAnlagen.contains(key)) return true;
          // Manuell angelegte Gewerke ohne Vorlage behalten.
          if (!templateGewerke.contains(key)) return true;
          return false;
        }).toList();
      } catch (e) {
        appLog('Filter leerer Vorlagen-Gewerke: $e');
      }
    }
    final newCount = disciplines.length;
    final disciplinesChanged = previousCount != newCount || 
        !_disciplines.every((d) => disciplines.any((nd) => nd.label == d.label));
    
    setState(() {
      _disciplines = disciplines;
      _hasProjectTemplates = hasTemplates;
    });
    _reinitTechnikTabController();
    await _refreshListViewParamKeys();
    
    // Wenn sich Disziplinen geändert haben, TechnikTab neu erstellen
    if (disciplinesChanged) {
      _technikTabKey = UniqueKey();
    }
    
    if (refreshSystemsPages || disciplinesChanged) {
      _refreshSystemsPages();
    }
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
      appLog('Starte CSV-Import für Building: ${_building.id}');
      if (_currentProject.id.isNotEmpty) {
        await ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
      }
      final importCsvSettings = _currentProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(_currentProject.id))
          : CsvSettings.defaults();
      final dbService = ref.read(databaseServiceProvider);
      final persistResult = await AnlagenCsvImportService.runFullImport(
        dbService: dbService,
        projectId: _currentProject.id,
        buildingId: _building.id,
        csvSettings: importCsvSettings,
        saveSettings: (updated) async {
          if (_currentProject.id.isNotEmpty) {
            await ref.read(csvSettingsProvider(_currentProject.id).notifier).save(updated);
          }
        },
      );
      appLog(
        'CSV-Import: ${persistResult.savedCount} importiert, '
        '${persistResult.skippedCount} übersprungen, ${persistResult.errorCount} Fehler',
      );

      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Disziplinen neu laden (wichtig, da Schema aktualisiert wurde)
      appLog('Lade Disziplinen neu...');
      await _loadDisciplines(
        clearExpandedState: true,
        refreshSystemsPages: true,
      );
      _refreshSystemsPages();
    } catch (e, stackTrace) {
      appLog('CSV-Import Fehler: $e');
      appLog('Stack Trace: $stackTrace');
      
      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<ExportDestination?> _showExportDestinationDialog() {
    return showDialog<ExportDestination>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speicherort wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: AppPalette.primary),
              title: const Text('Teilen'),
              subtitle: const Text('Per E-Mail, Messenger etc. versenden'),
              onTap: () => Navigator.of(context).pop(ExportDestination.share),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: AppPalette.primary),
              title: const Text('Auf Gerät speichern'),
              subtitle: const Text('In Dateien oder Downloads ablegen'),
              onTap: () => Navigator.of(context).pop(ExportDestination.saveToDevice),
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
  }

  /// Teilen oder Speichern – erst nach Schließen des Lade-Dialogs (sonst kein Speicherort-Dialog).
  Future<String?> _deliverExportBuiltFile(
    ExportBuiltFile built,
    ExportDestination destination, {
    String shareText = 'Anlagen-Export',
    String shareSubject = 'Anlagen-Export',
  }) async {
    if (destination == ExportDestination.saveToDevice) {
      // Kurz warten, bis der Lade-Dialog geschlossen ist – sonst öffnet sich kein Speicher-Dialog.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return null;
      return CsvService.saveFileToDevice(
        file: built.file,
        fileName: built.fileName,
      );
    }
    await Share.shareXFiles(
      [XFile(built.file.path)],
      text: shareText,
      subject: shareSubject,
    );
    return null;
  }

  void _showExportSavedMessage(String savedPath) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gespeichert unter:\n$savedPath'),
        duration: const Duration(seconds: 5),
      ),
    );
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
                leading: const Icon(Icons.table_chart, color: AppPalette.primary),
                title: const Text('Nur CSV exportieren'),
                subtitle: const Text('Exportiert nur die CSV-Datei ohne Fotos'),
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              ListTile(
                leading: const Icon(Icons.archive, color: AppPalette.primary),
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

      final destination = await _showExportDestinationDialog();
      if (destination == null) return;

      if (_currentProject.id.isNotEmpty) {
        await ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
      }
      final csvSettings = _currentProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(_currentProject.id))
          : CsvSettings.defaults();

      final dbService = ref.read(databaseServiceProvider);
      final anlagen = await dbService.getAnlagenByBuildingId(_building.id);
      appLog('Export: ${anlagen.length} Anlagen gefunden');

      if (anlagen.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Anlagen zum Exportieren')),
          );
        }
        return;
      }

      if (exportType == 'csv') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        late final ExportBuiltFile built;
        try {
          built = await CsvService.buildAnlagenCsvExportFile(
            anlagen: anlagen,
            csvSettings: csvSettings,
            disciplines: _disciplines,
            projectId:
                _currentProject.id.isNotEmpty ? _currentProject.id : null,
            buildingId: _building.id,
            dbService: dbService,
          );
        } finally {
          if (mounted) Navigator.of(context).pop();
        }

        if (!mounted) return;

        final savedPath = await _deliverExportBuiltFile(
          built,
          destination,
          shareSubject: 'Anlagen CSV Export',
        );

        if (savedPath != null) {
          _showExportSavedMessage(savedPath);
        }

        appLog('CSV-Export abgeschlossen');
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
                  leading: const Icon(Icons.folder, color: AppPalette.primary),
                  title: const Text('Nach Anlagen'),
                  subtitle: const Text('Jede Anlage hat einen eigenen Ordner'),
                  onTap: () => Navigator.of(context).pop(PhotoExportStructure.byAnlage),
                ),
                ListTile(
                  leading: const Icon(Icons.category, color: AppPalette.primary),
                  title: const Text('Nach Gewerken'),
                  subtitle: const Text('Fotos nach Gewerken gruppiert'),
                  onTap: () => Navigator.of(context).pop(PhotoExportStructure.byGewerk),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open, color: AppPalette.primaryLight),
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

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        late final ExportBuiltFile built;
        try {
          built = await CsvService.buildAnlagenZipExportFile(
            anlagen: anlagen,
            csvSettings: csvSettings,
            structure: structure,
            disciplines: _disciplines,
            projectId:
                _currentProject.id.isNotEmpty ? _currentProject.id : null,
            buildingId: _building.id,
            dbService: dbService,
          );
        } finally {
          if (mounted) Navigator.of(context).pop();
        }

        if (!mounted) return;

        String? savedPath;
        try {
          savedPath = await _deliverExportBuiltFile(
            built,
            destination,
            shareText: 'Anlagen-Export mit Fotos',
            shareSubject: 'Anlagen ZIP Export',
          );
        } finally {
          if (await built.file.exists()) {
            await built.file.delete();
          }
        }

        if (savedPath != null) {
          _showExportSavedMessage(savedPath);
        }

        appLog('ZIP-Export abgeschlossen');
      }
    } catch (e, stackTrace) {
      appLog('Export Fehler: $e');
      appLog('Stack Trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
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
    if (discipline != null) {
      _lastExpandedDiscipline = discipline;
    }
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
          appLog('Disziplin $label nicht gefunden beim Discipline-Expand');
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
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(_building);
    } catch (e) {
      _showProviderError(e);
      return;
    }
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
            dbService: ref.read(databaseServiceProvider),
          ),
          transitionsBuilder: (_, animation, __, child) {
            final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      ).then((_) async {
        try {
          await ref.read(projectsProvider.notifier).updateBuilding(_building);
        } catch (e) {
          _showProviderError(e);
        }
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
      try {
        await ref.read(projectsProvider.notifier).updateBuilding(_building);
      } catch (e) {
        _showProviderError(e);
        return;
      }
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
      try {
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
      } catch (e) {
        _showProviderError(e);
      }
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
      try {
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
          systems: BuildingSystems(),
          floors: <FloorPlan>[],
        );

        await ref.read(projectsProvider.notifier).addBuilding(neuesBuilding);
      } catch (e) {
        _showProviderError(e);
      }
    }
  }

  Future<void> _deleteSelectedBuildingsInDrawer() async {
    if (_selectedBuildingIndexes.isEmpty) return;

    final toDelete = _selectedBuildingIndexes.toList()..sort((a, b) => b.compareTo(a));
    final buildingsToDelete = toDelete
        .where((idx) => idx >= 0 && idx < _currentProject.buildings.length)
        .map((idx) => _currentProject.buildings[idx])
        .toList();

    for (final building in buildingsToDelete) {
      final confirmed = await showConfirmDeleteDialog(
        context,
        itemType: 'Gebäude',
        itemName: building.name,
      );
      if (!confirmed) return;
    }

    try {
      await ref.read(projectsProvider.notifier).deleteBuildings(toDelete);
    } catch (e) {
      _showProviderError(e);
      return;
    }

    setState(() {
      _buildingSelectionMode = false;
      _selectedBuildingIndexes.clear();
    });
  }

  void _openRecycleBin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecycleBinPage()),
    );
  }

  Future<void> _deleteSelectedProjects() async {
    if (_selectedProjectIndexes.isEmpty) return;

    final projectsState = ref.read(projectsProvider);
    final toDeleteProjects = _selectedProjectIndexes.toList()
      ..sort((a, b) => b.compareTo(a));

    final projectsToDelete = toDeleteProjects
        .where((idx) => idx >= 0 && idx < projectsState.projects.length)
        .map((idx) => projectsState.projects[idx])
        .toList();

    for (final project in projectsToDelete) {
      final confirmed = await showConfirmDeleteDialog(
        context,
        itemType: 'Projekt',
        itemName: project.name,
      );
      if (!confirmed) return;
    }

    try {
      await ref.read(projectsProvider.notifier).deleteProjects(toDeleteProjects);
    } catch (e) {
      _showProviderError(e);
      return;
    }

    setState(() {
      _projectSelectionMode = false;
      _selectedProjectIndexes.clear();
    });
    if (mounted) Navigator.of(context).pop();
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

  Future<AnlagePlacementResult?> _pickPlacementForDiscipline(
    Disziplin discipline, {
    String? initialRevisionsfeld,
    String? initialRevisionsobjekt,
    Map<String, dynamic>? mergeExtraParams,
  }) async {
    // Immer Hierarchie-Keys – nicht die Listen-Gruppierung (z. B. Baujahr),
    // sonst entfällt die Revisionsobjekt-Wahl und das Eingabe-Schema bleibt leer.
    final subKey = _resolveHierarchySubGroupingParamKey();
    if (subKey == null || subKey.isEmpty) {
      return AnlagePlacementResult(
        discipline: discipline,
        initialParams: Map<String, dynamic>.from(mergeExtraParams ?? {}),
      );
    }

    if (_currentProject.id.isEmpty) {
      return AnlagePlacementResult(
        discipline: discipline,
        initialParams: Map<String, dynamic>.from(mergeExtraParams ?? {}),
      );
    }

    await ref.read(csvSettingsProvider(_currentProject.id).notifier).load();

    final picked = await showModalBottomSheet<AnlagePlacementResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MoveAnlagenDialog.forPlacement(
        discipline: discipline,
        buildingId: _building.id,
        floorId: 'global',
        projectId: _currentProject.id,
        revisionsfeldGroupingKey: _resolveHierarchyGroupingParamKey(),
        revisionsobjektGroupingKey: subKey,
        initialRevisionsfeld: initialRevisionsfeld,
        initialRevisionsobjekt: initialRevisionsobjekt,
      ),
    );
    if (picked == null) return null;

    final merged = Map<String, dynamic>.from(picked.initialParams);
    if (mergeExtraParams != null) {
      merged.addAll(mergeExtraParams);
    }
    return AnlagePlacementResult(
      discipline: picked.discipline,
      initialParams: merged,
    );
  }

  Disziplin _resolveDisciplineForAdd() {
    if (_disciplines.isEmpty) {
      throw StateError('Keine Disziplinen vorhanden');
    }
    return _disciplines.length == 1
        ? _disciplines.first
        : (_lastExpandedDiscipline ?? _disciplines.first);
  }

  Future<void> _ensureDisciplinesFromTemplatesIfNeeded() async {
    if (_currentProject.id.isEmpty) return;
    final dbService = ref.read(databaseServiceProvider);
    final templates =
        await dbService.getTemplatesByProjectId(_currentProject.id);
    if (templates.isEmpty) return;
    // Nur Schemata in bestehende Disziplinen mergen – keine leeren Shells.
    final existing = await dbService.getDisciplinesByBuildingId(_building.id);
    if (existing.isEmpty) return;
    await TemplateService.ensureDisciplinesFromTemplates(
      dbService,
      _building.id,
      _currentProject.id,
    );
    await _loadDisciplines(refreshSystemsPages: true);
  }

  /// Plus: Start-Disziplin für den Platzierungsdialog (Gewerk + Ebene 2).
  /// Kein separater „Gewerk wählen“-Dialog – Auswahl erfolgt dort.
  Future<Disziplin?> _resolveDisciplineForAddOrMaterialize() async {
    if (_disciplines.isNotEmpty) {
      return _resolveDisciplineForAdd();
    }
    if (_currentProject.id.isEmpty || !_hasProjectTemplates) {
      return null;
    }
    final dbService = ref.read(databaseServiceProvider);
    final templateRows =
        await dbService.getTemplatesByProjectId(_currentProject.id);
    if (templateRows.isEmpty || !mounted) return null;

    final virtual =
        TemplateService.buildVirtualDisciplinesFromTemplateRows(templateRows);
    if (virtual.isEmpty) return null;
    // Platzhalter: echte Wahl im MoveAnlagenDialog (inkl. Vorlagen-Gewerke).
    return virtual.first;
  }

  Future<void> _openAnlageErfassungAfterPlacement({
    required Disziplin discipline,
    required Map<String, dynamic> placementParams,
  }) async {
    if (_currentProject.id.isEmpty) {
      if (!mounted) return;
      await showModalBottomSheet<void>(
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
          initialParams:
              placementParams.isNotEmpty ? placementParams : null,
          onSave: (newAnlage, _) async {
            final dbService = ref.read(databaseServiceProvider);
            await dbService.insertAnlage(newAnlage);
            await _saveNewAnlageFromDialog(newAnlage);
          },
        ),
      );
      return;
    }

    await ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
    final csvSettings = ref.read(csvSettingsProvider(_currentProject.id));
    final ro = (csvSettings.revisionsobjektValueFromParams(placementParams) ??
            csvSettings.schemaItemValueFromParams(placementParams) ??
            '')
        .trim();

    final dbService = ref.read(databaseServiceProvider);
    var gewerkTemplates = await TemplateService.loadTemplatesFromDatabase(
      dbService,
      _currentProject.id,
      gewerk: discipline.label,
    );

    var matched = ro.isNotEmpty && gewerkTemplates.isNotEmpty
        ? TemplateService.findTemplateForRevisionsobjekt(gewerkTemplates, ro)
        : null;
    if (ro.isNotEmpty && matched == null) {
      final allTemplates = await TemplateService.loadTemplatesFromDatabase(
        dbService,
        _currentProject.id,
      );
      matched = TemplateService.findTemplateForRevisionsobjekt(allTemplates, ro);
      if (matched != null) {
        gewerkTemplates = [matched, ...gewerkTemplates];
      } else if (gewerkTemplates.isEmpty) {
        gewerkTemplates = allTemplates;
      }
    }
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

    final childTemplates = schemaRo.isNotEmpty
        ? gewerkTemplates
            .where((t) =>
                t.anlagentyp.trim() == schemaRo &&
                t.anlageBauteil == 'b')
            .toList()
        : <Template>[];

    await _openGenericFormFromPlacement(
      projectId: _currentProject.id,
      selectedAnlagentyp: schemaRo.isNotEmpty ? schemaRo : ro,
      parentTemplate: parentTemplate,
      childTemplates: childTemplates,
      placementParams: placementParams,
      discipline: discipline,
    );
  }

  Future<void> _saveNewAnlageFromDialog(Anlage newAnlage) async {
    if (!mounted) return;
    await _loadAllAnlagenForProgress();
    _refreshSystemsPages();
    _exitGroupSelectionMode();
    _exitDisciplineSelectionMode();
  }

  Future<void> _openAddAnlageWithPlacement(
    Disziplin discipline, {
    Map<String, dynamic>? prefilledParams,
    String? initialRevisionsfeld,
    String? initialRevisionsobjekt,
  }) async {
    final placement = await _pickPlacementForDiscipline(
      discipline,
      initialRevisionsfeld: initialRevisionsfeld,
      initialRevisionsobjekt: initialRevisionsobjekt,
      mergeExtraParams: prefilledParams,
    );
    if (placement == null || !mounted) return;

    // Nach Materialisierung im Platzierungsdialog Technik-Liste aktualisieren
    await _loadDisciplines(refreshSystemsPages: true);
    if (!mounted) return;

    await _openAnlageErfassungAfterPlacement(
      discipline: placement.discipline,
      placementParams: placement.initialParams,
    );
  }

  Future<void> _openGenericFormFromPlacement({
    required String projectId,
    required String selectedAnlagentyp,
    required Template parentTemplate,
    required List<Template> childTemplates,
    required Map<String, dynamic> placementParams,
    required Disziplin discipline,
  }) async {
    final csvSettings = ref.read(csvSettingsProvider(projectId));
    final schemaItemKey = csvSettings.resolveSchemaItemParamKey();
    final params = TemplateService.buildInitialParamsForSchemaItem(
      parentTemplate: parentTemplate,
      selectedAnlagentyp: selectedAnlagentyp,
      schemaItemParamKey: schemaItemKey,
    );
    params.addAll(placementParams);

    final effectiveDiscipline = TemplateService.disciplineWithSchemaForRevisionsobjekt(
      discipline: discipline,
      revisionsobjekt: selectedAnlagentyp.trim(),
      template: parentTemplate,
      importHeaders: csvSettings.importHeaderRow,
    );
    final initialName = csvSettings.displayNameValueFromParams(params) ?? '';
    const uuid = Uuid();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GenericAnlageDialog(
        discipline: effectiveDiscipline,
        buildingId: _building.id,
        floorId: 'global',
        initialParams: params,
        initialName: initialName.isNotEmpty ? initialName : null,
        initialRevisionsobjekt: selectedAnlagentyp.trim(),
        onSave: (newAnlage, _) async {
          final dbService = ref.read(databaseServiceProvider);
          final existing = await dbService.getAnlageById(newAnlage.id);
          if (existing != null) {
            await dbService.updateAnlage(newAnlage);
          } else {
            await dbService.insertAnlage(newAnlage);
          }

          for (final t in childTemplates) {
            final childName = t.bezeichnung.trim().isNotEmpty
                ? t.bezeichnung.trim()
                : t.anlagentyp.trim();
            await dbService.insertAnlage(
              Anlage(
                id: uuid.v4(),
                parentId: newAnlage.id,
                name: childName,
                params: TemplateService.buildEmptyParamsFromTemplate(t.parameter),
                floorId: 'global',
                buildingId: _building.id,
                isMarker: false,
                markerInfo: null,
                markerType: discipline.label,
                discipline: effectiveDiscipline.withEffectiveSchema(
                  revisionsobjekt: t.anlagentyp.trim(),
                ),
              ),
            );
          }

          await _saveNewAnlageFromDialog(newAnlage);
        },
      ),
    );
  }

  Future<void> _openAddAnlageForGroupContext() async {
    final ctx = _groupSelectionContext;
    if (ctx == null || !ctx.isSchemaItemLevel) return;

    final roValue = ctx.groupValue.trim();
    if (roValue.isEmpty) return;

    await ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
    final csvSettings = ref.read(csvSettingsProvider(_currentProject.id));

    final additionalParams = Map<String, dynamic>.from(ctx.additionalParams)
      ..remove('__schemaOverride')
      ..remove('__sampleAnlageId');

    String? initialRf;
    final rfKey = csvSettings.resolveRevisionsfeldListGroupingParamKey();
    if (rfKey != null && rfKey.isNotEmpty) {
      initialRf = additionalParams.remove(rfKey)?.toString().trim();
    }

    final dbService = ref.read(databaseServiceProvider);
    Disziplin discipline = ctx.discipline;
    try {
      final disciplines =
          await dbService.getDisciplinesByBuildingId(_building.id);
      discipline = disciplines.firstWhere(
        (d) => d.label == ctx.discipline.label,
        orElse: () => ctx.discipline,
      );
    } catch (e) {
      appLog('Disziplinen für Gebäude konnten nicht geladen werden', error: e);
    }

    await _openAddAnlageWithPlacement(
      discipline,
      prefilledParams: additionalParams,
      initialRevisionsfeld: initialRf,
      initialRevisionsobjekt: roValue,
    );
  }

  void _enterGroupSelectionMode(
    Disziplin discipline,
    String groupKey,
    String groupValue,
    Map<String, dynamic> additionalParams, {
    required bool isSchemaItemLevel,
  }) {
    if (_systemsSelectionMode) {
      final activeDisciplines = _activeSelections.keys.toList();
      for (final label in activeDisciplines) {
        try {
          final disc = _systemsPageKeys.keys.firstWhere((d) => d.label == label);
          _systemsPageKeys[disc]?.currentState?.exitSelectionMode();
        } catch (e) {
          appLog('Systems-Selection beenden fehlgeschlagen', error: e);
        }
      }
    }

    setState(() {
      _systemsSelectionMode = false;
      _systemsSelectedCount = 0;
      _activeSelections.clear();
      _disciplineSelectionMode = false;
      _selectedDisciplineLabels.clear();
      _groupSelectionMode = true;
      _groupSelectionContext = (
        discipline: discipline,
        groupKey: groupKey,
        groupValue: groupValue,
        additionalParams: additionalParams,
        isSchemaItemLevel: isSchemaItemLevel,
      );
    });
    _drawerIconController.forward();
  }

  void _exitGroupSelectionMode() {
    setState(() {
      _groupSelectionMode = false;
      _groupSelectionContext = null;
    });
    _drawerIconController.reverse();
  }

  void _enterDisciplineSelectionMode(Disziplin discipline) {
    // Beende ggf. Systems-Selection (Anlagen-Auswahl) in allen Gewerken
    if (_systemsSelectionMode) {
      final activeDisciplines = _activeSelections.keys.toList();
      for (final label in activeDisciplines) {
        try {
          final disc = _systemsPageKeys.keys.firstWhere((d) => d.label == label);
          _systemsPageKeys[disc]?.currentState?.exitSelectionMode();
        } catch (e) {
          appLog('Systems-Selection beenden fehlgeschlagen', error: e);
        }
      }
    }
    if (_groupSelectionMode) {
      _exitGroupSelectionMode();
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
    } catch (e) {
      appLog('Ausgewählte Disziplin nicht in Keys gefunden: $label', error: e);
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
      ref.read(databaseServiceProvider),
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
                  'Wenn du die Disziplin löschst, werden die zugehörigen Anlagen in den Papierkorb verschoben. Die Disziplin selbst wird entfernt (kein Soft-Delete für Gewerke).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Anlagen können aus dem Papierkorb wiederhergestellt werden',
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

      // Anlagen soft-deleten → Papierkorb (Disziplin-Zeile selbst hat kein Soft-Delete)
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
        appLog('Disziplin ${activeLabels.first} nicht gefunden beim Bauteil-Hinzufügen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gewerk „${activeLabels.first}“ nicht gefunden')),
          );
        }
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
        appLog('Disziplin ${activeLabels.first} nicht gefunden beim Verschieben', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gewerk „${activeLabels.first}“ nicht gefunden')),
          );
        }
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);
    ref.listen<ProjectsState>(projectsProvider, (previous, next) {
      _syncFromProjectsState(next);
    });

    final projects = projectsState.projects;
    final selectedProjectIndex = projectsState.selectedProjectIndex ?? -1;
    final selectedBuildingIndex = projectsState.selectedBuildingIndex ?? -1;
    final displayProject =
        (selectedProjectIndex >= 0 && selectedProjectIndex < projects.length)
            ? projects[selectedProjectIndex]
            : _currentProject;
    final displayBuilding =
        (displayProject.buildings.isNotEmpty &&
                selectedBuildingIndex >= 0 &&
                selectedBuildingIndex < displayProject.buildings.length)
            ? displayProject.buildings[selectedBuildingIndex]
            : _building;

    if (projects.isEmpty) {
      return Scaffold(
        drawer: _buildDrawer(context),
        onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Keine Projekte vorhanden',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Es sind derzeit keine Projekte hinterlegt.\nLege über das Menü (☰) ein neues Projekt an.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    if (displayProject.buildings.isEmpty) {
      return Scaffold(
        drawer: _buildDrawer(context),
        onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          elevation: 0,
          title: Text(
            '„${displayProject.name}“: Keine Gebäude',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Dieses Projekt enthält momentan keine Gebäude.\nLege über das Menü (☰) ein neues Gebäude an.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    final isFloorplansTab = _tabController.index == 0;
    final inFloorplansSelection = isFloorplansTab && _isSelectionMode;

    final isTechnikTab = _tabController.index == 1;
    final inSystemsSelection = isTechnikTab && _systemsSelectionMode;
    final inDisciplineSelection = isTechnikTab && _disciplineSelectionMode;
    final inGroupSelection = isTechnikTab && _groupSelectionMode;

    final inSelectionMode =
        inFloorplansSelection || inSystemsSelection || inDisciplineSelection || inGroupSelection;

    String appBarTitle;
    if (inFloorplansSelection) {
      appBarTitle = '${_selectedFloorIndexes.length} ausgewählt';
    } else if (inSystemsSelection) {
      appBarTitle = '$_systemsSelectedCount ausgewählt';
    } else if (inGroupSelection) {
      appBarTitle = _groupSelectionContext?.groupValue ?? 'Gruppe';
    } else if (inDisciplineSelection) {
      appBarTitle = '${_selectedDisciplineLabels.length} ausgewählt';
    } else {
      appBarTitle = displayBuilding.name;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle(theme.brightness),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: _buildDrawer(context),
      onDrawerChanged: _onDrawerChanged,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: inSelectionMode
            ? const Color(0xFF4B5563)
            : theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: inSelectionMode ? Colors.white : onSurface.withOpacity(0.87),
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
                        appLog('Disziplin $label nicht gefunden beim Exit');
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
                  } else if (inGroupSelection) {
                    _exitGroupSelectionMode();
                  }
                } else {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _drawerIconAnimation,
                color: inSelectionMode ? Colors.white : onSurface.withOpacity(0.87),
              ),
            );
          },
        ),

        title: Text(
          appBarTitle,
          style: TextStyle(
            color: inSelectionMode ? Colors.white : onSurface.withOpacity(0.87),
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildAppBarActions(
          inSelectionMode: inSelectionMode,
          isTechnikTab: isTechnikTab,
          onSurface: onSurface,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 0. FLOORPLANS‐Tab
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

          // 1. TECHNIK‐Tab
          // neu: mit controller & keys
          TechnikMainTab(
            key: _technikTabKey,
            dbService: ref.read(databaseServiceProvider),
            building: _building,
            index: _currentBuildingIndex,
            tabController: _technikTabController,
            systemsPageKeys: _systemsPageKeys,
            onSelectionChanged: _onSystemsSelectionChanged,
            onDisciplineExpanded: _onDisciplineExpanded,
            onDisciplineLongPress: _enterDisciplineSelectionMode,
            onExitDisciplineSelectionMode: _exitDisciplineSelectionMode,
            disciplineSelectionMode: _tabController.index == 1 && _disciplineSelectionMode,
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
              await _loadDisciplines(refreshSystemsPages: true);
            },
            onImportCsv: _importCsv,
            onAddAnlage: () async {
              await _ensureDisciplinesFromTemplatesIfNeeded();
              if (!mounted) return;
              final discipline = await _resolveDisciplineForAddOrMaterialize();
              if (discipline == null || !mounted) return;
              await _openAddAnlageWithPlacement(discipline);
            },
            hasImportedTemplates: _hasProjectTemplates,
            isAnySelectionActive: () =>
                _systemsSelectionMode || _groupSelectionMode || _disciplineSelectionMode,
            systemsGroupingKey: _resolveSystemsGroupingParamKey(),
            systemsSubGroupingKey: _resolveSystemsSubGroupingParamKey(),
            systemsDisplayNameParamKey: _resolveSystemsDisplayNameParamKey(),
            labelGewerk: _currentProject.id.isNotEmpty
                ? ref.read(csvSettingsProvider(_currentProject.id)).labelGewerk
                : 'Gewerk',
            labelLeafLevel: _currentProject.id.isNotEmpty
                ? ref.read(csvSettingsProvider(_currentProject.id)).resolveLeafLevelLabel()
                : 'Anlage',
            labelGewerkPlural: _currentProject.id.isNotEmpty
                ? ref.read(csvSettingsProvider(_currentProject.id)).pluralDisciplineLabel(2)
                : 'Gewerke',
            labelLeafLevelPlural: _currentProject.id.isNotEmpty
                ? ref.read(csvSettingsProvider(_currentProject.id)).pluralLeafLevelLabel(2)
                : 'Anlagen',
            onGroupLongPress: (discipline, groupKey, groupValue, additionalParams) {
              CsvSettings? csvSettings;
              if (_currentProject.id.isNotEmpty) {
                csvSettings = ref.read(csvSettingsProvider(_currentProject.id));
              }
              final isLeafCreateGroup = csvSettings?.isCreateLeafFromGroupKey(groupKey) ?? false;
              _enterGroupSelectionMode(
                discipline,
                groupKey,
                groupValue,
                additionalParams,
                isSchemaItemLevel: isLeafCreateGroup,
              );
            },
          ),
        ],
      ),

      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom * 0.4,
              top: 4.0,
              left: 4.0,
              right: 4.0,
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return TabBar(
                  controller: _tabController,
                  indicator: const BoxDecoration(color: Colors.transparent),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: onSurface,
                  unselectedLabelColor: onSurface,
                  labelStyle:
                  const TextStyle(fontSize: 9, fontWeight: FontWeight.w400),
                  unselectedLabelStyle: const TextStyle(fontSize: 9),
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  tabs: [
                    _buildTabWithIconBackground(
                      icon: Icons.map,
                      text: 'Grundrisse',
                      index: 0,
                    ),
                    _buildTabWithIconBackground(
                      icon: Icons.settings,
                      text: 'Technik',
                      index: 1,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Erstellt elegante Floating Action Buttons rechts unten basierend auf dem Selection-Mode
  List<Widget> _buildAppBarActions({
    required bool inSelectionMode,
    required bool isTechnikTab,
    required Color onSurface,
  }) {
    if (inSelectionMode) return const [];
    if (!isTechnikTab || _listViewParamKeys.isEmpty) return const [];

    final current = _listViewGroupingKey;
    final isCustom =
        current != null && _listViewParamKeys.contains(current);

    return [
      PopupMenuButton<String>(
        tooltip: 'Auflisten nach',
        offset: const Offset(0, 40),
        icon: Icon(
          Icons.sort,
          color: isCustom ? AppPalette.primary : onSurface.withOpacity(0.75),
        ),
        onSelected: (key) {
          setState(() {
            _listViewGroupingKey =
                key == _listViewStandardGroupingValue ? null : key;
            _technikTabKey = UniqueKey();
          });
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem<String>(
            value: _listViewStandardGroupingValue,
            checked: !isCustom,
            child: const Text('Standard (Hierarchie)'),
          ),
          const PopupMenuDivider(),
          for (final key in _listViewParamKeys)
            CheckedPopupMenuItem<String>(
              value: key,
              checked: current == key,
              child: Text(key),
            ),
        ],
      ),
    ];
  }

  /// Erstellt elegante Floating Action Buttons rechts unten basierend auf dem Selection-Mode
  Widget? _buildFloatingActionButtons() {
    final inSelectionMode = _isSelectionMode ||
        _systemsSelectionMode ||
        _disciplineSelectionMode ||
        _groupSelectionMode;
    final inFloorplansSelection = _isSelectionMode && _tabController.index == 0;
    final inSystemsSelection = _systemsSelectionMode && _tabController.index == 1;
    final inDisciplineSelection = _disciplineSelectionMode && _tabController.index == 1;
    final inGroupSelection = _groupSelectionMode && _tabController.index == 1;

    // Grundriss-Tab: Button zum Hochladen (wenn nicht im Selection Mode)
    if (_tabController.index == 0 && !inSelectionMode) {
      return FloatingActionButton(
        onPressed: _addNewFloorAndUpload,
        tooltip: 'Grundriss hochladen',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.download, color: Colors.white),
      );
    }

    // Technik-Tab: Anlage hinzufügen (immer sichtbar außer im Auswahlmodus)
    if (_tabController.index == 1 && !inSelectionMode) {
      final leafLabel = _currentProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(_currentProject.id)).resolveLeafLevelLabel()
          : 'Anlage';
      return FloatingActionButton(
        onPressed: () async {
          await _ensureDisciplinesFromTemplatesIfNeeded();
          if (!mounted) return;
          final discipline = await _resolveDisciplineForAddOrMaterialize();
          if (discipline == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _hasProjectTemplates
                      ? 'Bitte ein Gewerk aus den Vorlagen wählen oder $leafLabel per CSV importieren.'
                      : 'Bitte zuerst Gewerkevorlagen unter CSV-Import importieren '
                          'oder $leafLabel per CSV importieren.',
                ),
              ),
            );
            return;
          }
          await _openAddAnlageWithPlacement(discipline);
        },
        tooltip: '$leafLabel hinzufügen',
        backgroundColor: SystemsOverviewPalette.primary,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }

    // Selection Mode: Zeige mehrere Buttons vertikal angeordnet
    if (inSelectionMode) {
      final List<Widget> buttons = [];

      if (inGroupSelection) {
        final ctx = _groupSelectionContext;
        if (ctx != null && ctx.isSchemaItemLevel) {
          var leafLabel = 'Eintrag';
          if (_currentProject.id.isNotEmpty) {
            final csv = ref.read(csvSettingsProvider(_currentProject.id));
            leafLabel = csv.resolveDatensatzUnderRevisionsobjektLabel();
          }
          buttons.add(
            BuildingDetailsFab(
              icon: Icons.add,
              tooltip: '$leafLabel hinzufügen',
              onPressed: _openAddAnlageForGroupContext,
              backgroundColor: SystemsOverviewPalette.primary,
            ),
          );
        }
      } else if (inDisciplineSelection) {
        if (_selectedDisciplineLabels.length == 1) {
          buttons.add(
            BuildingDetailsFab(
              icon: Icons.edit,
              tooltip: 'Gewerk bearbeiten',
              onPressed: _editSelectedDiscipline,
              backgroundColor: SystemsOverviewPalette.primaryLight,
            ),
          );
          final leafLabel = _currentProject.id.isNotEmpty
              ? ref.read(csvSettingsProvider(_currentProject.id)).resolveLeafLevelLabel()
              : 'Anlage';
          buttons.add(
            BuildingDetailsFab(
              icon: Icons.add,
              tooltip: '$leafLabel hinzufügen',
              onPressed: () async {
                final d = _getSingleSelectedDiscipline();
                if (d != null) {
                  await _openAddAnlageWithPlacement(d);
                }
              },
              backgroundColor: SystemsOverviewPalette.primary,
            ),
          );
        }
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.delete_outline,
            tooltip: 'Gewerk löschen',
            onPressed: _deleteSelectedDiscipline,
            backgroundColor: SystemsOverviewPalette.primaryDark,
          ),
        );
      } else if (inSystemsSelection) {
        // Anlagen-Auswahl: Bauteil hinzufügen, Verschieben, Löschen
        if (_activeSelections.keys.length == 1) {
          // Prüfe, ob nur Bauteile ausgewählt sind
          final activeLabel = _activeSelections.keys.first;
          bool hasOnlyBauteile = false;
          
          try {
            final discipline = _systemsPageKeys.keys.firstWhere(
              (d) => d.label == activeLabel,
            );
            hasOnlyBauteile = _systemsPageKeys[discipline]?.currentState?.hasOnlyBauteileSelected() ?? false;
          } catch (e) {
            // Disziplin nicht gefunden, ignoriere
            appLog('Disziplin $activeLabel nicht gefunden beim Prüfen auf Bauteile');
          }
          
          final csvSettings = _currentProject.id.isNotEmpty
              ? ref.read(csvSettingsProvider(_currentProject.id))
              : null;
          final showChildAdd = csvSettings?.allowsParentChildRows ?? false;
          if (showChildAdd && !hasOnlyBauteile) {
            final childLabel = csvSettings!.labelBauteil;
            buttons.add(
              BuildingDetailsFab(
                icon: Icons.add,
                tooltip: '$childLabel hinzufügen',
                onPressed: _openBulkAddBauteilForSystemsSelection,
                backgroundColor: SystemsOverviewPalette.primary,
              ),
            );
          }
          buttons.add(
            BuildingDetailsFab(
              icon: Icons.drive_file_move,
              tooltip: 'Verschieben',
              onPressed: _openMoveDialogForSystemsSelection,
              backgroundColor: SystemsOverviewPalette.primaryMuted,
            ),
          );
        }
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.delete_outline,
            tooltip: () {
              if (_currentProject.id.isEmpty) {
                return 'Ausgewählte Einträge löschen';
              }
              final label = ref
                  .read(csvSettingsProvider(_currentProject.id))
                  .pluralLeafLevelLabel(2);
              return 'Ausgewählte $label löschen';
            }(),
            onPressed: _handleDeleteSelectedAnlagen,
            backgroundColor: SystemsOverviewPalette.primaryDark,
          ),
        );
      } else if (inFloorplansSelection) {
        // Grundriss-Auswahl: Löschen
        buttons.add(
          BuildingDetailsFab(
            icon: Icons.delete_outline,
            tooltip: 'Ausgewählte Grundrisse löschen',
            onPressed: _handleDeleteSelectedFloors,
            backgroundColor: SystemsOverviewPalette.primaryDark,
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
                'Die ausgewählten Anlagen werden in den Papierkorb verschoben und können von dort wiederhergestellt werden.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
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
                        'In Papierkorb',
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
      // Soft-Delete: ausgewählte Anlagen aus allen aktiven Gewerken → Papierkorb
      final activeDisciplines = _activeSelections.keys.toList();
      for (final label in activeDisciplines) {
        try {
          final discipline = _systemsPageKeys.keys.firstWhere(
            (d) => d.label == label,
          );
          _systemsPageKeys[discipline]?.currentState?.deleteSelectedAnlagen();
        } catch (e) {
          // Disziplin nicht gefunden, ignorieren
          appLog('Disziplin $label nicht gefunden beim Löschen');
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
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Tab(
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: isSelected ? surfaceColor : Colors.transparent,
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
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(_building);
    } catch (e) {
      _showProviderError(e);
      return;
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FloorPlanFullScreen(
          building: _building,
          floor: newFloor,
          dbService: ref.read(databaseServiceProvider),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    try {
      await ref.read(projectsProvider.notifier).updateBuilding(_building);
    } catch (e) {
      _showProviderError(e);
    }
  }

  Widget _buildDrawer(BuildContext context) {
    final projectsState = ref.read(projectsProvider);
    final projects = projectsState.projects;
    
    return Drawer(
      width: 320,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                        onTap: _deleteSelectedProjects,
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
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder,
                        color: AppPalette.primaryDark,
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
                        onTap: _openRecycleBin,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.delete_outline,
                            size: 22,
                            color: Colors.grey[700],
                          ),
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
                            color: AppPalette.primary,
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
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                            : AppPalette.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.folder,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : AppPalette.primaryDark,
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
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: AppPalette.primary,
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
                              color: AppPalette.primaryLight,
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
                                ? AppPalette.primary.withOpacity(0.1)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBldgSelected
                                  ? AppPalette.primary.withOpacity(0.3)
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
                                            ? AppPalette.primary.withOpacity(0.15)
                                            : AppPalette.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.location_city,
                                        color: isBldgSelected
                                            ? AppPalette.primaryDark
                                            : AppPalette.primary,
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
                                              ? AppPalette.primaryDark
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
                                                ? AppPalette.primaryLight
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                          color: isChecked
                                              ? AppPalette.primaryLight
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
                                        color: AppPalette.primaryDark,
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
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
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
                    color: AppPalette.success,
                    onTap: () => _importCsv(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.upload_rounded,
                    label: 'CSV exportieren',
                    color: AppPalette.primary,
                    onTap: () => _exportCsv(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.tune_rounded,
                    label: 'Allgemeine Einstellungen',
                    color: AppPalette.primary,
                    onTap: () {
                      final projects = ref.read(projectsProvider).projects;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AppSettingsPage(
                            projectId: projects.isNotEmpty ? _currentProject.id : null,
                            buildingId: projects.isNotEmpty &&
                                    _currentProject.buildings.isNotEmpty
                                ? _building.id
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.settings_rounded,
                    label: 'CSV-Import',
                    color: AppPalette.primaryLight,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CsvSettingsPage(
                            projectId: _currentProject.id,
                            buildingId: _building.id,
                          ),
                        ),
                      );
                      // Disziplinen neu laden, falls sie in den Einstellungen geändert wurden
                      await _loadDisciplines(refreshSystemsPages: true);
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