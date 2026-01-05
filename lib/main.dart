// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database.dart' as db;
import 'database/database_service.dart';

import 'providers/database_provider.dart';
import 'providers/projects_provider.dart';
import 'pages/building_details_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setzt die Navigationsleiste auf die App-Hintergrundfarbe
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFFEEEEEE),
    systemNavigationBarDividerColor: Color(0xFFEEEEEE),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Optional: Aktiviert den Edge-to-Edge Modus für Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Datenbank initialisieren
  final database = db.AppDatabase();
  final dbService = DatabaseService(database);
  
 
  
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseServiceProvider.overrideWithValue(dbService),
      ],
      child: const MyApp(),
    ),
  );
}

/// MyApp: Einstiegspunkt für die Flutter‐App
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Projekte & Gebäude',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

/// RootPage lädt die gespeicherten Projekte und zeigt das Haupt‐Interface an
class RootPage extends ConsumerWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsProvider);

    if (projectsState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const BuildingDetailsPage();
  }
}
