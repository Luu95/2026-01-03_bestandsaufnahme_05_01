// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database.dart' as db;
import 'database/database_service.dart';

import 'providers/database_provider.dart';
import 'providers/projects_provider.dart';
import 'providers/settings_provider.dart';
import 'pages/building_details_page.dart';
import 'navigation/route_observer.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((settings) => settings.themeMode));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projekte & Gebäude',
      navigatorObservers: [routeObserver],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemUiOverlayStyle(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
