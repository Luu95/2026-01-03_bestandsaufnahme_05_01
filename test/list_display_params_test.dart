import 'package:bestandsaufnahme_01/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/providers/csv_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

CsvSettings _settings({
  int listTitleInputFieldIndex = 1,
  int listSubtitleInputFieldIndex = 0,
}) {
  return CsvSettings(
    level1: const HierarchyLevelConfig(enabled: true, nameColumn: 0),
    level2: const HierarchyLevelConfig(enabled: true, nameColumn: 1),
    level3: const HierarchyLevelConfig(enabled: false, nameColumn: 2),
    delimiterMode: 'auto',
    anlageKuerzel: 'A,Anlage',
    bauteilKuerzel: 'B,Bauteil',
    useDisciplineGrouping: true,
    labelGewerk: 'Gewerk',
    labelAnlage: 'Anlage',
    labelBauteil: 'Bauteil',
    listTitleInputFieldIndex: listTitleInputFieldIndex,
    listSubtitleInputFieldIndex: listSubtitleInputFieldIndex,
  );
}

void main() {
  final schema = [
    {'key': 'Türnummer', 'label': 'Türnummer', 'type': 'text'},
    {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text'},
    {'key': 'Baujahr', 'label': 'Baujahr', 'type': 'text'},
  ];

  test('Eingabefeld 1 steuert den Listen-Titel', () {
    final csv = _settings(listTitleInputFieldIndex: 1);
    final params = {
      'Türnummer': 'T-12',
      'Hersteller': 'Wilo',
      'Baujahr': '2020',
    };
    expect(
      csv.listTitleValueFromParams(params, schemaFields: schema),
      'T-12',
    );
  });

  test('Eingabefeld 2 als Titel', () {
    final csv = _settings(listTitleInputFieldIndex: 2);
    final params = {
      'Türnummer': 'T-12',
      'Hersteller': 'Wilo',
    };
    expect(
      csv.listTitleValueFromParams(params, schemaFields: schema),
      'Wilo',
    );
  });

  test('Leeres Eingabefeld → Unbekannte Anlage', () {
    final csv = _settings(listTitleInputFieldIndex: 1);
    expect(
      csv.listTitleValueFromParams({}, schemaFields: schema),
      CsvSettings.unknownAnlageListLabel,
    );
    expect(
      csv.listTitleValueFromParams({'Türnummer': ''}, schemaFields: schema),
      CsvSettings.unknownAnlageListLabel,
    );
  });

  test('Untertitel = Eingabefeld 2, 0 = keiner', () {
    final withSub = _settings(listSubtitleInputFieldIndex: 2);
    final params = {
      'Türnummer': 'T-12',
      'Hersteller': 'Wilo',
    };
    expect(
      withSub.listSubtitleValueFromParams(params, schemaFields: schema),
      'Wilo',
    );

    final noSub = _settings(listSubtitleInputFieldIndex: 0);
    expect(
      noSub.listSubtitleValueFromParams(params, schemaFields: schema),
      isNull,
    );
  });

  test('JSON roundtrip Feldindizes', () {
    final csv = _settings(
      listTitleInputFieldIndex: 1,
      listSubtitleInputFieldIndex: 2,
    );
    final restored = CsvSettings.fromJson(csv.toJson());
    expect(restored.listTitleInputFieldIndex, 1);
    expect(restored.listSubtitleInputFieldIndex, 2);
  });
}
