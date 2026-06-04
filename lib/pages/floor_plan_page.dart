// lib/pages/floor_plan_page.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import '../services/csv_service.dart';
import '../database/database_service.dart';
import '../utils/app_log.dart';

import '../models/anlage.dart';
import '../models/marker.dart';
import '../models/building.dart';
import '../models/floor_plan.dart';
import '../models/disziplin_schnittstelle.dart';
import '../pages/widgets/marker_form_dialog.dart';
import '../providers/csv_settings_provider.dart';

class FloorPlanFullScreen extends StatefulWidget {
  final Building building;
  final FloorPlan floor;
  final DatabaseService dbService;

  const FloorPlanFullScreen({
    Key? key,
    required this.building,
    required this.floor,
    required this.dbService,
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
  bool _isExporting = false;

  List<Anlage> _allAnlagen = [];
  List<Disziplin> _disziplinen = [];
  CsvSettings? _csvSettings;

  bool _isLoading = true;
  String? _currentPdfName;
  final TransformationController _transformationController =
  TransformationController();
  String? _draggingCalloutAnlageId;
  String? _draggingAnchorAnlageId;
  bool _matrixRebuildScheduled = false;

  static const double _defaultLabelDx = 90.0;
  static const double _defaultLabelDy = -70.0;

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
    await _loadCsvSettings();
    await _loadDisziplinen();
    await _loadFloorPlanData();
  }

  Future<void> _loadCsvSettings() async {
    final projectId =
        await widget.dbService.getProjectIdByBuildingId(widget.building.id);
    if (projectId == null || projectId.isEmpty) return;
    final settings = await CsvSettings.loadForProject(projectId);
    if (!mounted) return;
    setState(() => _csvSettings = settings);
  }

  Future<void> _loadDisziplinen() async {
    final list = await widget.dbService.getDisciplinesByBuildingId(widget.building.id);
    if (!mounted) return;
    setState(() {
      _disziplinen = list;
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
    if (_matrixRebuildScheduled) return;
    _matrixRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _matrixRebuildScheduled = false;
      setState(() {});
    });
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
        appLog('Fehler beim Laden/Rendern der PDF', error: e);
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  /// Dynamisch: alle Anlagen beliebiger Disziplin laden
  Future<void> _loadAllAnlagen() async {
    final buildingId = widget.building.id;
    final futures = _disziplinen.map((disziplin) async {
      try {
        return await widget.dbService.getAnlagenByBuildingIdAndDiscipline(
          buildingId,
          disziplin.label,
        );
      } catch (e, st) {
        appLog(
          'Fehler beim Laden für Disziplin "${disziplin.label}"',
          error: e,
          stackTrace: st,
        );
        return <Anlage>[];
      }
    }).toList();

    final lists = await Future.wait(futures);
    final alle = lists.expand((e) => e).toList();

    setState(() {
      _allAnlagen = alle.where((a) => a.floorId == widget.floor.id).toList();
    });
  }

  /// Speichert alle Anlagen einer Disziplin in Drift.
  Future<void> _saveAnlagenForDisziplin(Disziplin disziplin) async {
    final buildingId = widget.building.id;
    // Nicht über Objekt-Identität filtern, sondern stabil über das Label.
    // Disziplinen können aus DB/Fallback neu instanziiert werden.
    final filtered = _allAnlagen
        .where((a) => a.discipline.label == disziplin.label && a.buildingId == buildingId)
        .toList();

    // Speichere jede Anlage einzeln
    for (final anlage in filtered) {
      try {
        final existing = await widget.dbService.getAnlageById(anlage.id);
        if (existing != null) {
          await widget.dbService.updateAnlage(anlage);
        } else {
          await widget.dbService.insertAnlage(anlage);
        }
      } catch (e, st) {
        appLog(
          'Fehler beim Speichern der Anlage ${anlage.id}',
          error: e,
          stackTrace: st,
        );
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

  List<Anlage> _markerAnlagenForPage(int pageNumber) => _allAnlagen
      .where((a) =>
          a.isMarker &&
          a.floorId == widget.floor.id &&
          a.markerInfo != null &&
          (a.markerInfo!['pageNumber'] as int) == pageNumber)
      .toList();

  String _markerLabel(Anlage a) {
    final name = a.name.trim();
    if (name.isNotEmpty) return name;
    return 'Marker ${a.id}';
  }

  Offset _getLabelOffset(Anlage a) {
    final mi = a.markerInfo ?? const <String, dynamic>{};
    final dx = (mi['labelDx'] as num?)?.toDouble() ?? _defaultLabelDx;
    final dy = (mi['labelDy'] as num?)?.toDouble() ?? _defaultLabelDy;
    return Offset(dx, dy);
  }

  void _setLabelOffset(Anlage a, Offset offset) {
    final current = a.markerInfo != null
        ? Map<String, dynamic>.from(a.markerInfo!)
        : <String, dynamic>{};
    current['labelDx'] = offset.dx;
    current['labelDy'] = offset.dy;
    a.markerInfo = current;
  }

  void _setMarkerAnchor(Anlage a, Offset anchor) {
    final current = a.markerInfo != null
        ? Map<String, dynamic>.from(a.markerInfo!)
        : <String, dynamic>{};
    current['x'] = anchor.dx;
    current['y'] = anchor.dy;
    current['pageNumber'] = (current['pageNumber'] as int?) ?? _currentPage;
    a.markerInfo = current;
  }

  Future<void> _persistMarker(Anlage a) async {
    await _saveAnlagenForDisziplin(a.discipline);
  }

  String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'grundriss';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  Rect _computeExpandedPageRectScene({
    required List<_RasterMarkerLayout> layouts,
    required double baseWidth,
    required double baseHeight,
  }) {
    // Standard: Original-PDF-Seite vollständig exportieren.
    final baseRect = Rect.fromLTWH(0, 0, baseWidth, baseHeight);
    if (layouts.isEmpty) return baseRect;

    Rect? box;
    for (final m in layouts) {
      final bubble = Rect.fromLTWH(
        m.calloutTopLeft.dx,
        m.calloutTopLeft.dy,
        _RasterMarkerLayout.bubbleWidth,
        _RasterMarkerLayout.bubbleHeight,
      );
      final anchor = Rect.fromCircle(
        center: m.anchor,
        radius: _RasterMarkerLayout.anchorDiameter / 2,
      );
      final leader = Rect.fromPoints(m.anchor, m.leaderTarget).inflate(6.0);
      final piece = bubble.expandToInclude(anchor).expandToInclude(leader);
      if (box == null) {
        box = piece;
      } else {
        box = box.expandToInclude(piece);
      }
    }

    if (box == null) return baseRect;

    // +10% Rand (mind. 24 Scene-Units). Kein Cropping: Grundriss bleibt immer komplett,
    // wir erweitern nur nach außen, wenn Sprechblasen/Marker außerhalb liegen.
    final padX = max(24.0, box.width * 0.10);
    final padY = max(24.0, box.height * 0.10);
    final padded = Rect.fromLTRB(
      box.left - padX,
      box.top - padY,
      box.right + padX,
      box.bottom + padY,
    );

    return Rect.fromLTRB(
      min(baseRect.left, padded.left),
      min(baseRect.top, padded.top),
      max(baseRect.right, padded.right),
      max(baseRect.bottom, padded.bottom),
    );
  }

  Future<_RasterizedPage> _rasterizePageWithMarkers({
    required Uint8List backgroundPng,
    required double baseWidth,
    required double baseHeight,
    required List<_RasterMarkerLayout> layouts,
    required Rect pageRectScene,
  }) async {
    final codec = await ui.instantiateImageCodec(backgroundPng);
    final frame = await codec.getNextFrame();
    final bg = frame.image;

    final outW = bg.width.toDouble();
    final outH = bg.height.toDouble();

    // Exakt wie in der App: Bild liegt per BoxFit.contain in einem Scene-Container
    // von (baseWidth/baseHeight). Marker-Koordinaten beziehen sich auf diese Scene.
    // Optional erweitern wir die Seite nach außen via pageRectScene (kann negative left/top haben).
    final baseContainer = Size(max(1.0, baseWidth), max(1.0, baseHeight));
    final imageSize = Size(outW, outH);
    final fitted = applyBoxFit(BoxFit.contain, imageSize, baseContainer);
    final destRectScene =
        Alignment.center.inscribe(fitted.destination, Offset.zero & baseContainer);

    final scale = destRectScene.width > 0 ? (outW / destRectScene.width) : 1.0;
    final sMin = scale;

    // Scene -> Pixel im (ggf. erweiterten) Seitenraum
    final originPx = Offset(-pageRectScene.left * scale, -pageRectScene.top * scale);
    Offset toPx(Offset scene) => originPx + (scene * scale);

    final canvasW = max(2.0, pageRectScene.width * scale);
    final canvasH = max(2.0, pageRectScene.height * scale);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    // Weißer Hintergrund für evtl. Seiten-Erweiterungen
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = Colors.white,
    );

    // Bild an die contain-Position zeichnen
    final imageTopLeftPx = originPx + Offset(destRectScene.left * scale, destRectScene.top * scale);
    canvas.drawImage(bg, imageTopLeftPx, Paint());

    if (layouts.isNotEmpty) {
      for (final m in layouts) {
        final accentFill = m.accent.withOpacity(0.85);
        final accentStroke = m.accent.withOpacity(0.75);

        final anchor = toPx(m.anchor);
        final calloutTopLeft = toPx(m.calloutTopLeft);

        final bubbleW = _RasterMarkerLayout.bubbleWidth * scale;
        final bubbleH = _RasterMarkerLayout.bubbleHeight * scale;
        final tailW = _RasterMarkerLayout.tailWidth * scale;
        final tailH = _RasterMarkerLayout.tailHeight * scale;

        final leaderTarget = calloutTopLeft +
            Offset(m.tailOnLeft ? 0.0 : bubbleW, bubbleH / 2);

        // Leader line
        final linePaint = Paint()
          ..color = accentStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * sMin
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(anchor, leaderTarget, linePaint);

        // Anchor
        final anchorDiameter = _RasterMarkerLayout.anchorDiameter * sMin;
        final anchorRadius = anchorDiameter / 2;
        final anchorPath = Path()..addOval(Rect.fromCircle(center: anchor, radius: anchorRadius));
        canvas.drawShadow(anchorPath, Colors.black.withOpacity(0.18), 6.0 * sMin, true);
        canvas.drawCircle(anchor, anchorRadius, Paint()..color = accentFill);
        canvas.drawCircle(
          anchor,
          anchorRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * sMin,
        );

        // Bubble (Body + Tail + Text)
        canvas.save();
        canvas.translate(calloutTopLeft.dx, calloutTopLeft.dy);

        final bubbleRect = Rect.fromLTWH(0, 0, bubbleW, bubbleH);
        final bodyRect = m.tailOnLeft
            ? Rect.fromLTWH(tailW, 0, bubbleRect.width - tailW, bubbleRect.height)
            : Rect.fromLTWH(0, 0, bubbleRect.width - tailW, bubbleRect.height);
        final rrect = RRect.fromRectAndRadius(bodyRect, Radius.circular(10.0 * sMin));
        final bubblePath = Path()..addRRect(rrect);
        canvas.drawShadow(bubblePath, Colors.black.withOpacity(0.10), 6.0 * sMin, true);

        final fillPaint = Paint()
          ..color = Colors.white.withOpacity(0.98)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = m.accent.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * sMin;

        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);

        final midY = bubbleRect.height / 2;
        final tailTop = midY - tailH / 2;
        final tailBottom = midY + tailH / 2;
        final tailPath = Path();
        if (m.tailOnLeft) {
          tailPath
            ..moveTo(tailW, tailTop)
            ..lineTo(0, midY)
            ..lineTo(tailW, tailBottom)
            ..close();
        } else {
          final x = bubbleRect.width - tailW;
          tailPath
            ..moveTo(x, tailTop)
            ..lineTo(bubbleRect.width, midY)
            ..lineTo(x, tailBottom)
            ..close();
        }
        canvas.drawPath(tailPath, fillPaint);
        canvas.drawPath(tailPath, strokePaint);

        final leftPad = m.tailOnLeft ? (tailW + 10.0 * sMin) : (12.0 * sMin);
        final rightPad = m.tailOnLeft ? (12.0 * sMin) : (tailW + 10.0 * sMin);
        final maxTextWidth = max(0.0, bubbleRect.width - leftPad - rightPad);

        final tp = TextPainter(
          text: TextSpan(
            text: m.text,
            style: TextStyle(
              fontSize: 13.0 * sMin,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          maxLines: 2,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxTextWidth);
        tp.paint(canvas, Offset(leftPad, 8.0 * sMin));

        canvas.restore();
      }
    }

    final picture = recorder.endRecording();
    ui.Image? outImage;
    try {
      outImage = await picture.toImage(canvasW.toInt(), canvasH.toInt());
      final outBytes = await outImage.toByteData(format: ui.ImageByteFormat.png);
      if (outBytes == null) {
        throw StateError('Konnte gerasterte PNG-Daten nicht erzeugen.');
      }
      return _RasterizedPage(
        bytes: outBytes.buffer.asUint8List(),
        width: canvasW,
        height: canvasH,
      );
    } finally {
      // Verhindert Peak-Memory bei mehrseitigem Export.
      outImage?.dispose();
      bg.dispose();
    }
  }

  Future<void> _exportPdfWithMarkers() async {
    if (_isLoading || _isExporting) return;
    if (_pageImages.isEmpty || _pdfPageWidth <= 0 || _pdfPageHeight <= 0) return;

    final destination = await showDialog<ExportDestination>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speicherort wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Teilen'),
              subtitle: const Text('Per E-Mail, Messenger etc. versenden'),
              onTap: () => Navigator.of(context).pop(ExportDestination.share),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
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
    if (destination == null) return;

    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();

      final baseTitle = (widget.floor.name.trim().isNotEmpty)
          ? widget.floor.name.trim()
          : (_currentPdfName?.trim().isNotEmpty == true ? _currentPdfName!.trim() : 'Grundriss');
      final safeBase = _sanitizeFileName(baseTitle);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int pageNumber = 1; pageNumber <= _pageImages.length; pageNumber++) {
        final markerAnlagen = _markerAnlagenForPage(pageNumber);
        final layouts = markerAnlagen.map((a) {
          final mi = a.markerInfo ?? const <String, dynamic>{};
          final ax = (mi['x'] as num?)?.toDouble() ?? 0.0;
          final ay = (mi['y'] as num?)?.toDouble() ?? 0.0;
          final anchor = Offset(ax, ay);
          final labelOffset = _getLabelOffset(a);
          final calloutTopLeft = anchor + labelOffset;
          final tailOnLeft = calloutTopLeft.dx >= anchor.dx;
          final text = _markerLabel(a);
          return _RasterMarkerLayout(
            anchor: anchor,
            calloutTopLeft: calloutTopLeft,
            tailOnLeft: tailOnLeft,
            accent: a.discipline.color,
            text: text,
          );
        }).toList();

        final pageRectScene = _computeExpandedPageRectScene(
          layouts: layouts,
          baseWidth: _pdfPageWidth,
          baseHeight: _pdfPageHeight,
        );

        final rasterized = await _rasterizePageWithMarkers(
          backgroundPng: _pageImages[pageNumber - 1],
          baseWidth: _pdfPageWidth,
          baseHeight: _pdfPageHeight,
          layouts: layouts,
          pageRectScene: pageRectScene,
        );

        final pageImage = pw.MemoryImage(rasterized.bytes);
        doc.addPage(
          pw.Page(
            // 1:1 Raster -> PDF, damit keine zusätzliche Skalierung passiert.
            pageFormat: pdf.PdfPageFormat(rasterized.width, rasterized.height),
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.SizedBox(
                width: rasterized.width,
                height: rasterized.height,
                child: pw.Image(pageImage, fit: pw.BoxFit.fill),
              );
            },
          ),
        );
      }

      final bytes = await doc.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = '${safeBase}_mit_markern_$timestamp.pdf';
      final outFile = File(path.join(tempDir.path, fileName));
      await outFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      if (destination == ExportDestination.saveToDevice) {
        final savedPath = await CsvService.saveFileToDevice(
          file: outFile,
          fileName: fileName,
        );
        if (savedPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert unter:\n$savedPath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(outFile.path)],
          text: 'Grundriss mit Markern',
          subject: 'Grundriss-Export',
        );
      }
    } catch (e, stackTrace) {
      appLog('Fehler beim Grundriss-PDF-Export', error: e, stackTrace: stackTrace);
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() => _isExporting = false);
    }
  }

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
      final dx = ((mi['x'] as num).toDouble()) - tappedX;
      final dy = ((mi['y'] as num).toDouble()) - tappedY;
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

  Future<void> _showAddMarkerDialog(double x, double y, int pageNumber) async {
    final selectableExisting = <Anlage>[];
    try {
      final all = await widget.dbService.getAnlagenByBuildingId(widget.building.id);
      selectableExisting.addAll(
        all
            .where((a) => a.parentId == null)
            // Nur "normale" Anlagen (noch kein Marker irgendwo).
            .where((a) => !a.isMarker)
            .toList()
          ..sort((a, b) {
            final dl = a.discipline.label.toLowerCase().compareTo(b.discipline.label.toLowerCase());
            if (dl != 0) return dl;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }),
      );
    } catch (e, st) {
      appLog('Fehler beim Laden bestehender Anlagen', error: e, stackTrace: st);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return MarkerFormDialog(
          dbService: widget.dbService,
          pageNumber: pageNumber,
          x: x,
          y: y,
          buildingId: widget.building.id,
          existing: null,
          selectableExistingAnlagen: selectableExisting,
          onSelectExistingAnlage: (Anlage selected) async {
            await _addAnlageAsMarker(
              selected,
              x,
              y,
              pageNumber: pageNumber,
            );
          },
          onSave: (Marker newMarker) async {
            final newId = newMarker.id;
            final newDisziplin = _disziplinen.firstWhere(
                  (d) => d.label == newMarker.discipline.label,
              orElse: () => newMarker.discipline,
            );

            final params = newMarker.params != null
                ? Map<String, dynamic>.from(newMarker.params!)
                : <String, dynamic>{};

            final leafLabel = _csvSettings?.resolveLeafLevelLabel() ?? 'Eintrag';
            final newAnlage = Anlage(
              id: newId,
              name: newMarker.title.isNotEmpty
                  ? newMarker.title
                  : '$leafLabel $newId',
              params: params,
              floorId: widget.floor.id,
              buildingId: widget.building.id,
              isMarker: true,
              markerInfo: {
                'x': newMarker.x,
                'y': newMarker.y,
                'pageNumber': newMarker.pageNumber,
                'labelDx': _defaultLabelDx,
                'labelDy': _defaultLabelDy,
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

  Future<void> _addAnlageAsMarker(
    Anlage anlage,
    double x,
    double y, {
    required int pageNumber,
  }) async {
    // Erstelle eine Kopie der Anlage mit Marker-Informationen
    final updatedAnlage = Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: Map<String, dynamic>.from(anlage.params),
      floorId: widget.floor.id, // Aktualisiere floorId auf den aktuellen Grundriss
      buildingId: anlage.buildingId,
      isMarker: true,
      markerInfo: {
        'x': x,
        'y': y,
        'pageNumber': pageNumber,
        'labelDx': _defaultLabelDx,
        'labelDy': _defaultLabelDy,
      },
      markerType: anlage.discipline.label,
      discipline: anlage.discipline,
    );

    // Speichere in der Datenbank
    await widget.dbService.updateAnlage(updatedAnlage);

    // Aktualisiere lokale Liste
    setState(() {
      final index = _allAnlagen.indexWhere((a) => a.id == anlage.id);
      if (index >= 0) {
        _allAnlagen[index] = updatedAnlage;
      } else {
        _allAnlagen.add(updatedAnlage);
      }
    });

    await _saveAnlagenForDisziplin(updatedAnlage.discipline);
    await _loadAllAnlagen();
  }

  void _showEditMarkerDialog(Anlage a) {
    final existingMarker = Marker(
      id: a.id,
      discipline: a.discipline,
      title: a.name,
      x: (a.markerInfo!['x'] as num).toDouble(),
      y: (a.markerInfo!['y'] as num).toDouble(),
      pageNumber: a.markerInfo!['pageNumber'] as int,
      params: a.params,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return MarkerFormDialog(
          dbService: widget.dbService,
          pageNumber: existingMarker.pageNumber,
          x: existingMarker.x,
          y: existingMarker.y,
          buildingId: widget.building.id,
          existing: existingMarker,
          onRemoveFromFloorPlan: () async {
            setState(() {
              a.isMarker = false;
              a.markerInfo = null;
            });

            // Direkt persistieren, ohne die Anlage zu löschen.
            await widget.dbService.updateAnlage(a);

            await _saveAnlagenForDisziplin(a.discipline);
            await _loadAllAnlagen();
          },
          onSave: (Marker updatedMarker) async {
            setState(() {
              a.name = updatedMarker.title;
              final params = updatedMarker.params != null
                  ? Map<String, dynamic>.from(updatedMarker.params!)
                  : <String, dynamic>{};
              a.params = params;
              final oldMarkerInfo = a.markerInfo != null
                  ? Map<String, dynamic>.from(a.markerInfo!)
                  : <String, dynamic>{};
              a.markerInfo = {
                ...oldMarkerInfo,
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
            await widget.dbService.hardDeleteAnlage(a.id);
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
                      // Header mit X-Button, Titel, Add-Button
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
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: _isExporting
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      padding: EdgeInsets.zero,
                                      tooltip: 'PDF mit Markern exportieren',
                                      icon: const Icon(Icons.picture_as_pdf),
                                      onPressed: (_pdfFile == null || _pageImages.isEmpty)
                                          ? null
                                          : _exportPdfWithMarkers,
                                    ),
                            ),
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
                                    // Leader-Lines (hinter den Callouts)
                                    CustomPaint(
                                      size: Size(_pdfPageWidth, _pdfPageHeight),
                                      painter: _MarkerLeaderLinesPainter(
                                        markerAnlagen: _markerAnlagen,
                                        getLabelOffset: _getLabelOffset,
                                        getLabelText: _markerLabel,
                                        scale: scale,
                                      ),
                                    ),

                                    // Marker: Ankerpunkt + Callout (Bezeichnung)
                                    for (final a in _markerAnlagen)
                                      Builder(builder: (_) {
                                        final disziplin = a.discipline;
                                        final color = disziplin.color.withOpacity(0.85);

                                        final mx = (a.markerInfo!['x'] as num).toDouble();
                                        final my = (a.markerInfo!['y'] as num).toDouble();
                                        final anchor = Offset(mx, my);
                                        final labelOffset = _getLabelOffset(a);
                                        final calloutTopLeft = anchor + labelOffset;
                                        final tailOnLeft = calloutTopLeft.dx >= anchor.dx;

                                        // Anker-Punktgröße in Screen-Pixeln konstant halten
                                        const double anchorDiameter = 12.0;
                                        final anchorOffset = (anchorDiameter / 2) / scale;

                                        return Stack(
                                          children: [
                                            // Ankerpunkt (kleiner Punkt statt Symbol)
                                            Positioned(
                                              left: anchor.dx - anchorOffset,
                                              top: anchor.dy - anchorOffset,
                                              child: Transform.scale(
                                                scale: 1 / scale,
                                                alignment: Alignment.topLeft,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => _showEditMarkerDialog(a),
                                                  onPanStart: (_) {
                                                    setState(() {
                                                      _draggingAnchorAnlageId = a.id;
                                                    });
                                                  },
                                                  onPanUpdate: (d) {
                                                    if (_draggingAnchorAnlageId != a.id) return;
                                                    final deltaScene = d.delta / scale;
                                                    setState(() {
                                                      final currentAx = (a.markerInfo?['x'] as num?)?.toDouble() ?? anchor.dx;
                                                      final currentAy = (a.markerInfo?['y'] as num?)?.toDouble() ?? anchor.dy;
                                                      _setMarkerAnchor(a, Offset(currentAx, currentAy) + deltaScene);
                                                    });
                                                  },
                                                  onPanEnd: (_) async {
                                                    if (_draggingAnchorAnlageId != a.id) return;
                                                    setState(() {
                                                      _draggingAnchorAnlageId = null;
                                                    });
                                                    await _persistMarker(a);
                                                  },
                                                  child: Container(
                                                    width: anchorDiameter,
                                                    height: anchorDiameter,
                                                    decoration: BoxDecoration(
                                                      color: color,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.18),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Callout-Label (sprechblasenartig), verschiebbar
                                            Positioned(
                                              left: calloutTopLeft.dx,
                                              top: calloutTopLeft.dy,
                                              child: Transform.scale(
                                                scale: 1 / scale,
                                                alignment: Alignment.topLeft,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.translucent,
                                                  onTap: () => _showEditMarkerDialog(a),
                                                  onPanStart: (_) {
                                                    setState(() {
                                                      _draggingCalloutAnlageId = a.id;
                                                    });
                                                  },
                                                  onPanUpdate: (d) {
                                                    if (_draggingCalloutAnlageId != a.id) return;
                                                    final deltaScene = d.delta / scale;
                                                    setState(() {
                                                      final currentOffset = _getLabelOffset(a);
                                                      _setLabelOffset(a, currentOffset + deltaScene);
                                                    });
                                                  },
                                                  onPanEnd: (_) async {
                                                    if (_draggingCalloutAnlageId != a.id) return;
                                                    setState(() {
                                                      _draggingCalloutAnlageId = null;
                                                    });
                                                    await _persistMarker(a);
                                                  },
                                                  child: _MarkerCalloutBubble(
                                                    text: _markerLabel(a),
                                                    accent: disziplin.color,
                                                    tailOnLeft: tailOnLeft,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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

class _MarkerLeaderLinesPainter extends CustomPainter {
  final List<Anlage> markerAnlagen;
  final Offset Function(Anlage) getLabelOffset;
  final String Function(Anlage) getLabelText;
  final double scale;

  _MarkerLeaderLinesPainter({
    required this.markerAnlagen,
    required this.getLabelOffset,
    required this.getLabelText,
    required this.scale,
  });

  static const _bubbleMaxWidthPx = 240.0;
  static const _tailWidthPx = 10.0;
  static const _textStyle = TextStyle(
    fontSize: 13,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  Size _estimateBubbleSizePx({
    required String text,
    required bool tailOnLeft,
  }) {
    final leftPad = tailOnLeft ? _tailWidthPx + 10.0 : 12.0;
    final rightPad = tailOnLeft ? 12.0 : _tailWidthPx + 10.0;
    const verticalPad = 16.0; // 8 oben + 8 unten

    final maxTextWidth = max(0.0, _bubbleMaxWidthPx - leftPad - rightPad);
    final tp = TextPainter(
      text: TextSpan(text: text, style: _textStyle),
      maxLines: 2,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    final width = min(_bubbleMaxWidthPx, tp.width + leftPad + rightPad);
    final height = tp.height + verticalPad;
    return Size(width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (markerAnlagen.isEmpty) return;

    for (final a in markerAnlagen) {
      final mi = a.markerInfo;
      if (mi == null) continue;

      final ax = (mi['x'] as num?)?.toDouble();
      final ay = (mi['y'] as num?)?.toDouble();
      if (ax == null || ay == null) continue;

      final anchor = Offset(ax, ay);
      final offset = getLabelOffset(a);
      final calloutTopLeft = anchor + offset;

      final tailOnLeft = calloutTopLeft.dx >= anchor.dx;
      final label = getLabelText(a);
      final bubbleSizePx = _estimateBubbleSizePx(text: label, tailOnLeft: tailOnLeft);

      // Andockpunkt: an die Tail-Spitze (links/rechts) + vertikale Mitte.
      // Wichtig: Bubble wird mit 1/scale gegengezoomt, daher hier Screen-Pixel -> Scene-Units via /scale.
      final localTargetPx = Offset(
        tailOnLeft ? 0.0 : bubbleSizePx.width,
        bubbleSizePx.height / 2,
      );
      final target = calloutTopLeft + (localTargetPx / scale);

      final paint = Paint()
        ..color = a.discipline.color.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale
        ..strokeCap = StrokeCap.round;

      final dotPaint = Paint()
        ..color = a.discipline.color.withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchor, 2.2 / scale, dotPaint);

      canvas.drawLine(anchor, target, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerLeaderLinesPainter oldDelegate) {
    // Repaint bei Zoom oder Marker-Änderungen.
    return oldDelegate.scale != scale || oldDelegate.markerAnlagen != markerAnlagen;
  }
}

class _MarkerCalloutBubble extends StatelessWidget {
  final String text;
  final Color accent;
  final bool tailOnLeft;

  const _MarkerCalloutBubble({
    required this.text,
    required this.accent,
    required this.tailOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    const tailWidth = 10.0;

    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: CustomPaint(
          painter: _CalloutBubblePainter(
            borderColor: accent.withOpacity(0.85),
            tailOnLeft: tailOnLeft,
            tailWidth: tailWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tailOnLeft ? tailWidth + 10 : 12,
              8,
              tailOnLeft ? 12 : tailWidth + 10,
              8,
            ),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalloutBubblePainter extends CustomPainter {
  final Color borderColor;
  final bool tailOnLeft;
  final double tailWidth;

  _CalloutBubblePainter({
    required this.borderColor,
    required this.tailOnLeft,
    required this.tailWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 10.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.98)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final bodyRect = tailOnLeft
        ? Rect.fromLTWH(tailWidth, 0, rect.width - tailWidth, rect.height)
        : Rect.fromLTWH(0, 0, rect.width - tailWidth, rect.height);

    final rrect = RRect.fromRectAndRadius(bodyRect, Radius.circular(radius));

    // Shadow (leicht nach unten versetzt)
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // Body
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, strokePaint);

    // Tail (kleines Dreieck in der Mitte)
    final midY = rect.height / 2;
    final tailHeight = 12.0;
    final tailTop = midY - tailHeight / 2;
    final tailBottom = midY + tailHeight / 2;

    final path = Path();
    if (tailOnLeft) {
      path.moveTo(tailWidth, tailTop);
      path.lineTo(0, midY);
      path.lineTo(tailWidth, tailBottom);
      path.close();
    } else {
      final x = rect.width - tailWidth;
      path.moveTo(x, tailTop);
      path.lineTo(rect.width, midY);
      path.lineTo(x, tailBottom);
      path.close();
    }

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CalloutBubblePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.tailOnLeft != tailOnLeft ||
        oldDelegate.tailWidth != tailWidth;
  }
}

class _RasterMarkerLayout {
  final Offset anchor;
  final Offset calloutTopLeft;
  final bool tailOnLeft;
  final Color accent;
  final String text;

  static const double bubbleWidth = 240.0;
  static const double bubbleHeight = 46.0;
  static const double tailWidth = 10.0;
  static const double tailHeight = 12.0;
  static const double anchorDiameter = 12.0;

  const _RasterMarkerLayout({
    required this.anchor,
    required this.calloutTopLeft,
    required this.tailOnLeft,
    required this.accent,
    required this.text,
  });

  Offset get leaderTarget =>
      calloutTopLeft + Offset(tailOnLeft ? 0.0 : bubbleWidth, bubbleHeight / 2);
}

class _RasterizedPage {
  final Uint8List bytes;
  final double width;
  final double height;

  const _RasterizedPage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}
