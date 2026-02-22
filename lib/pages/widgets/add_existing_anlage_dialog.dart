// lib/pages/widgets/add_existing_anlage_dialog.dart

import 'package:flutter/material.dart';
import '../../database/database_service.dart';
import '../../models/anlage.dart';

/// Bottom-Sheet-Dialog: Liste aller Anlagen des Gebäudes/Flurs, die noch nicht
/// als Marker auf dem Grundriss liegen. Auswahl einer Anlage gibt sie zurück.
class AddExistingAnlageDialog extends StatefulWidget {
  final DatabaseService dbService;
  final String buildingId;
  final String floorId;
  final List<Anlage> existingMarkerAnlagen;

  const AddExistingAnlageDialog({
    Key? key,
    required this.dbService,
    required this.buildingId,
    required this.floorId,
    required this.existingMarkerAnlagen,
  }) : super(key: key);

  @override
  State<AddExistingAnlageDialog> createState() => _AddExistingAnlageDialogState();
}

class _AddExistingAnlageDialogState extends State<AddExistingAnlageDialog> {
  List<Anlage> _anlagen = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnlagen();
  }

  Future<void> _loadAnlagen() async {
    try {
      final all = await widget.dbService.getAnlagenByBuildingId(widget.buildingId);
      final existingIds = widget.existingMarkerAnlagen.map((a) => a.id).toSet();
      final available = all
          .where((a) =>
              a.floorId == widget.floorId &&
              !existingIds.contains(a.id) &&
              a.parentId == null)
          .toList();
      if (mounted) {
        setState(() {
          _anlagen = available;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _anlagen = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vorhandene Anlage hinzufügen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                )
              else if (_anlagen.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Keine weiteren Anlagen für diesen Flur verfügbar.'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _anlagen.length,
                    itemBuilder: (context, index) {
                      final a = _anlagen[index];
                      return ListTile(
                        leading: Icon(Icons.category, color: a.discipline.color),
                        title: Text(a.name),
                        subtitle: Text(a.discipline.label),
                        onTap: () => Navigator.of(context).pop(a),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
