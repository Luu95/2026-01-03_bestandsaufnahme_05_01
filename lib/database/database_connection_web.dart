// Web database connection implementation
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

LazyDatabase createConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'bestandsaufnahme',
      // Relative URIs so assets resolve correctly with Flutter's base href.
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

