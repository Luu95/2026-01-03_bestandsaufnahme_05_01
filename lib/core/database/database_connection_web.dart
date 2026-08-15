/// Drift-Datenbankverbindung für Web (WASM).
/// Öffnet `bestandsaufnahme` über sqlite3.wasm und den Drift-Worker.
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Erzeugt eine [LazyDatabase] mit WasmDatabase für den Browser.
LazyDatabase createConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'bestandsaufnahme',
      // Relative URIs, damit Assets mit Flutter base href korrekt aufgelöst werden.
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      debugPrint(
        'Drift web: using ${result.chosenImplementation} due to missing '
        'browser features: ${result.missingFeatures}',
      );
    }

    return result.resolvedExecutor;
  });
}
