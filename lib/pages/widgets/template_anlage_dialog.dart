import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../database/database_service.dart';
import '../../services/template_service.dart';

class TemplateAnlageDialog extends StatefulWidget {
  final DatabaseService dbService;
  final String projectId;
  final Disziplin discipline;
  final String buildingId;
  final String floorId;
  final void Function(List<Anlage> created) onCreate;
  final VoidCallback? onCreateManual;

  const TemplateAnlageDialog({
    Key? key,
    required this.dbService,
    required this.projectId,
    required this.discipline,
    required this.buildingId,
    required this.floorId,
    required this.onCreate,
    this.onCreateManual,
  }) : super(key: key);

  @override
  State<TemplateAnlageDialog> createState() => _TemplateAnlageDialogState();
}

class _TemplateAnlageDialogState extends State<TemplateAnlageDialog> {
  final _uuid = const Uuid();
  bool _isLoading = true;
  String? _error;
  List<Template> _templates = [];
  List<String> _anlagentypen = [];
  String? _selectedAnlagentyp;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      // Lade ALLE Vorlagen für das Projekt
      final allTemplates =
          await TemplateService.loadTemplatesFromDatabase(widget.dbService, widget.projectId);
      // Filtere nur nach dem aktuellen Gewerk (Disziplin = Gewerk)
      final templates = allTemplates
          .where((t) => t.gewerk == widget.discipline.label)
          .toList();
      final anlagentypen = TemplateService.getAnlagentypenForGewerk(templates);
      setState(() {
        _templates = templates;
        _anlagentypen = anlagentypen;
        _selectedAnlagentyp =
            anlagentypen.isNotEmpty ? anlagentypen.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _createFromTemplate() {
    final selectedType = _selectedAnlagentyp;
    if (selectedType == null || selectedType.trim().isEmpty) return;

    final matching = _templates
        .where((t) => t.anlagentyp.trim() == selectedType.trim())
        .toList();
    final parentTemplate = matching
        .firstWhere((t) => t.anlageBauteil == 'a', orElse: () => Template(
              gewerk: widget.discipline.label,
              anlageBauteil: 'a',
              anlagentyp: selectedType,
              bezeichnung: selectedType,
              parameter: null,
            ));

    final parentId = _uuid.v4();
    final parentName = parentTemplate.bezeichnung.trim().isNotEmpty
        ? parentTemplate.bezeichnung.trim()
        : parentTemplate.anlagentyp.trim();
    final parentParams = TemplateService.buildEmptyParamsFromTemplate(
      parentTemplate.parameter,
    );

    final parent = Anlage(
      id: parentId,
      parentId: null,
      name: parentName,
      params: parentParams,
      floorId: widget.floorId,
      buildingId: widget.buildingId,
      isMarker: false,
      markerInfo: null,
      markerType: widget.discipline.label,
      discipline: widget.discipline,
    );

    final children = matching
        .where((t) => t.anlageBauteil == 'b')
        .map((t) {
      final name = t.bezeichnung.trim().isNotEmpty
          ? t.bezeichnung.trim()
          : t.anlagentyp.trim();
      return Anlage(
        id: _uuid.v4(),
        parentId: parentId,
        name: name,
        params: TemplateService.buildEmptyParamsFromTemplate(t.parameter),
        floorId: widget.floorId,
        buildingId: widget.buildingId,
        isMarker: false,
        markerInfo: null,
        markerType: widget.discipline.label,
        discipline: widget.discipline,
      );
    }).toList();

    widget.onCreate([parent, ...children]);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasTypes = _anlagentypen.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anlage aus Vorlage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  if (widget.onCreateManual != null)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCreateManual?.call();
                      },
                      child: const Text('Manuell'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Fehler beim Laden der Vorlagen: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (!hasTypes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Keine Vorlagen für dieses Gewerk vorhanden.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anlagentyp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedAnlagentyp,
                      items: _anlagentypen
                          .map((t) => DropdownMenuItem<String>(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedAnlagentyp = val),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: hasTypes ? _createFromTemplate : null,
                      child: const Text('Erstellen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

