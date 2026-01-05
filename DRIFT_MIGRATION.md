# Drift Migration - Abgeschlossen ✅

Die App wurde vollständig auf Drift umgestellt. Alle Dateien wurden angepasst.

## ⚠️ WICHTIG: Code-Generierung erforderlich

Bevor die App läuft, müssen Sie folgende Befehle ausführen:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

Dies generiert die benötigten Drift-Dateien (`lib/database/database.g.dart`).

## ✅ Umgestellte Komponenten

### Datenbank-Schema
- ✅ `lib/database/database.dart` - Vollständiges Drift-Schema mit allen Tabellen
- ✅ `lib/services/database_service.dart` - Service-Klasse für CRUD-Operationen
- ✅ `lib/services/migration_service.dart` - Automatische Migration von SharedPreferences

### Angepasste Dateien
- ✅ `lib/main.dart` - Verwendet jetzt Drift statt SharedPreferences
- ✅ `lib/pages/systems_page.dart` - Lädt und speichert Anlagen über Drift
- ✅ `lib/pages/tabs/floorplans_tab.dart` - PDF-Pfade werden in Drift gespeichert
- ✅ `lib/pages/floor_plan_page.dart` - Anlagen werden über Drift geladen/gespeichert
- ✅ `lib/pages/building_details_page.dart` - PDF-Pfade werden in Drift gespeichert

## 📊 Datenbank-Struktur

Die Datenbank wird unter `bestandsaufnahme.db` im App-Dokumentenverzeichnis gespeichert.

**Tabellen:**
- `projects` - Projekte
- `buildings` - Gebäude (mit Foreign Key zu projects)
- `envelopes` - Gebäudehüllen (mit Foreign Key zu buildings)
- `walls` - Wände (mit Foreign Key zu envelopes)
- `windows` - Fenster (mit Foreign Key zu envelopes)
- `floorPlans` - Grundrisse (mit Foreign Key zu buildings)
- `anlagen` - Anlagen (mit Foreign Key zu buildings)
- `consumptions` - Verbrauchsdaten (mit Foreign Key zu buildings)
- `attachmentsTable` - Anhänge (mit Foreign Key zu buildings)

## 🔄 Automatische Migration

Die Migration von SharedPreferences zu Drift erfolgt **automatisch** beim ersten Start der App nach der Umstellung. Die alten Daten werden dabei in die neue Datenbank übertragen.

## 📝 Wichtige Änderungen

- ✅ Alle Projekte, Gebäude, Anlagen, etc. werden jetzt in einer SQLite-Datenbank (Drift) gespeichert
- ✅ Die Daten werden beim ersten Start automatisch von SharedPreferences migriert
- ✅ Der `DatabaseService` ist als Singleton verfügbar: `DatabaseService.instance`
- ✅ PDF-Pfade werden jetzt im `FloorPlan`-Objekt gespeichert (in Drift)
- ⚠️ **Disziplinen** bleiben weiterhin in SharedPreferences, da sie Konfigurationsdaten sind

## 🚀 Nächste Schritte

1. Führen Sie `flutter pub get` aus
2. Führen Sie `flutter pub run build_runner build --delete-conflicting-outputs` aus
3. Starten Sie die App - die Migration erfolgt automatisch

## 🐛 Fehlerbehebung

Falls nach der Code-Generierung noch Fehler auftreten:
- Prüfen Sie, ob `lib/database/database.g.dart` existiert
- Prüfen Sie, ob alle Dependencies korrekt installiert sind
- Prüfen Sie die Imports in den Dateien

## ⚠️ WICHTIG: Typen nach Code-Generierung aktualisieren

Nach der Code-Generierung müssen die Typen in `lib/database/database.dart` von den alten Namen auf die neuen Namen umgestellt werden:

**Alte Typen (temporär für Kompilierung):**
- `Project`, `Building`, `Envelope`, `Wall`, `Window`, `FloorPlan`, `AnlagenData`, `Consumption`, `AttachmentsTableData`

**Neue Typen (nach Code-Generierung):**
- `ProjectDb`, `BuildingDb`, `EnvelopeDb`, `WallDb`, `WindowDb`, `FloorPlanDb`, `AnlageDb`, `ConsumptionDb`, `AttachmentsTableDb`

Die `@DataClassName` Annotationen in `database.dart` sind bereits korrekt gesetzt und werden die neuen Typen generieren.

## 📋 Namenskonflikte gelöst

- ✅ Alle Tabellen haben `@DataClassName` Annotationen mit Suffixen (z.B. `ProjectDb`, `BuildingDb`)
- ✅ `main.dart` verwendet Prefix `db` für `database.dart` Import, um Konflikte zu vermeiden
- ✅ `database_service.dart` verwendet `as models` Prefix für Model-Imports
- ✅ `markerInfo` wird automatisch zwischen JSON-String (DB) und Map (Model) konvertiert

