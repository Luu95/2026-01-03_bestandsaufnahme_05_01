import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/anlage.dart';
import '../models/building.dart';
import '../models/project.dart';
import '../providers/database_provider.dart';
import '../providers/projects_provider.dart';
import 'widgets/confirm_delete_dialog.dart';

class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  bool _loading = true;
  List<Project> _deletedProjects = [];
  List<Building> _deletedBuildings = [];
  List<Anlage> _deletedAnlagen = [];
  final Map<String, String> _buildingProjectNames = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedItems();
  }

  Future<void> _loadDeletedItems() async {
    setState(() => _loading = true);
    final db = ref.read(databaseServiceProvider);

    final projects = await db.getDeletedProjects();
    final allBuildings = await db.getDeletedBuildings();
    final allAnlagen = await db.getDeletedAnlagen();

    final deletedProjectIds = projects.map((p) => p.id).toSet();
    final deletedBuildingIds = allBuildings.map((b) => b.id).toSet();

    final buildings = <Building>[];
    for (final b in allBuildings) {
      final projectId = await db.getProjectIdByBuildingIdIncludingDeleted(b.id);
      if (projectId != null && deletedProjectIds.contains(projectId)) {
        continue;
      }
      buildings.add(b);
    }

    final anlagen = <Anlage>[];
    for (final a in allAnlagen) {
      if (deletedBuildingIds.contains(a.buildingId)) continue;
      anlagen.add(a);
    }

    final projectNames = <String, String>{};
    for (final p in projects) {
      projectNames[p.id] = p.name;
    }

    final buildingNames = <String, String>{};
    for (final b in buildings) {
      buildingNames[b.id] = b.name;
      final projectId = await db.getProjectIdByBuildingIdIncludingDeleted(b.id);
      if (projectId != null) {
        final projectRow = await db.getProjectNameByIdIncludingDeleted(projectId);
        if (projectRow != null) {
          _buildingProjectNames[b.id] = projectRow;
        }
      }
    }

    for (final a in anlagen) {
      if (!_buildingProjectNames.containsKey(a.buildingId)) {
        final projectId = await db.getProjectIdByBuildingIdIncludingDeleted(a.buildingId);
        if (projectId != null) {
          final name = await db.getProjectNameByIdIncludingDeleted(projectId);
          if (name != null) {
            _buildingProjectNames[a.buildingId] = name;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _deletedProjects = projects;
        _deletedBuildings = buildings;
        _deletedAnlagen = anlagen;
        _loading = false;
      });
    }
  }

  Future<void> _restoreProject(Project project) async {
    final db = ref.read(databaseServiceProvider);
    await db.restoreProject(project.id);
    await ref.read(projectsProvider.notifier).loadProjects();
    await _loadDeletedItems();
  }

  Future<void> _restoreBuilding(Building building) async {
    final db = ref.read(databaseServiceProvider);
    await db.restoreBuilding(building.id);
    await ref.read(projectsProvider.notifier).loadProjects();
    await _loadDeletedItems();
  }

  Future<void> _restoreAnlage(Anlage anlage) async {
    final db = ref.read(databaseServiceProvider);
    await db.restoreAnlage(anlage.id);
    await ref.read(projectsProvider.notifier).loadProjects();
    await _loadDeletedItems();
  }

  Future<void> _permanentlyDelete({
    required String itemType,
    required String itemName,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      itemType: itemType,
      itemName: itemName,
      isPermanent: true,
    );
    if (!confirmed || !mounted) return;

    await onDelete();
    await ref.read(projectsProvider.notifier).loadProjects();
    await _loadDeletedItems();
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItemTile({
    required String title,
    String? subtitle,
    required VoidCallback onRestore,
    required VoidCallback onPermanentDelete,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Wiederherstellen',
              icon: Icon(Icons.restore, color: Colors.green[700]),
              onPressed: onRestore,
            ),
            IconButton(
              tooltip: 'Endgültig löschen',
              icon: Icon(Icons.delete_forever, color: Colors.red[700]),
              onPressed: onPermanentDelete,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _deletedProjects.isEmpty &&
        _deletedBuildings.isEmpty &&
        _deletedAnlagen.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papierkorb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: _loadDeletedItems,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Papierkorb ist leer',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    if (_deletedProjects.isNotEmpty) ...[
                      _buildSectionTitle('Projekte', _deletedProjects.length),
                      ..._deletedProjects.map((p) => _buildItemTile(
                            title: p.name,
                            subtitle: p.customer.isNotEmpty ? p.customer : null,
                            onRestore: () => _restoreProject(p),
                            onPermanentDelete: () => _permanentlyDelete(
                              itemType: 'Projekt',
                              itemName: p.name,
                              onDelete: () => ref
                                  .read(databaseServiceProvider)
                                  .permanentlyDeleteProject(p.id),
                            ),
                          )),
                    ],
                    if (_deletedBuildings.isNotEmpty) ...[
                      _buildSectionTitle('Gebäude', _deletedBuildings.length),
                      ..._deletedBuildings.map((b) => _buildItemTile(
                            title: b.name,
                            subtitle: _buildingProjectNames[b.id] != null
                                ? 'Projekt: ${_buildingProjectNames[b.id]}'
                                : null,
                            onRestore: () => _restoreBuilding(b),
                            onPermanentDelete: () => _permanentlyDelete(
                              itemType: 'Gebäude',
                              itemName: b.name,
                              onDelete: () => ref
                                  .read(databaseServiceProvider)
                                  .permanentlyDeleteBuilding(b.id),
                            ),
                          )),
                    ],
                    if (_deletedAnlagen.isNotEmpty) ...[
                      _buildSectionTitle('Datensätze', _deletedAnlagen.length),
                      ..._deletedAnlagen.map((a) => _buildItemTile(
                            title: a.name,
                            subtitle: a.discipline.label,
                            onRestore: () => _restoreAnlage(a),
                            onPermanentDelete: () => _permanentlyDelete(
                              itemType: 'Datensatz',
                              itemName: a.name,
                              onDelete: () => ref
                                  .read(databaseServiceProvider)
                                  .hardDeleteAnlage(a.id),
                            ),
                          )),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
