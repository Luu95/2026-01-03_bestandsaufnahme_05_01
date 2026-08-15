/// QR-Code-Scan aus einem Bild über Google ML Kit Barcode Scanning.
/// Liefert den ersten nicht-leeren Roh- oder Anzeigewert bzw. `null`.

import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Statischer Hilfsdienst zum Auslesen eines QR-Codes aus einer Bilddatei.
class QrScanService {
  /// Scannt [image] nach QR-Codes und gibt den ersten gefundenen Text zurück.
  static Future<String?> scanQrCodeFromImage(File image) async {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final barcodes = await scanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final raw = barcode.rawValue?.trim() ?? '';
        if (raw.isNotEmpty) return raw;
        final display = barcode.displayValue?.trim() ?? '';
        if (display.isNotEmpty) return display;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }
}
