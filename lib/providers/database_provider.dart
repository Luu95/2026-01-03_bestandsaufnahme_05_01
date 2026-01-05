// lib/providers/database_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart' as db;
import '../database/database_service.dart';

/// Provider für die AppDatabase-Instanz
final appDatabaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

/// Provider für den DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return DatabaseService(database);
});



