import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

CsvSettings _settings({int titleField = 1, int subtitleField = 0}) {
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
    listTitleInputFieldIndex: titleField,
    listSubtitleInputFieldIndex: subtitleField,
  );
}

void main() {
  final schema = [
    {'key': 'Türnummer', 'label': 'Türnummer', 'type': 'text', 'attSlot': 1},
    {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text', 'attSlot': 2},
  ];

  test('gespeicherter __listTitle hat Vorrang', () {
    final csv = _settings();
    final params = {
      CsvSettings.listTitleParamKey: 'Gespeichert T-99',
      'Türnummer': 'T-01',
    };
    expect(
      csv.listTitleValueFromParams(params, schemaFields: schema),
      'Gespeichert T-99',
    );
  });

  test('Eingabefeld 1 über attSlot', () {
    final csv = _settings(titleField: 1);
    expect(
      csv.listTitleValueFromParams(
        {'Türnummer': 'T-12', 'Hersteller': 'Wilo'},
        schemaFields: schema,
      ),
      'T-12',
    );
  });

  test('Eingabefeld 1 über Positionsindex ohne attSlot', () {
    final csv = _settings(titleField: 1);
    final schemaNoSlot = [
      {'key': 'FeldA', 'label': 'FeldA', 'type': 'text'},
      {'key': 'FeldB', 'label': 'FeldB', 'type': 'text'},
    ];
    expect(
      csv.listTitleValueFromParams(
        {'FeldA': 'Alpha', 'FeldB': 'Beta'},
        schemaFields: schemaNoSlot,
      ),
      'Alpha',
    );
  });

  test('leeres Feld → Unbekannte Anlage', () {
    final csv = _settings();
    expect(
      csv.listTitleValueFromParams({}, schemaFields: schema),
      CsvSettings.unknownAnlageListLabel,
    );
  });

  test('ATT-Slot in Params ohne Schema', () {
    final csv = _settings(titleField: 1);
    final params = <String, dynamic>{
      'MeineTür': 'T-55',
      CsvSettings.attSlotParamKey('MeineTür'): 1,
    };
    expect(csv.listTitleValueFromParams(params), 'T-55');
  });

  test('clearPlaceholder löscht keinen RO-gleichen Nutzerwert', () {
    final csv = _settings().copyWith(displayNameParamKey: 'Türnummer');
    final params = <String, dynamic>{
      'Türnummer': 'Brandschutztür',
      'Revisionsobjekt': 'Brandschutztür',
    };
    csv.clearPlaceholderDisplayNameFromParams(params);
    expect(params['Türnummer'], 'Brandschutztür');
  });

  test('clearPlaceholder löscht echtes Platzhalter-Label', () {
    final csv = _settings().copyWith(displayNameParamKey: 'Türnummer');
    final params = <String, dynamic>{'Türnummer': 'Eintrag'};
    csv.clearPlaceholderDisplayNameFromParams(params);
    expect(params['Türnummer'], '');
  });

  test('__listTitle wird in leeres Eingabefeld 1 zurückgeschrieben', () {
    final csv = _settings(titleField: 1);
    final params = <String, dynamic>{
      CsvSettings.listTitleParamKey: 'T-99',
      'Türnummer': '',
      'Hersteller': 'Wilo',
    };
    csv.restoreListTitleIntoInputField(params, schemaFields: schema);
    expect(params['Türnummer'], 'T-99');
  });

  test('restore überschreibt befülltes Feld nicht', () {
    final csv = _settings(titleField: 1);
    final params = <String, dynamic>{
      CsvSettings.listTitleParamKey: 'Alt',
      'Türnummer': 'Neu',
    };
    csv.restoreListTitleIntoInputField(params, schemaFields: schema);
    expect(params['Türnummer'], 'Neu');
  });
}
