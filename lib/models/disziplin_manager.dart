import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'disziplin_schnittstelle.dart'; // Nutzung des zentralen Disziplin-Modells
import '../utils/delete_utils.dart'; // Für Bestätigungsdialog
import '../providers/database_provider.dart';
import '../providers/projects_provider.dart';
import '../pages/widgets/schema_editor_dialog.dart';
import '../utils/app_log.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

/// Widget zum Verwalten (Anzeigen, Hinzufügen, Bearbeiten, Löschen) von Disziplinen.
/// Disziplinen werden gebäudespezifisch gespeichert.
class DisziplinManagerWidget extends ConsumerStatefulWidget {
  final String buildingId; // Gebäude-ID, für die die Disziplinen verwaltet werden

  const DisziplinManagerWidget({
    Key? key,
    required this.buildingId,
  }) : super(key: key);

  @override
  _DisziplinManagerWidgetState createState() => _DisziplinManagerWidgetState();
}

class _DisziplinManagerWidgetState extends ConsumerState<DisziplinManagerWidget> {
  List<Disziplin> disziplinen = [];
  bool _isSelectionMode = false; // Gibt an, ob sich die Seite im Auswahlmodus befindet
  final Set<String> _selectedDisziplinLabels = {}; // Enthält die Labels der selektierten Disziplinen

  @override
  void initState() {
    super.initState();
    _loadDisziplinen();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDisziplinen() async {
    final dbService = ref.read(databaseServiceProvider);
    final loaded = await dbService.getDisciplinesByBuildingId(widget.buildingId);
    if (!mounted) return;
    setState(() {
      disziplinen = loaded;
    });
  }

  Future<void> _saveDisziplinen() async {
    final dbService = ref.read(databaseServiceProvider);
    await dbService.replaceDisciplines(widget.buildingId, disziplinen);
  }

  Future<void> _editSchemaForDisziplin() async {
    if (disziplinen.isEmpty) {
      return;
    }

    if (disziplinen.length == 1) {
      await _editSchemaForDisziplinAtIndex(0);
      return;
    }

    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Schema bearbeiten', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Wähle eine Disziplin aus:'),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: disziplinen.length,
                  itemBuilder: (ctx, idx) {
                    final d = disziplinen[idx];
                    return ListTile(
                      leading: Icon(d.icon, color: d.color),
                      title: Text(d.label),
                      onTap: () => Navigator.of(ctx).pop(idx),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedIndex != null) {
      await _editSchemaForDisziplinAtIndex(selectedIndex);
    }
  }

  Future<void> _editSchemaForDisziplinAtIndex(int index) async {
    if (index < 0 || index >= disziplinen.length) return;

    final d = disziplinen[index];
    final currentSchema = List<Map<String, dynamic>>.from(d.schema);

    final newSchema = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SchemaEditorDialog(existingSchema: currentSchema),
    );

    if (newSchema != null) {
      setState(() {
        disziplinen[index] = Disziplin(
          label: d.label,
          icon: d.icon,
          color: d.color,
          schema: newSchema,
          groupingKey: d.groupingKey,
        );
      });
      await _saveDisziplinen();
    }
  }

  void _editDisziplin(int idx) async {
    final d = disziplinen[idx];
    final editedDisziplin = await showDialog<Disziplin>(
      context: context,
      builder: (_) => DisziplinEditDialog(
        disziplin: d,
        projectId: ref.read(currentProjectProvider)?.id, // Wir brauchen hier auch die ProjectId
      ),
    );

    if (editedDisziplin != null) {
      setState(() {
        disziplinen[idx] = editedDisziplin;
      });
      await _saveDisziplinen();
    }
  }

  void _enterSelectionMode(String label) {
    setState(() {
      _isSelectionMode = true;
      _selectedDisziplinLabels.add(label);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedDisziplinLabels.clear();
    });
  }

  Future<void> _deleteDisziplin(int idx) async {
    final d = disziplinen[idx];
    final dbService = ref.read(databaseServiceProvider);
    final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, d.label);
    
    bool confirmed = false;
    if (anlagen.isNotEmpty) {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disziplin hat noch Anlagen'),
          content: Text('"${d.label}" hat noch ${anlagen.length} Anlagen. Wirklich löschen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
          ],
        ),
      ) ?? false;

      if (confirmed) {
        for (final anlage in anlagen) {
          await dbService.deleteAnlage(anlage.id);
        }
      }
    } else {
      confirmed = await showDeleteConfirmationDialog(context, 'Disziplin', d.label);
    }

    if (!confirmed) return;

    setState(() {
      disziplinen.removeAt(idx);
      _selectedDisziplinLabels.remove(d.label);
    });
    await _saveDisziplinen();
  }

  Future<void> _deleteAllAnlagen() async {
    final dbService = ref.read(databaseServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Anlagen löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Alle löschen')),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    for (final d in disziplinen) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, d.label);
      for (final anlage in anlagen) {
        await dbService.deleteAnlage(anlage.id);
      }
    }
  }

  Future<void> _deleteSelectedDisziplinen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ausgewählte löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    final dbService = ref.read(databaseServiceProvider);
    final toDeleteLabels = _selectedDisziplinLabels.toList();
    for (final label in toDeleteLabels) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, label);
      for (final anlage in anlagen) {
        await dbService.deleteAnlage(anlage.id);
      }
    }

    setState(() {
      disziplinen.removeWhere((d) => toDeleteLabels.contains(d.label));
      _selectedDisziplinLabels.clear();
    });
    await _saveDisziplinen();
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
            : null,
        title: Text(_isSelectionMode ? '${_selectedDisziplinLabels.length} ausgewählt' : 'Datenmodell'),
        actions: _isSelectionMode
            ? [IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelectedDisziplinen)]
            : [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete_all') _deleteAllAnlagen();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'delete_all', child: Text('Alle Anlagen löschen')),
                  ],
                ),
                IconButton(icon: const Icon(Icons.schema), onPressed: _editSchemaForDisziplin),
              ],
      ),
      body: ListView.builder(
        itemCount: disziplinen.length,
        itemBuilder: (ctx, i) {
          final d = disziplinen[i];
          final isSelected = _selectedDisziplinLabels.contains(d.label);
          return Dismissible(
            key: Key(d.label),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteDisziplin(i),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: d.color.withOpacity(0.2),
                child: Icon(d.icon, color: d.color),
              ),
              title: Text(d.label),
              selected: isSelected,
              onTap: () {
                if (_isSelectionMode) {
                  setState(() => isSelected ? _selectedDisziplinLabels.remove(d.label) : _selectedDisziplinLabels.add(d.label));
                } else {
                  _editDisziplin(i);
                }
              },
              onLongPress: () => _enterSelectionMode(d.label),
            ),
          );
        },
      ),
    );
  }
}

class DisziplinEditDialog extends StatefulWidget {
  final Disziplin? disziplin;
  final String? projectId;
  const DisziplinEditDialog({Key? key, this.disziplin, this.projectId}) : super(key: key);

  @override
  State<DisziplinEditDialog> createState() => _DisziplinEditDialogState();
}

class _DisziplinEditDialogState extends State<DisziplinEditDialog> {
  late final TextEditingController nameCtrl;
  late IconData selectedIcon;
  late Color selectedColor;
  List<Map<String, dynamic>>? _globalSchema;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.disziplin?.label ?? '');
    selectedIcon = widget.disziplin?.icon ?? Icons.build;
    selectedColor = widget.disziplin?.color ?? Colors.blue;
    _loadGlobalSchema();
  }

  Future<void> _loadGlobalSchema() async {
    if (widget.projectId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'global_schema_${widget.projectId}';
      final schemaJson = prefs.getString(key);
      if (schemaJson != null) {
        if (mounted) {
          setState(() {
            _globalSchema = (json.decode(schemaJson) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des globalen Schemas: $e');
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selectedIcon,
                    color: selectedColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.disziplin == null ? 'Neue Disziplin' : 'Disziplin bearbeiten',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Definieren Sie Name und Erscheinungsbild',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name der Disziplin (z.B. Heizung)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Symbol & Farbe (Demnächst anpassbar)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context, Disziplin(
                      label: nameCtrl.text.trim(),
                      icon: selectedIcon,
                      color: selectedColor,
                      schema: widget.disziplin?.schema ?? _globalSchema ?? [],
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: selectedColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
