// lib/pages/floor_plan_page.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../database/database_service.dart';

import '../models/anlage.dart';
import '../models/marker.dart';
import '../models/building.dart';
import '../models/floor_plan.dart';
import '../models/disziplin_schnittstelle.dart';
import '../pages/widgets/marker_form_dialog.dart';

class FloorPlanFullScreen extends StatefulWidget {
  final Building building;
  final FloorPlan floor;

  const FloorPlanFullScreen({
    Key? key,
    required this.building,
    required this.floor,
  }) : super(key: key);

  @override
  State<FloorPlanFullScreen> createState() => _FloorPlanFullScreenState();
}

class _FloorPlanFullScreenState extends State<FloorPlanFullScreen> {
  File? _pdfFile;
  PdfDocument? _pdfDocument;
  List<Uint8List> _pageImages = [];
  double _pdfPageWidth = 0;
  double _pdfPageHeight = 0;
  int _currentPage = 1;

  List<Anlage> _allAnlagen = [];
  List<Disziplin> _disziplinen = [];

  bool _isLoading = true;
  String? _currentPdfName;
  final TransformationController _transformationController =
  TransformationController();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onMatrixChanged);
    // Wichtig: Disziplinen müssen vor dem Laden der Anlagen verfügbar sein,
    // sonst lädt _loadAllAnlagen() ggf. 0 Marker (Race-Condition) und beim
    // erneuten Öffnen "verschwinden" die Marker trotz DB-Persistenz.
    Future.microtask(_init);
  }

  Future<void> _init() async {
    await _loadDisziplinen();
    await _loadFloorPlanData();
  }

  Future<void> _loadDisziplinen() async {
    final dbService = DatabaseService.instance;
    if (dbService != null) {
      final list = await dbService.getDisciplinesByBuildingId(widget.building.id);
      if (!mounted) return;
      setState(() {
        _disziplinen = list;
      });
      return;
    }

    // Fallback (z.B. wenn DatabaseService noch nicht initialisiert ist)
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('disziplinen_${widget.building.id}');
    if (jsonStr != null) {
      final list = json.decode(jsonStr) as List<dynamic>;
      setState(() {
        _disziplinen = list
            .map((e) => Disziplin.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      return;
    }

    // Standard-Disziplinen falls keine gespeichert
    setState(() {
      _disziplinen = [
        Disziplin(
          label: 'Heizung',
          icon: Icons.local_fire_department,
          color: const Color.fromRGBO(255, 165, 0, 0.9),
          schema: [
            {'key': 'leistung', 'label': 'Leistung (kW)', 'type': 'int'},
            {'key': 'brennstoff', 'label': 'Brennstofftyp', 'type': 'string'},
          ],
        ),
        Disziplin(
          label: 'Lüftung',
          icon: Icons.air,
          color: const Color.fromRGBO(0, 0, 255, 0.8),
          schema: [
            {'key': 'volumenstrom', 'label': 'Volumenstrom (m³/h)', 'type': 'int'},
            {'key': 'filtertyp', 'label': 'Filtertyp', 'type': 'string'},
          ],
        ),
      ];
    });
  }

  @override
  void didUpdateWidget(covariant FloorPlanFullScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.building.id != widget.building.id ||
        oldWidget.floor.id != widget.floor.id) {
      // Building/Floor-Wechsel: Disziplinen + PDF + Marker neu laden
      Future.microtask(_init);
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    _transformationController.removeListener(_onMatrixChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onMatrixChanged() {
    setState(() {});
  }

  Future<void> _loadFloorPlanData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final pdfPath = widget.floor.pdfPath;
    if (pdfPath != null && File(pdfPath).existsSync()) {
      try {
        final doc = await PdfDocument.openFile(pdfPath);
        _pdfDocument = doc;

        // Seite 1 abrufen, um Dimensionen zu ermitteln
        final pageInfo = await doc.getPage(1);
        _pdfPageWidth = pageInfo.width;
        _pdfPageHeight = pageInfo.height;
        await pageInfo.close();

        // Alle Seiten laden und rendern
        final tempImages = <Uint8List>[];
        for (int i = 1; i <= doc.pagesCount; i++) {
          final page = await doc.getPage(i);
          final pageImage = await page.render(
            width: _pdfPageWidth,
            height: _pdfPageHeight,
            format: PdfPageImageFormat.png,
          );
          tempImages.add(pageImage!.bytes);
          await page.close();
        }

        setState(() {
          _pdfFile = File(pdfPath);
          _pageImages = tempImages;
          _currentPage = 1;
        });

        // PDF-Name aus FloorPlan-Objekt oder Dateiname ermitteln
        _currentPdfName = (widget.floor.pdfName != null && widget.floor.pdfName!.isNotEmpty)
            ? widget.floor.pdfName!
            : path.basename(pdfPath);

        // Marker-Anlagen nachladen
        await _loadAllAnlagen();
      } catch (e) {
        debugPrint('Fehler beim Laden/Rendern der PDF: \$e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  /// Dynamisch: alle Anlagen beliebiger Disziplin laden
  Future<void> _loadAllAnlagen() async {
    final dbService = DatabaseService.instance;
    if (dbService == null) {
      setState(() {
        _allAnlagen = [];
      });
      return;
    }

    final buildingId = widget.building.id;
    final List<Anlage> alle = [];

    for (final disziplin in _disziplinen) {
      try {
        final anlagen = await dbService.getAnlagenByBuildingIdAndDiscipline(buildingId, disziplin.label);
        alle.addAll(anlagen);
      } catch (e) {
        debugPrint('Fehler beim Laden für Disziplin ${disziplin.label}: $e');
      }
    }

    setState(() {
      _allAnlagen = alle.where((a) => a.floorId == widget.floor.id).toList();
    });
  }

  /// Speichert alle Anlagen einer Disziplin in Drift.
  Future<void> _saveAnlagenForDisziplin(Disziplin disziplin) async {
    final dbService = DatabaseService.instance;
    if (dbService == null) return;

    final buildingId = widget.building.id;
    // Nicht über Objekt-Identität filtern, sondern stabil über das Label.
    // Disziplinen können aus DB/Fallback neu instanziiert werden.
    final filtered = _allAnlagen
        .where((a) => a.discipline.label == disziplin.label && a.buildingId == buildingId)
        .toList();

    // Speichere jede Anlage einzeln
    for (final anlage in filtered) {
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

  /// Marker-Anlagen für diesen Floor und Seite.
  List<Anlage> get _markerAnlagen => _allAnlagen
      .where((a) =>
  a.isMarker &&
      a.floorId == widget.floor.id &&
      a.markerInfo != null &&
      (a.markerInfo!['pageNumber'] as int) == _currentPage)
      .toList();

  void _handleTapUp(TapUpDetails details) {
    final local = details.localPosition;
    final matrix = _transformationController.value;
    late Matrix4 inverseMatrix;
    try {
      inverseMatrix = Matrix4.inverted(matrix);
    } catch (e) {
      return;
    }
    final untransformed = MatrixUtils.transformPoint(inverseMatrix, local);
    final tappedX = untransformed.dx;
    final tappedY = untransformed.dy;

    const double hitRadius = 20.0;
    for (final a in _markerAnlagen) {
      final mi = a.markerInfo!;
      final dx = (mi['x'] as double) - tappedX;
      final dy = (mi['y'] as double) - tappedY;
      if (sqrt(dx * dx + dy * dy) <= hitRadius) {
        _showEditMarkerDialog(a);
        return;
      }
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final local = details.localPosition;
    final matrix = _transformationController.value;
    late Matrix4 inverseMatrix;
    try {
      inverseMatrix = Matrix4.inverted(matrix);
    } catch (e) {
      return;
    }
    final untransformed = MatrixUtils.transformPoint(inverseMatrix, local);
    if (untransformed.dx < 0 ||
        untransformed.dy < 0 ||
        untransformed.dx > _pdfPageWidth ||
        untransformed.dy > _pdfPageHeight) {
      return;
    }
    _showAddMarkerDialog(
      untransformed.dx,
      untransformed.dy,
      _currentPage,
    );
  }

  void _showAddMarkerDialog(double x, double y, int pageNumber) {
    showDialog(
      context: context,
      builder: (ctx) {
        return MarkerFormDialog(
          pageNumber: pageNumber,
          x: x,
          y: y,
          buildingId: widget.building.id,
          existing: null,
          onSave: (Marker newMarker) async {
            final newId = newMarker.id;
            final newDisziplin = _disziplinen.firstWhere(
                  (d) => d.label == newMarker.discipline.label,
              orElse: () => newMarker.discipline,
            );

            final params = newMarker.params != null
                ? Map<String, dynamic>.from(newMarker.params!)
                : <String, dynamic>{};
            // Etage automatisch setzen (Etage = Name/PDF-Name des aktuellen Grundrisses)
            final floorLabel = widget.floor.name.trim().isNotEmpty
                ? widget.floor.name.trim()
                : (_currentPdfName?.trim().isNotEmpty == true
                    ? _currentPdfName!.trim()
                    : '');
            if (floorLabel.isNotEmpty) {
              final existing = params['Etage']?.toString().trim() ?? '';
              if (existing.isEmpty) {
                params['Etage'] = floorLabel;
              }
            }

            final newAnlage = Anlage(
              id: newId,
              name: newMarker.title.isNotEmpty
                  ? newMarker.title
                  : 'Anlage \$newId',
              params: params,
              floorId: widget.floor.id,
              buildingId: widget.building.id,
              isMarker: true,
              markerInfo: {
                'x': newMarker.x,
                'y': newMarker.y,
                'pageNumber': newMarker.pageNumber,
              },
              markerType: newDisziplin.label,
              discipline: newDisziplin,
            );
            setState(() {
              _allAnlagen.add(newAnlage);
            });
            await _saveAnlagenForDisziplin(newDisziplin);
            await _loadAllAnlagen();
          },
          onDelete: null,
        );
      },
    );
  }

  void _showEditMarkerDialog(Anlage a) {
    final existingMarker = Marker(
      id: a.id,
      discipline: a.discipline,
      title: a.name,
      x: a.markerInfo!['x'] as double,
      y: a.markerInfo!['y'] as double,
      pageNumber: a.markerInfo!['pageNumber'] as int,
      params: a.params,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return MarkerFormDialog(
          pageNumber: existingMarker.pageNumber,
          x: existingMarker.x,
          y: existingMarker.y,
          buildingId: widget.building.id,
          existing: existingMarker,
          onSave: (Marker updatedMarker) async {
            setState(() {
              a.name = updatedMarker.title;
              final params = updatedMarker.params != null
                  ? Map<String, dynamic>.from(updatedMarker.params!)
                  : <String, dynamic>{};
              // Etage beim Bearbeiten ebenfalls sicherstellen
              final floorLabel = widget.floor.name.trim().isNotEmpty
                  ? widget.floor.name.trim()
                  : (_currentPdfName?.trim().isNotEmpty == true
                      ? _currentPdfName!.trim()
                      : '');
              if (floorLabel.isNotEmpty) {
                final existing = params['Etage']?.toString().trim() ?? '';
                if (existing.isEmpty) {
                  params['Etage'] = floorLabel;
                }
              }
              a.params = params;
              a.markerInfo = {
                'x': updatedMarker.x,
                'y': updatedMarker.y,
                'pageNumber': updatedMarker.pageNumber,
              };
              a.discipline = updatedMarker.discipline;
              a.markerType = updatedMarker.discipline.label;
            });
            await _saveAnlagenForDisziplin(a.discipline);
            await _loadAllAnlagen();
          },
          onDelete: (Marker toDelete) async {
            final dbService = DatabaseService.instance;
            if (dbService != null) {
              await dbService.deleteAnlage(a.id);
            }
            setState(() {
              _allAnlagen.removeWhere((e) => e.id == a.id);
            });
            await _loadAllAnlagen();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Header mit X-Button, Titel
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 16.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close, size: 28),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentPdfName ?? 'Grundriss',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                      ),

                      // PDF‐Bereich (nutzt flexibel den Rest des Panels)
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : (_pdfFile == null
                            ? const Center(child: Text('Kein PDF vorhanden.'))
                            : LayoutBuilder(
                          builder: (context, constraints) {
                            final matrix = _transformationController.value;
                            final scale = matrix.getMaxScaleOnAxis();

                            return GestureDetector(
                              onTapUp: _handleTapUp,
                              onLongPressStart: _handleLongPressStart,
                              child: InteractiveViewer(
                                transformationController:
                                _transformationController,
                                panEnabled: true,
                                scaleEnabled: true,
                                boundaryMargin: const EdgeInsets.all(
                                    double.infinity),
                                minScale: 0.2,
                                maxScale: 5.0,
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      width: _pdfPageWidth,
                                      height: _pdfPageHeight,
                                      child: Image.memory(
                                        _pageImages[_currentPage - 1],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    // Marker-Symbole
                                    for (final a in _markerAnlagen)
                                      Builder(builder: (_) {
                                        final disziplin = a.discipline;
                                        const iconSize = 40.0;
                                        final halfIcon = iconSize / 2;
                                        final offset = halfIcon / scale;

                                        final iconData = disziplin.icon;
                                        final iconColor =disziplin.color.withOpacity(0.8);

                                        final mx = a.markerInfo!['x'] as double;
                                        final my = a.markerInfo!['y'] as double;

                                        return Positioned(
                                          left: mx - offset,
                                          top: my - offset * 2,
                                          child: Transform.scale(
                                            scale: 1 / scale,
                                            alignment:
                                            Alignment.topLeft,
                                            child: Icon(
                                              iconData,
                                              size: iconSize,
                                              color: iconColor,
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
                      ),

                      // Seiten‐Navigation (falls > 1 Seite)
                      if (_pageImages.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 1
                                    ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                                    : null,
                              ),
                              Text(
                                'Seite \$_currentPage / \${_pageImages.length}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < _pageImages.length
                                    ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
