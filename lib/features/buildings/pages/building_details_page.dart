/// Gebäude-Hauptseite: Tabs (Grundrisse / Technik), Drawer, CSV und Anlagen.
///
/// Orientierung (Mixins unter `building_details/`):
/// 1. State / Lifecycle
/// 2. CSV Import & Export → building_details_csv_actions.dart
/// 3. Grundrisse / Tabs → building_details_floor_actions.dart
/// 4. Anlagen / Placement → building_details_anlage_actions.dart
/// 5. Selection-Modes → building_details_selection_actions.dart
/// 6. build() / AppBar / FAB → building_details_fab_host.dart
/// 7. Drawer → building_details_drawer_host.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/app/navigation/route_observer.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/app/theme/app_theme.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/csv/utils/csv_column_layout.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_anlage_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_csv_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_drawer_host.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_empty_scaffold.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_fab_host.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_floor_actions.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/building_details_selection_actions.dart';
import 'package:bestandsaufnahme_01/features/systems/pages/systems_page.dart';
import 'package:bestandsaufnahme_01/features/buildings/tabs/floorplans_tab.dart';
import 'package:bestandsaufnahme_01/features/buildings/tabs/technik_main_tab.dart';

/// Einstiegspunkt der Gebäude-Ansicht (Projekte/Gebäude über Drawer).
class BuildingDetailsPage extends ConsumerStatefulWidget {
  const BuildingDetailsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<BuildingDetailsPage> createState() =>
      _BuildingDetailsPageState();
}

/// State der Gebäude-Hauptseite; Logik über Mixins in `building_details/`.
class _BuildingDetailsPageState extends ConsumerState<BuildingDetailsPage>
    with
        RouteAware,
        TickerProviderStateMixin,
        BuildingDetailsCsvActions,
        BuildingDetailsAnlageActions,
        BuildingDetailsSelectionActions,
        BuildingDetailsFloorActions,
        BuildingDetailsDrawerHost,
        BuildingDetailsFabHost {
  late int _currentProjectIndex;
  late Project _currentProject;
  late int _currentBuildingIndex;
  late Building _building;
  late TabController _tabController;

  bool _isSelectionMode = false;
  final Set<int> _selectedFloorIndexes = {};

  bool _systemsSelectionMode = false;
  int _systemsSelectedCount = 0;

  final Map<Disziplin, GlobalKey<SystemsPageState>> _systemsPageKeys = {};
  final Map<String, int> _activeSelections = {};
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

  Disziplin? _lastExpandedDiscipline;
  bool _hasProjectTemplates = false;

  String? _listViewGroupingKey;
  List<String> _listViewParamKeys = [];

  // --- Abschnitt: 1 State / Lifecycle ---
  @override
  void showProviderError(Object e) {
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

    _drawerIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _drawerIconAnimation = CurvedAnimation(
      parent: _drawerIconController,
      curve: Curves.easeInOut,
    );

    final projectsState = ref.read(projectsProvider);
    final projects = projectsState.projects;
    final selectedProjectIndex = projectsState.selectedProjectIndex ?? -1;
    final selectedBuildingIndex = projectsState.selectedBuildingIndex ?? -1;

    _currentProjectIndex = selectedProjectIndex;
    if (projects.isNotEmpty &&
        selectedProjectIndex >= 0 &&
        selectedProjectIndex < projects.length) {
      _currentProject = projects[_currentProjectIndex];
    } else {
      _currentProject = Project(
        id: '',
        name: '',
        description: '',
        customer: '',
        buildings: [],
      );
    }
    _currentBuildingIndex = selectedBuildingIndex;
    if (_currentProject.buildings.isNotEmpty &&
        selectedBuildingIndex >= 0 &&
        selectedBuildingIndex < _currentProject.buildings.length) {
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
        floors: [],
      );
    }

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_isSelectionMode && _tabController.index != 0) {
          exitFloorplansSelectionMode();
        }
        if (_systemsSelectionMode && _tabController.index != 1) {
          exitSystemsPageSelectionsForLabels(_activeSelections.keys.toList());
          setState(() {
            _systemsSelectionMode = false;
            _systemsSelectedCount = 0;
            _activeSelections.clear();
          });
          _drawerIconController.reverse();
        }
        if (_previousTabIndex != _tabController.index) {
          _previousTabIndex = _tabController.index;
          _loadAllAnlagenForProgress();
          setState(() {});
        }
      });

    _loadDisciplines();
    _loadAllAnlagenForProgress();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentProject.id.isNotEmpty) {
        ref.read(csvSettingsProvider(_currentProject.id).notifier).load();
      }
    });
  }

  String? _resolveSystemsGroupingParamKey() {
    final override = _listViewGroupingKey?.trim();
    if (override != null && override.isNotEmpty) return override;
    return resolveHierarchyGroupingParamKey();
  }

  String? _resolveSystemsSubGroupingParamKey() {
    final override = _listViewGroupingKey?.trim();
    if (override != null && override.isNotEmpty) return null;
    return resolveHierarchySubGroupingParamKey();
  }

  @override
  String? resolveHierarchyGroupingParamKey() {
    if (_currentProject.id.isEmpty) return null;
    final settings = ref.read(csvSettingsProvider(_currentProject.id));
    return settings.resolveRevisionsfeldListGroupingParamKey();
  }

  @override
  String? resolveHierarchySubGroupingParamKey() {
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
      if (_listViewGroupingKey != null &&
          !sorted.contains(_listViewGroupingKey)) {
        _listViewGroupingKey = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    _drawerIconController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadDisciplines(refreshSystemsPages: false);
  }

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
      hasTemplates =
          await dbService.hasTemplatesForProject(_currentProject.id);
      // Kein voller Schema-Merge mehr bei jedem Laden – das blockiert Plus/Reload
      // bei großen Vorlagen. Schema kommt beim Prefill/Materialize.
    }
    var initialized = await dbService.isDisciplinesInitialized(_building.id);

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

    final previousCount = _disciplines.length;
    if (_currentProject.id.isNotEmpty) {
      try {
        final anlagen = await dbService.getAnlagenByBuildingId(_building.id);
        final withAnlagen = {
          for (final a in anlagen) a.discipline.label.trim().toLowerCase(),
        };
        final templateGewerke = {
          for (final g
              in await dbService.getDistinctTemplateGewerke(_currentProject.id))
            if (g.trim().isNotEmpty) g.trim().toLowerCase(),
        };
        disciplines = disciplines.where((d) {
          final key = d.label.trim().toLowerCase();
          if (withAnlagen.contains(key)) return true;
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
    _rebuildSystemsPageKeys();
    await _refreshListViewParamKeys();

    if (disciplinesChanged) {
      _technikTabKey = UniqueKey();
    }

    if (refreshSystemsPages || disciplinesChanged) {
      _refreshSystemsPages();
    }
  }

  void _refreshSystemsPages() {
    for (final key in _systemsPageKeys.values) {
      key.currentState?.didPopNext();
    }
    _loadAllAnlagenForProgress();
  }

  // --- Abschnitt: 2 CSV Import & Export ---
  @override
  Building get csvBuilding => _building;

  @override
  Project get csvProject => _currentProject;

  @override
  List<Disziplin> get csvDisciplines => _disciplines;

  @override
  Future<void> reloadDisciplinesAfterCsv({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  }) =>
      _loadDisciplines(
        clearExpandedState: clearExpandedState,
        refreshSystemsPages: refreshSystemsPages,
      );

  @override
  void refreshSystemsPagesAfterCsv() => _refreshSystemsPages();

  // --- Mixin-Bridges (Anlage / Selection / Floor / Drawer / FAB) ---
  @override
  Building get anlageBuilding => _building;

  @override
  Project get anlageProject => _currentProject;

  @override
  List<Disziplin> get anlageDisciplines => _disciplines;

  @override
  Disziplin? get lastExpandedDiscipline => _lastExpandedDiscipline;

  @override
  bool get hasProjectTemplates => _hasProjectTemplates;

  @override
  ({
    Disziplin discipline,
    String groupKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
    bool isSchemaItemLevel,
  })? get groupSelectionContext => _groupSelectionContext;

  @override
  set groupSelectionContext(
    ({
      Disziplin discipline,
      String groupKey,
      String groupValue,
      Map<String, dynamic> additionalParams,
      bool isSchemaItemLevel,
    })? value,
  ) =>
      _groupSelectionContext = value;

  @override
  Future<void> reloadDisciplinesForAnlage({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  }) =>
      _loadDisciplines(
        clearExpandedState: clearExpandedState,
        refreshSystemsPages: refreshSystemsPages,
      );

  @override
  Future<void> saveNewAnlageFromDialog(Anlage newAnlage) async {
    if (!mounted) return;
    await _loadAllAnlagenForProgress();
    _refreshSystemsPages();
    exitGroupSelectionMode();
    exitDisciplineSelectionMode();
  }

  @override
  Building get selectionBuilding => _building;

  @override
  Project get selectionProject => _currentProject;

  @override
  bool get systemsSelectionMode => _systemsSelectionMode;

  @override
  set systemsSelectionMode(bool value) => _systemsSelectionMode = value;

  @override
  int get systemsSelectedCount => _systemsSelectedCount;

  @override
  set systemsSelectedCount(int value) => _systemsSelectedCount = value;

  @override
  Map<String, int> get activeSelections => _activeSelections;

  @override
  bool get disciplineSelectionMode => _disciplineSelectionMode;

  @override
  set disciplineSelectionMode(bool value) => _disciplineSelectionMode = value;

  @override
  Set<String> get selectedDisciplineLabels => _selectedDisciplineLabels;

  @override
  bool get groupSelectionMode => _groupSelectionMode;

  @override
  set groupSelectionMode(bool value) => _groupSelectionMode = value;

  @override
  Map<Disziplin, GlobalKey<SystemsPageState>> get systemsPageKeys =>
      _systemsPageKeys;

  @override
  AnimationController get drawerIconController => _drawerIconController;

  @override
  Animation<double> get drawerIconAnimation => _drawerIconAnimation;

  @override
  Future<void> reloadDisciplinesForSelection({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  }) =>
      _loadDisciplines(
        clearExpandedState: clearExpandedState,
        refreshSystemsPages: refreshSystemsPages,
      );

  @override
  Future<void> reloadAllAnlagenForProgress() => _loadAllAnlagenForProgress();

  @override
  Building get floorBuilding => _building;

  @override
  bool get isFloorSelectionMode => _isSelectionMode;

  @override
  set isFloorSelectionMode(bool value) => _isSelectionMode = value;

  @override
  Set<int> get selectedFloorIndexes => _selectedFloorIndexes;

  @override
  Project get drawerProject => _currentProject;

  @override
  set drawerProject(Project value) => _currentProject = value;

  @override
  Building get drawerBuilding => _building;

  @override
  set drawerBuilding(Building value) => _building = value;

  @override
  int get drawerProjectIndex => _currentProjectIndex;

  @override
  set drawerProjectIndex(int value) => _currentProjectIndex = value;

  @override
  int get drawerBuildingIndex => _currentBuildingIndex;

  @override
  set drawerBuildingIndex(int value) => _currentBuildingIndex = value;

  @override
  bool get projectSelectionMode => _projectSelectionMode;

  @override
  set projectSelectionMode(bool value) => _projectSelectionMode = value;

  @override
  Set<int> get selectedProjectIndexes => _selectedProjectIndexes;

  @override
  bool get buildingSelectionMode => _buildingSelectionMode;

  @override
  set buildingSelectionMode(bool value) => _buildingSelectionMode = value;

  @override
  Set<int> get selectedBuildingIndexes => _selectedBuildingIndexes;

  @override
  VoidCallback get onImportCsv => importCsv;

  @override
  VoidCallback get onExportCsv => exportCsv;

  @override
  Future<void> reloadDisciplinesForDrawer({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  }) =>
      _loadDisciplines(
        clearExpandedState: clearExpandedState,
        refreshSystemsPages: refreshSystemsPages,
      );

  @override
  Future<void> onBuildingSwitched() => _loadDisciplines();

  @override
  TabController get mainTabController => _tabController;

  @override
  Project get fabProject => _currentProject;

  @override
  String? get listViewGroupingKey => _listViewGroupingKey;

  @override
  set listViewGroupingKey(String? value) => _listViewGroupingKey = value;

  @override
  List<String> get listViewParamKeys => _listViewParamKeys;

  @override
  set technikTabKey(Key value) => _technikTabKey = value;

  // --- Abschnitt: 3 Grundrisse / Tabs ---
  void _rebuildSystemsPageKeys() {
    _systemsPageKeys.clear();
    for (var d in _disciplines) {
      _systemsPageKeys[d] = GlobalKey<SystemsPageState>();
    }
  }

  void _onDisciplineExpanded(Disziplin? discipline) {
    if (discipline != null) {
      _lastExpandedDiscipline = discipline;
    }
    final activeDisciplines =
        _systemsSelectionMode ? _activeSelections.keys.toList() : <String>[];

    setState(() {
      if (_systemsSelectionMode) {
        _systemsSelectionMode = false;
        _systemsSelectedCount = 0;
        _activeSelections.clear();
        _drawerIconController.reverse();
      }
    });

    if (activeDisciplines.isNotEmpty) {
      exitSystemsPageSelectionsForLabels(activeDisciplines);
    }
  }

  void _onSystemsSelectionChanged(
    bool isActive,
    int selectedCount,
    Disziplin discipline,
  ) {
    if (isActive) {
      _activeSelections[discipline.label] = selectedCount;
    } else {
      _activeSelections.remove(discipline.label);
    }

    final totalCount =
        _activeSelections.values.fold(0, (sum, count) => sum + count);
    final hasAnySelection = _activeSelections.isNotEmpty;

    setState(() {
      _systemsSelectionMode = hasAnySelection;
      _systemsSelectedCount = totalCount;
    });

    if (hasAnySelection) {
      _drawerIconController.forward();
    } else {
      _drawerIconController.reverse();
    }
  }

  // --- Abschnitt: 6 build() / AppBar / FAB ---
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
    final displayBuilding = (displayProject.buildings.isNotEmpty &&
            selectedBuildingIndex >= 0 &&
            selectedBuildingIndex < displayProject.buildings.length)
        ? displayProject.buildings[selectedBuildingIndex]
        : _building;

    final drawer = buildBuildingDetailsDrawer(context);

    if (projects.isEmpty) {
      return BuildingDetailsEmptyScaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        title: 'Keine Projekte vorhanden',
        message:
            'Es sind derzeit keine Projekte hinterlegt.\nLege über das Menü (☰) ein neues Projekt an.',
      );
    }

    if (displayProject.buildings.isEmpty) {
      return BuildingDetailsEmptyScaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        title: '„${displayProject.name}“: Keine Gebäude',
        message:
            'Dieses Projekt enthält momentan keine Gebäude.\nLege über das Menü (☰) ein neues Gebäude an.',
      );
    }

    final isFloorplansTab = _tabController.index == 0;
    final inFloorplansSelection = isFloorplansTab && _isSelectionMode;
    final isTechnikTab = _tabController.index == 1;
    final inSystemsSelection = isTechnikTab && _systemsSelectionMode;
    final inDisciplineSelection = isTechnikTab && _disciplineSelectionMode;
    final inGroupSelection = isTechnikTab && _groupSelectionMode;
    final inSelectionMode = inFloorplansSelection ||
        inSystemsSelection ||
        inDisciplineSelection ||
        inGroupSelection;

    final String appBarTitle;
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
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
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
                      exitFloorplansSelectionMode();
                    } else if (inSystemsSelection) {
                      exitSystemsPageSelectionsForLabels(
                        _activeSelections.keys.toList(),
                      );
                      setState(() {
                        _systemsSelectionMode = false;
                        _systemsSelectedCount = 0;
                        _activeSelections.clear();
                      });
                      _drawerIconController.reverse();
                    } else if (inDisciplineSelection) {
                      exitDisciplineSelectionMode();
                    } else if (inGroupSelection) {
                      exitGroupSelectionMode();
                    }
                  } else {
                    Scaffold.of(innerContext).openDrawer();
                  }
                },
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _drawerIconAnimation,
                  color: inSelectionMode
                      ? Colors.white
                      : onSurface.withOpacity(0.87),
                ),
              );
            },
          ),
          title: Text(
            appBarTitle,
            style: TextStyle(
              color:
                  inSelectionMode ? Colors.white : onSurface.withOpacity(0.87),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          actions: buildListViewAppBarActions(
            inSelectionMode: inSelectionMode,
            isTechnikTab: isTechnikTab,
            onSurface: onSurface,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            FloorPlansTab(
              building: _building,
              index: _currentBuildingIndex,
              onAddFloor: addNewFloorAndUpload,
              isSelectionMode: _isSelectionMode,
              selectedFloorIndexes: _selectedFloorIndexes,
              onFloorTap: onFloorTap,
              onFloorLongPress: onFloorLongPress,
              onDeleteSingleFloor: onDeleteSingleFloor,
            ),
            TechnikMainTab(
              key: _technikTabKey,
              dbService: ref.read(databaseServiceProvider),
              building: _building,
              index: _currentBuildingIndex,
              systemsPageKeys: _systemsPageKeys,
              onSelectionChanged: _onSystemsSelectionChanged,
              onDisciplineExpanded: _onDisciplineExpanded,
              onDisciplineLongPress: enterDisciplineSelectionMode,
              onExitDisciplineSelectionMode: exitDisciplineSelectionMode,
              disciplineSelectionMode:
                  _tabController.index == 1 && _disciplineSelectionMode,
              selectedDisciplineLabels: _selectedDisciplineLabels,
              onDisciplineSelectionToggle: toggleDisciplineSelection,
              onAnlageCreated: () {
                onAnlageCreatedFromSystemsPage();
              },
              onBauteilCreated: () {
                onBauteilCreatedFromSystemsPage();
              },
              onAnlagenMoved: () {
                _refreshSystemsPages();
              },
              onSchemaUpdated: () async {
                await _loadDisciplines(refreshSystemsPages: true);
              },
              onImportCsv: importCsv,
              onAddAnlage: () async {
                if (!mounted) return;
                final discipline = await resolveDisciplineForAddOrMaterialize();
                if (discipline == null || !mounted) return;
                await openAddAnlageWithPlacement(discipline);
              },
              hasImportedTemplates: _hasProjectTemplates,
              isAnySelectionActive: () =>
                  _systemsSelectionMode ||
                  _groupSelectionMode ||
                  _disciplineSelectionMode,
              systemsGroupingKey: _resolveSystemsGroupingParamKey(),
              systemsSubGroupingKey: _resolveSystemsSubGroupingParamKey(),
              systemsDisplayNameParamKey: _resolveSystemsDisplayNameParamKey(),
              labelGewerk: _currentProject.id.isNotEmpty
                  ? ref.read(csvSettingsProvider(_currentProject.id)).labelGewerk
                  : 'Gewerk',
              labelLeafLevel: _currentProject.id.isNotEmpty
                  ? ref
                      .read(csvSettingsProvider(_currentProject.id))
                      .resolveLeafLevelLabel()
                  : 'Anlage',
              labelGewerkPlural: _currentProject.id.isNotEmpty
                  ? ref
                      .read(csvSettingsProvider(_currentProject.id))
                      .pluralDisciplineLabel(2)
                  : 'Gewerke',
              labelLeafLevelPlural: _currentProject.id.isNotEmpty
                  ? ref
                      .read(csvSettingsProvider(_currentProject.id))
                      .pluralLeafLevelLabel(2)
                  : 'Anlagen',
              onGroupLongPress:
                  (discipline, groupKey, groupValue, additionalParams) {
                CsvSettings? csvSettings;
                if (_currentProject.id.isNotEmpty) {
                  csvSettings =
                      ref.read(csvSettingsProvider(_currentProject.id));
                }
                final isLeafCreateGroup =
                    csvSettings?.isCreateLeafFromGroupKey(groupKey) ?? false;
                enterGroupSelectionMode(
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
        floatingActionButton: buildSelectionAwareFab(),
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
                    labelStyle: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 9),
                    isScrollable: false,
                    tabAlignment: TabAlignment.fill,
                    tabs: [
                      buildBottomTab(
                        icon: Icons.map,
                        text: 'Grundrisse',
                        index: 0,
                      ),
                      buildBottomTab(
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
}
