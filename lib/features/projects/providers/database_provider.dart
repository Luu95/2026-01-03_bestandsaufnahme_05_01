/// Riverpod-Provider für [AppDatabase] und [DatabaseService].
/// Die Instanzen werden in `main.dart` typischerweise überschrieben.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestandsaufnahme_01/core/database/database.dart' as db;
import 'package:bestandsaufnahme_01/core/database/database_service.dart';

/// Provider für die [AppDatabase]-Instanz.
final appDatabaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

/// Provider für den [DatabaseService].
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return DatabaseService(database);
});
