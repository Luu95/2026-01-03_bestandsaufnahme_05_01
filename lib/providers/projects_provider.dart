// lib/providers/projects_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/building.dart';
import '../database/database_service.dart';
import 'database_provider.dart';

/// State-Klasse für die Projekte-Verwaltung
class ProjectsState {
  final List<Project> projects;
  final bool isLoading;
  final int? selectedProjectIndex;
  final int? selectedBuildingIndex;

  ProjectsState({
    required this.projects,
    this.isLoading = false,
    this.selectedProjectIndex,
    this.selectedBuildingIndex,
  });

  ProjectsState copyWith({
    List<Project>? projects,
    bool? isLoading,
    int? selectedProjectIndex,
    int? selectedBuildingIndex,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      selectedProjectIndex: selectedProjectIndex ?? this.selectedProjectIndex,
      selectedBuildingIndex: selectedBuildingIndex ?? this.selectedBuildingIndex,
    );
  }

  Project? get selectedProject {
    if (selectedProjectIndex == null || selectedProjectIndex! < 0 || selectedProjectIndex! >= projects.length) {
      return null;
    }
    return projects[selectedProjectIndex!];
  }

  Building? get selectedBuilding {
    final project = selectedProject;
    if (project == null || selectedBuildingIndex == null || selectedBuildingIndex! < 0) {
      return null;
    }
    if (selectedBuildingIndex! >= project.buildings.length) {
      return null;
    }
    return project.buildings[selectedBuildingIndex!];
  }
}

/// StateNotifier für Projekte-Verwaltung
class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final DatabaseService _dbService;

  ProjectsNotifier(this._dbService) : super(ProjectsState(projects: [], isLoading: true)) {
    loadProjects();
  }

  /// Lädt alle Projekte aus der Datenbank
  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true);
    try {
      final projects = await _dbService.getAllProjects();
      int? selectedProjectIndex;
      int? selectedBuildingIndex;

      if (projects.isNotEmpty) {
        selectedProjectIndex = 0;
        if (projects[0].buildings.isNotEmpty) {
          selectedBuildingIndex = 0;
        }
      }

      state = state.copyWith(
        projects: projects,
        isLoading: false,
        selectedProjectIndex: selectedProjectIndex,
        selectedBuildingIndex: selectedBuildingIndex,
      );
    } catch (e) {
      state = state.copyWith(
        projects: [],
        isLoading: false,
        selectedProjectIndex: null,
        selectedBuildingIndex: null,
      );
    }
  }

  /// Wählt ein Projekt aus
  void selectProject(int index) {
    if (index < 0 || index >= state.projects.length) return;

    final project = state.projects[index];
    final buildingIndex = project.buildings.isNotEmpty ? 0 : null;

    state = state.copyWith(
      selectedProjectIndex: index,
      selectedBuildingIndex: buildingIndex,
    );
  }

  /// Wählt ein Gebäude aus
  void selectBuilding(int index) {
    state = state.copyWith(selectedBuildingIndex: index);
  }

  /// Fügt ein neues Projekt hinzu
  Future<void> addProject(Project project) async {
    try {
      await _dbService.insertProject(project);
      final projects = [...state.projects, project];
      state = state.copyWith(projects: projects);
    } catch (e) {
      // Fehlerbehandlung
    }
  }

  /// Aktualisiert ein Projekt
  Future<void> updateProject(Project project) async {
    try {
      await _dbService.updateProject(project);
      final projects = List<Project>.from(state.projects);
      final index = projects.indexWhere((p) => p.id == project.id);
      if (index >= 0) {
        projects[index] = project;
        state = state.copyWith(projects: projects);
      }
    } catch (e) {
      // Fehlerbehandlung
    }
  }

  /// Löscht Projekte
  Future<void> deleteProjects(List<int> indices) async {
    try {
      indices.sort((a, b) => b.compareTo(a));
      final projects = List<Project>.from(state.projects);
      
      for (final idx in indices) {
        if (idx >= 0 && idx < projects.length) {
          await _dbService.deleteProject(projects[idx].id);
          projects.removeAt(idx);
        }
      }

      int? selectedProjectIndex;
      int? selectedBuildingIndex;

      if (projects.isNotEmpty) {
        final currentIndex = state.selectedProjectIndex ?? 0;
        if (currentIndex >= projects.length) {
          selectedProjectIndex = projects.length - 1;
        } else {
          selectedProjectIndex = currentIndex;
        }
        final project = projects[selectedProjectIndex];
        if (project.buildings.isNotEmpty) {
          selectedBuildingIndex = 0;
        }
      }

      state = state.copyWith(
        projects: projects,
        selectedProjectIndex: selectedProjectIndex,
        selectedBuildingIndex: selectedBuildingIndex,
      );
    } catch (e) {
      // Fehlerbehandlung
    }
  }

  /// Aktualisiert ein Gebäude
  Future<void> updateBuilding(Building building) async {
    try {
      await _dbService.updateBuilding(building);
      final project = state.selectedProject;
      if (project == null) return;

      final buildingIndex = state.selectedBuildingIndex;
      if (buildingIndex == null || buildingIndex < 0 || buildingIndex >= project.buildings.length) return;

      project.buildings[buildingIndex] = building;
      await updateProject(project);
    } catch (e) {
      // Fehlerbehandlung
    }
  }

  /// Fügt ein Gebäude hinzu
  Future<void> addBuilding(Building building) async {
    try {
      final project = state.selectedProject;
      if (project == null) return;

      final currentProjectIndex = state.selectedProjectIndex;

      // Speichere das Gebäude direkt in der Datenbank
      await _dbService.insertBuilding(building, project.id);

      // Lade die Projekte neu aus der Datenbank, um Duplikate zu vermeiden
      final projects = await _dbService.getAllProjects();
      
      // Versuche die vorherigen Indizes beizubehalten
      int? selectedProjectIndex = currentProjectIndex;
      int? selectedBuildingIndex;
      
      if (selectedProjectIndex != null && selectedProjectIndex >= 0 && selectedProjectIndex < projects.length) {
        final updatedProject = projects[selectedProjectIndex];
        
        // Finde das neu hinzugefügte Gebäude
        final buildingIndex = updatedProject.buildings.indexWhere((b) => b.id == building.id);
        if (buildingIndex >= 0) {
          selectedBuildingIndex = buildingIndex;
        } else if (updatedProject.buildings.isNotEmpty) {
          // Falls das Gebäude nicht gefunden wird, wähle das letzte Gebäude
          selectedBuildingIndex = updatedProject.buildings.length - 1;
        }
      } else if (projects.isNotEmpty) {
        // Fallback: Wähle das erste Projekt und Gebäude
        selectedProjectIndex = 0;
        if (projects[0].buildings.isNotEmpty) {
          selectedBuildingIndex = projects[0].buildings.length - 1;
        }
      }
      
      state = state.copyWith(
        projects: projects,
        selectedProjectIndex: selectedProjectIndex,
        selectedBuildingIndex: selectedBuildingIndex,
      );
    } catch (e) {
      // Fehlerbehandlung
    }
  }

  /// Löscht Gebäude
  Future<void> deleteBuildings(List<int> indices) async {
    try {
      final project = state.selectedProject;
      if (project == null) return;

      indices.sort((a, b) => b.compareTo(a));
      for (final idx in indices) {
        if (idx >= 0 && idx < project.buildings.length) {
          await _dbService.deleteBuilding(project.buildings[idx].id);
          project.buildings.removeAt(idx);
        }
      }

      int? selectedBuildingIndex;
      if (project.buildings.isNotEmpty) {
        final currentIndex = state.selectedBuildingIndex ?? 0;
        if (currentIndex >= project.buildings.length) {
          selectedBuildingIndex = project.buildings.length - 1;
        } else {
          selectedBuildingIndex = currentIndex;
        }
      }

      await updateProject(project);
      state = state.copyWith(selectedBuildingIndex: selectedBuildingIndex);
    } catch (e) {
      // Fehlerbehandlung
    }
  }
}

/// Provider für den ProjectsNotifier
final projectsProvider = StateNotifierProvider<ProjectsNotifier, ProjectsState>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return ProjectsNotifier(dbService);
});



