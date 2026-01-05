import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'disziplin_schnittstelle.dart'; // Nutzung des zentralen Disziplin-Modells
import 'disziplin_defaults.dart'; // Import der Standard-Disziplinen
import '../utils/delete_utils.dart'; // Für Bestätigungsdialog
import '../providers/database_provider.dart';

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

class _DisziplinManagerWidgetState extends ConsumerState<DisziplinManagerWidget>
    with TickerProviderStateMixin {
  List<Disziplin> disziplinen = [];
  bool _isSelectionMode = false; // Gibt an, ob sich die Seite im Auswahlmodus befindet
  final Set<String> _selectedDisziplinLabels = {}; // Enthält die Labels der selektierten Disziplinen

  late final AnimationController _iconController;
  late final Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconAnimation = CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOut,
    );
    _loadDisziplinen();
  }

  @override
  void dispose() {
    _iconController.dispose();
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

  /// Generiert Standard-Disziplinen und fügt sie hinzu (nur die, die noch nicht existieren)
  Future<void> _generateDefaultDisziplinen() async {
    final defaultDisziplinen = getDefaultDisziplinen();
    final existingLabels = disziplinen.map((d) => d.label.toLowerCase()).toSet();
    
    int addedCount = 0;
    for (final defaultDisc in defaultDisziplinen) {
      if (!existingLabels.contains(defaultDisc.label.toLowerCase())) {
        disziplinen.add(defaultDisc);
        addedCount++;
      }
    }
    
    if (addedCount > 0) {
      await _saveDisziplinen();
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount Standard-Disziplinen hinzugefügt'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Standard-Disziplinen sind bereits vorhanden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveDisziplinen() async {
    final dbService = ref.read(databaseServiceProvider);
    await dbService.replaceDisciplines(widget.buildingId, disziplinen);
  }

  Future<void> _addDisziplin() async {
    final newDisziplin = await showDialog<Disziplin>(
      context: context,
      builder: (_) => const DisziplinEditDialog(),
    );

    if (newDisziplin != null) {
      setState(() => disziplinen.add(newDisziplin));
      await _saveDisziplinen();
    }
  }

  void _editDisziplin(int idx) async {
    final d = disziplinen[idx];
    final editedDisziplin = await showDialog<Disziplin>(
      context: context,
      builder: (_) => DisziplinEditDialog(disziplin: d),
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
      _isSelectionMode = true; // Aktiviert den Auswahlmodus
      _selectedDisziplinLabels.add(label); // Fügt die Disziplin der Auswahl hinzu
    });
    _iconController.forward();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedDisziplinLabels.clear();
    });
    _iconController.reverse();
  }

  Future<void> _deleteDisziplin(int idx) async {
    final d = disziplinen[idx];
    
    // Prüfen, ob noch Anlagen in dieser Disziplin existieren
    final dbService = ref.read(databaseServiceProvider);
    final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, d.label);
    
    if (anlagen.isNotEmpty) {
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
                  'Disziplin hat noch Anlagen',
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
                        '${anlagen.length} Anlage${anlagen.length > 1 ? 'n' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'in "${d.label}"',
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
      for (final anlage in anlagen) {
        await dbService.deleteAnlage(anlage.id);
      }
    } else {
      final confirmed = await showDeleteConfirmationDialog(
        context,
        'Disziplin',
        d.label,
      );
      if (!confirmed) return;
    }

    setState(() {
      disziplinen.removeAt(idx);
      _selectedDisziplinLabels.remove(d.label);
    });
    await _saveDisziplinen();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${d.label} gelöscht')));
    }
    // Beende Auswahlmodus, wenn keine Disziplinen mehr ausgewählt sind
    if (_selectedDisziplinLabels.isEmpty && _isSelectionMode) {
      _exitSelectionMode();
    }
  }

  Future<void> _deleteAllAnlagen() async {
    // Prüfe, ob überhaupt Anlagen vorhanden sind
    final dbService = ref.read(databaseServiceProvider);
    int totalAnlagenCount = 0;
    
    for (final d in disziplinen) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, d.label);
      totalAnlagenCount += anlagen.length;
    }
    
    if (totalAnlagenCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Anlagen vorhanden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Bestätigungsdialog anzeigen
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
                'ALLE Anlagen löschen?',
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
                      '$totalAnlagenCount Anlage${totalAnlagenCount > 1 ? 'n' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'aus allen Disziplinen',
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
                'Diese Aktion kann nicht rückgängig gemacht werden',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Möchtest du wirklich fortfahren?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Alle Anlagen werden unwiderruflich gelöscht',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
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
                          const Icon(Icons.delete_forever, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'ALLE löschen',
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
    
    // Alle Anlagen für alle Disziplinen löschen
    int deletedCount = 0;
    for (final d in disziplinen) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, d.label);
      for (final anlage in anlagen) {
        await dbService.deleteAnlage(anlage.id);
        deletedCount++;
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount Anlage(n) gelöscht'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSelectedDisziplinen() async {
    if (_selectedDisziplinLabels.isEmpty) return;

    final count = _selectedDisziplinLabels.length;
    
    // Prüfen, ob eine der ausgewählten Disziplinen noch Anlagen hat
    final dbService = ref.read(databaseServiceProvider);
    int totalAnlagenCount = 0;
    List<String> affectedLabels = [];
    
    for (final label in _selectedDisziplinLabels) {
      final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, label);
      if (anlagen.isNotEmpty) {
        totalAnlagenCount += anlagen.length;
        affectedLabels.add(label);
      }
    }

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
                totalAnlagenCount > 0 ? 'Disziplinen & Anlagen löschen?' : 'Disziplinen löschen?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (totalAnlagenCount > 0) ...[
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
                        '$count Disziplin${count > 1 ? 'en' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'mit $totalAnlagenCount Anlage${totalAnlagenCount > 1 ? 'n' : ''}',
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
                  'In den ausgewählten Disziplinen (${affectedLabels.join(", ")}) befinden sich noch insgesamt $totalAnlagenCount Anlage(n).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Wenn du diese löschst, werden auch ALLE zugehörigen Anlagen unwiderruflich aus der Datenbank gelöscht.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'Möchtest du $count ausgewählte Disziplin${count > 1 ? 'en' : ''} wirklich löschen?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
                        backgroundColor: totalAnlagenCount > 0 ? Colors.red[600] : Colors.red[600],
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
                          Icon(
                            totalAnlagenCount > 0 ? Icons.delete_forever : Icons.delete,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              totalAnlagenCount > 0 ? 'Alles löschen' : 'Löschen',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

    if (confirmed == true) {
      // Anlagen für alle zu löschenden Disziplinen aus der Datenbank entfernen
      final toDeleteLabels = _selectedDisziplinLabels.toList();
      for (final label in toDeleteLabels) {
        final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(widget.buildingId, label);
        for (final anlage in anlagen) {
          await dbService.deleteAnlage(anlage.id);
        }
      }

      // Lösche alle ausgewählten Disziplinen (rückwärts, um Index-Probleme zu vermeiden)
      setState(() {
        disziplinen.removeWhere((d) => toDeleteLabels.contains(d.label));
        _selectedDisziplinLabels.clear();
      });
      await _saveDisziplinen();
      _exitSelectionMode();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count Disziplin${count > 1 ? 'en' : ''} gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _iconAnimation,
                  color: Colors.white,
                ),
                onPressed: _exitSelectionMode,
                tooltip: 'Auswahl beenden',
              )
            : null,
        title: _isSelectionMode
            ? Text('${_selectedDisziplinLabels.length} ausgewählt')
            : Text('Disziplin Manager'),
        backgroundColor: _isSelectionMode
            ? const Color(0xFF4B5563) // Edles, professionelles Grau statt Blau
            : null,
        iconTheme: _isSelectionMode
            ? IconThemeData(color: Colors.white)
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.delete),
                  tooltip: 'Ausgewählte löschen',
                  onPressed: _selectedDisziplinLabels.isEmpty
                      ? null
                      : _deleteSelectedDisziplinen,
                ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete_all') {
                      _deleteAllAnlagen();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Alle Anlagen löschen'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.auto_fix_high),
                  tooltip: 'Standard-Disziplinen generieren',
                  onPressed: _generateDefaultDisziplinen,
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline),
                  tooltip: 'Neue Disziplin hinzufügen',
                  onPressed: _addDisziplin,
                ),
              ],
      ),
      body: disziplinen.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Disziplinen vorhanden',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Importiere Disziplinen über CSV oder\ngeneriere Standard-Disziplinen',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.auto_fix_high),
                    label: Text('Standard-Disziplinen generieren'),
                    onPressed: _generateDefaultDisziplinen,
                  ),
                ],
              ),
            )
          : ListView.builder(
        itemCount: disziplinen.length,
        itemBuilder: (ctx, i) {
          final d = disziplinen[i];
          final isSelected = _selectedDisziplinLabels.contains(d.label);
          
          return Dismissible(
            key: Key('${d.label}#$i'),
            background: Container(color: Colors.red),
            onDismissed: (_) async => await _deleteDisziplin(i),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.3)
                    : d.color.withOpacity(0.2),
                child: Icon(d.icon, color: d.color),
              ),
              title: Text(
                d.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                ),
              ),
              subtitle: d.schema.isNotEmpty
                  ? Text('Felder: ${d.schema.map((e) => e['label']).join(', ')}')
                  : null,
              trailing: _isSelectionMode
                  ? (isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                      : const Icon(Icons.radio_button_unchecked, color: Colors.grey))
                  : null,
              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedDisziplinLabels.remove(d.label);
                      if (_selectedDisziplinLabels.isEmpty) {
                        _exitSelectionMode();
                      }
                    } else {
                      _selectedDisziplinLabels.add(d.label);
                    }
                  });
                } else {
                  _editDisziplin(i);
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(d.label);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class DisziplinEditDialog extends StatefulWidget {
  final Disziplin? disziplin;
  const DisziplinEditDialog({Key? key, this.disziplin}) : super(key: key);

  @override
  State<DisziplinEditDialog> createState() => _DisziplinEditDialogState();
}

class _DisziplinEditDialogState extends State<DisziplinEditDialog> {
  late final TextEditingController nameCtrl;
  late IconData selectedIcon;
  late Color selectedColor;
  late List<Map<String, dynamic>> editedSchema;
  String? selectedGroupingKey;

  @override
  void initState() {
    super.initState();
    final d = widget.disziplin;
    nameCtrl = TextEditingController(text: d?.label ?? '');
    selectedIcon = d?.icon ?? Icons.build;
    selectedColor = d?.color ?? Colors.blue;
    editedSchema = d != null ? List.from(d.schema) : [];
    selectedGroupingKey = d?.groupingKey;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNameEmpty = nameCtrl.text.trim().isEmpty;
    final isEditMode = widget.disziplin != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    selectedColor.withOpacity(0.15),
                    selectedColor.withOpacity(0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEditMode ? 'Disziplin bearbeiten' : 'Neue Disziplin anlegen',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Konfiguriere Name, Symbol und Schema',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isNameEmpty
                              ? Colors.red.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorText: isNameEmpty ? 'Name darf nicht leer sein' : null,
                          errorStyle: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Symbol Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final newIcon = await showDialog<IconData>(
                              context: context,
                              builder: (_) => IconPickerDialog(selectedIcon: selectedIcon),
                            );
                            if (newIcon != null) {
                              setState(() => selectedIcon = newIcon);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: selectedColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    selectedIcon,
                                    color: selectedColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Symbol',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tippen zum Ändern',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Color Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final newColor = await showDialog<Color>(
                              context: context,
                              builder: (_) => ColorPickerDialog(selectedColor: selectedColor),
                            );
                            if (newColor != null) {
                              setState(() => selectedColor = newColor);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selectedColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Farbe',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tippen zum Ändern',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Schema Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final newSchema = await showDialog<List<Map<String, dynamic>>>(
                              context: context,
                              builder: (_) => SchemaEditorDialog(existingSchema: editedSchema),
                            );
                            if (newSchema != null) {
                              setState(() {
                                editedSchema = newSchema;
                                if (selectedGroupingKey != null &&
                                    !editedSchema.any((e) => e['key'] == selectedGroupingKey)) {
                                  selectedGroupingKey = null;
                                }
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.schema,
                                    color: Colors.blue[700],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Schema-Einträge',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${editedSchema.length} Feld(er) definiert',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (editedSchema.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gruppierung',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              value: selectedGroupingKey,
                              decoration: InputDecoration(
                                labelText: 'Gruppierung nach Feld',
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                helperText: 'Wähle ein Feld, nach dem die Anlagen gruppiert werden sollen',
                                helperStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Keine Gruppierung'),
                                ),
                                ...editedSchema.map((e) => DropdownMenuItem<String?>(
                                      value: e['key'],
                                      child: Text(e['label']),
                                    )),
                              ],
                              onChanged: (val) => setState(() => selectedGroupingKey = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isNameEmpty
                        ? null
                        : () {
                            final result = Disziplin(
                              label: nameCtrl.text.trim(),
                              icon: selectedIcon,
                              color: selectedColor,
                              schema: editedSchema.cast<Map<String, String>>(),
                              groupingKey: selectedGroupingKey,
                            );
                            Navigator.of(context).pop(result);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 20),
                        const SizedBox(width: 8),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog, um ein Icon auszuwählen.
class IconPickerDialog extends StatelessWidget {
  final IconData selectedIcon;
  const IconPickerDialog({required this.selectedIcon});

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.local_fire_department,
      Icons.air,
      Icons.home,
      Icons.build,
      Icons.settings,
      Icons.new_releases,
      Icons.ac_unit,
      Icons.water_drop,
      Icons.electrical_services,
      Icons.construction,
      Icons.power,
      Icons.bolt,
      Icons.wifi,
      Icons.security,
      Icons.thermostat,
    ];
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.emoji_objects,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Symbol wählen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: icons.length,
                itemBuilder: (_, idx) {
                  final icon = icons[idx];
                  final isSelected = icon == selectedIcon;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog, um eine Farbe auszuwählen.
class ColorPickerDialog extends StatelessWidget {
  final Color selectedColor;
  const ColorPickerDialog({required this.selectedColor});

  @override
  Widget build(BuildContext context) {
    // Edle, professionelle Farbpalette für Business-Anwendung
    final colors = [
      // Gedämpfte Blautöne
      const Color(0xFF4A6FA5), // Edles Blau
      const Color(0xFF5B7BA3), // Helles Blau
      const Color(0xFF3D5A80), // Dunkles Blau
      // Professionelle Grautöne mit Nuancen
      const Color(0xFF6B7280), // Warmes Grau
      const Color(0xFF4B5563), // Mittelgrau
      const Color(0xFF374151), // Dunkelgrau
      // Dezente Grüntöne
      const Color(0xFF4A7C59), // Gedämpftes Grün
      const Color(0xFF5A8A6B), // Helles Grün
      // Blaugrau-Töne
      const Color(0xFF5B7A8A), // Blaugrau
      const Color(0xFF4A6B7A), // Dunkles Blaugrau
      // Gedämpfte Violetttöne
      const Color(0xFF6B5B7A), // Violettgrau
      const Color(0xFF5A4A6B), // Dunkles Violett
      // Warme Brauntöne
      const Color(0xFF7A6B5A), // Warmes Braun
      const Color(0xFF6B5A4A), // Dunkles Braun
      // Edle Akzente
      const Color(0xFF8B7355), // Bronze
      const Color(0xFF6B5A4A), // Kupfer
    ];
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: Colors.grey[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Farbe wählen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: colors.length,
                itemBuilder: (_, idx) {
                  final color = colors[idx];
                  final isSelected = color.value == selectedColor.value;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(color),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.grey[900]!
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1) Haupt-Dialog: Schema bearbeiten
class SchemaEditorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existingSchema;
  SchemaEditorDialog({required this.existingSchema});

  @override
  _SchemaEditorDialogState createState() => _SchemaEditorDialogState();
}

class _SchemaEditorDialogState extends State<SchemaEditorDialog> {
  late List<Map<String, dynamic>> schemaList;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    schemaList = List.from(widget.existingSchema);
  }

  Future<void> _onAddField() async {
    final newField = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddSchemaFieldDialog(uuid: _uuid),
    );
    if (newField != null) {
      setState(() => schemaList.add(newField));
    }
  }

  Future<void> _onEditField(int index) async {
    final existingField = schemaList[index];
    final editedField = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddSchemaFieldDialog(
        uuid: _uuid,
        existingField: existingField,
      ),
    );
    if (editedField != null) {
      setState(() => schemaList[index] = editedField);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.schema,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Schema bearbeiten',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: schemaList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Noch keine Felder',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fügen Sie Felder hinzu, um das Schema zu definieren',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...schemaList.asMap().entries.map((e) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.label_outline,
                                        color: Colors.blue[700],
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            e.value['label'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              letterSpacing: -0.1,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              e.value['type'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _onEditField(e.key),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => setState(() => schemaList.removeAt(e.key)),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
            // Add Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Neues Feld hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _onAddField,
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: () => Navigator.of(context).pop(schemaList),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Speichern',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2) Unter-Dialog: Label + Type, Key intern generiert
class AddSchemaFieldDialog extends StatefulWidget {
  final Uuid uuid;
  final Map<String, dynamic>? existingField;
  AddSchemaFieldDialog({required this.uuid, this.existingField});

  @override
  _AddSchemaFieldDialogState createState() => _AddSchemaFieldDialogState();
}

class _AddSchemaFieldDialogState extends State<AddSchemaFieldDialog> {
  late final TextEditingController labelCtrl;
  late String selectedType;
  late final String? originalKey;

  static const List<String> availableTypes = ['string', 'int'];

  @override
  void initState() {
    super.initState();
    if (widget.existingField != null) {
      labelCtrl = TextEditingController(text: widget.existingField!['label'] ?? '');
      final fieldType = widget.existingField!['type'] ?? 'string';
      // Konvertiere alte Typen zu neuen: 'text' -> 'string', 'number' -> 'int'
      if (fieldType == 'text') {
        selectedType = 'string';
      } else if (fieldType == 'number') {
        selectedType = 'int';
      } else {
        selectedType = availableTypes.contains(fieldType) ? fieldType : 'string';
      }
      originalKey = widget.existingField!['key'];
    } else {
      labelCtrl = TextEditingController();
      selectedType = 'string';
      originalKey = null;
    }
  }

  @override
  void dispose() {
    labelCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => labelCtrl.text.trim().isNotEmpty;

  String _generateKey(String label) {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final shortId = widget.uuid.v4().split('-').first;
    return '${slug}_$shortId';
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingField != null;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.label,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditMode ? 'Feld bearbeiten' : 'Neues Feld anlegen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            TextField(
              controller: labelCtrl,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: InputDecoration(
                labelText: 'Typ',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              items: availableTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: !_canSave
                      ? null
                      : () {
                          final label = labelCtrl.text.trim();
                          Navigator.of(context).pop({
                            'key': originalKey ?? _generateKey(label),
                            'label': label,
                            'type': selectedType,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Speichern',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
