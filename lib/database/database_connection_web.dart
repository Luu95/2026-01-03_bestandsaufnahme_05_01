// Web database connection implementation
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

LazyDatabase createConnection() {
  return LazyDatabase(() async {
    final db = await WasmDatabase.open(
      databaseName: 'bestandsaufnahme',
      sqlite3Uri: Uri.parse('/sqlite3.wasm'),
      driftWorkerUri: Uri.parse('/drift_worker.js'),
    );
    return db.resolvedExecutor;
  });
}

