/// App-Einstieg: initialisiert Binding, Drift-DB und Riverpod-[ProviderScope].
/// Startet [MyApp] mit Theme, RouteObserver und [RootPage] als Home.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/core/database/database.dart' as db;
import 'package:bestandsaufnahme_01/core/database/database_service.dart';

import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/projects_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/settings_provider.dart';
import 'package:bestandsaufnahme_01/features/buildings/pages/building_details_page.dart';
import 'package:bestandsaufnahme_01/app/navigation/route_observer.dart';
import 'package:bestandsaufnahme_01/app/theme/app_theme.dart';
import 'package:bestandsaufnahme_01/features/media/services/ocr_service.dart';

/// Startet die App mit geteilter Datenbank-Instanz (Provider-Overrides).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eine DB-Instanz für die gesamte App-Laufzeit (nicht pro Provider neu öffnen).
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

/// Root-Widget: Theme, Lifecycle (OCR-Cleanup) und [MaterialApp].
class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OcrService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // OCR-Ressourcen freigeben, wenn die App beendet wird.
    if (state == AppLifecycleState.detached) {
      OcrService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
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

/// Startseite: lädt Projekte und zeigt Lade-/Fehlerzustand oder [BuildingDetailsPage].
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

    if (projectsState.lastError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  projectsState.lastError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(projectsProvider.notifier).loadProjects(),
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const BuildingDetailsPage();
  }
}
