import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class OcrCameraPage extends StatefulWidget {
  const OcrCameraPage({
    Key? key,
  }) : super(key: key);

  @override
  State<OcrCameraPage> createState() => _OcrCameraPageState();
}

class _OcrCameraPageState extends State<OcrCameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('OCR Camera: Starte Kamera-Initialisierung...');
      _cameras = await availableCameras();
      debugPrint('OCR Camera: Verfügbare Kameras: ${_cameras?.length ?? 0}');
      
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('OCR Camera: Keine Kamera verfügbar');
        if (mounted) {
          setState(() {
            _errorMessage = 'Keine Kamera verfügbar';
          });
        }
        return;
      }

      debugPrint('OCR Camera: Erstelle CameraController...');
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      debugPrint('OCR Camera: Initialisiere Controller...');
      await _controller!.initialize();
      debugPrint('OCR Camera: Controller erfolgreich initialisiert');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('OCR Camera: Fehler beim Initialisieren: $e');
      debugPrint('OCR Camera: StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler beim Initialisieren der Kamera: $e';
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _controller!.takePicture();
      
      // Speichere das Bild in einem permanenten Verzeichnis
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ocr_image_$timestamp.jpg';
      final filePath = path.join(directory.path, fileName);
      
      final savedImage = await File(image.path).copy(filePath);
      
      if (mounted) {
        Navigator.of(context).pop(savedImage);
      }
    } catch (e) {
      debugPrint('OCR Camera: Fehler beim Aufnehmen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Aufnehmen des Fotos: $e')),
        );
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fehleranzeige
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          ),
        ),
      );
    }

    // Ladeanzeige
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Kamera wird initialisiert...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Abbrechen',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Kamera-Ansicht mit Overlay
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera-Vorschau
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Orientierungsrahmen (Rechteck in der Mitte)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.6,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Ecken-Markierungen für bessere Orientierung
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Anweisungstext oben
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Richten Sie das Typenschild im Rahmen aus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Buttons unten
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Abbrechen-Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                
                // Foto-Button
                GestureDetector(
                  onTap: _isCapturing ? null : _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing ? Colors.grey : Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.black),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 36,
                          ),
                  ),
                ),
                
                // Platzhalter für Symmetrie
                const SizedBox(width: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
