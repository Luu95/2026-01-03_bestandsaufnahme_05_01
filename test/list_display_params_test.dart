import 'package:bestandsaufnahme_01/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/providers/csv_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

CsvSettings _settings({
  String displayNameParamKey = 'Name',
  String listSubtitleParamKey = 'Hersteller',
  String labelAnlage = 'Anlage',
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
    labelAnlage: labelAnlage,
    labelBauteil: 'Bauteil',
    displayNameParamKey: displayNameParamKey,
    listSubtitleParamKey: listSubtitleParamKey,
  );
}

void main() {
  test('Platzhalter-Ebenen-Label blockiert nicht den echten Anzeigenamen', () {
    final csv = _settings();
    final params = <String, dynamic>{
      'Name': 'Anlage',
      'Anlagenbezeichnung': 'Pumpe 1',
    };

    expect(csv.isPlaceholderDisplayValue('Anlage'), isTrue);
    expect(csv.displayNameValueFromParams(params), 'Pumpe 1');
  });

  test('Revisionsobjekt als Name wird als nicht-eigenständig erkannt', () {
    final csv = _settings(
      labelAnlage: 'Revisionsobjekt',
    ).copyWith(
      groupingAnlageParamKey: 'Revisionsobjekt',
    );
    // Simulate schema/RO value in params via hierarchy level 2 header
    final params = <String, dynamic>{
      'Revisionsobjekt':
          'Brandschutztüren, -tore, rauchdichte Türen u. Tore',
      'Name': 'Brandschutztüren, -tore, rauchdichte Türen u. Tore',
      'Bezeichnung': 'Tür T-12',
    };

    expect(
      csv.isNonDistinctDisplayValue(params['Name']?.toString(), params),
      isTrue,
    );
    expect(csv.displayNameValueFromParams(params), 'Tür T-12');
  });

  test('clearPlaceholderDisplayNameFromParams entfernt RO-Duplikat', () {
    final csv = _settings();
    final params = <String, dynamic>{
      'Revisionsobjekt': 'Brandschutztüren',
      'Name': 'Brandschutztüren',
    };
    // Ensure schema/RO resolution finds Revisionsobjekt
    final withGrouping = csv.copyWith(groupingAnlageParamKey: 'Revisionsobjekt');
    withGrouping.clearPlaceholderDisplayNameFromParams(params);
    expect(params['Name'], '');
  });

  test('writeDisplayNameToParams schreibt keine Platzhalter', () {
    final csv = _settings();
    final params = <String, dynamic>{};
    csv.writeDisplayNameToParams(params, 'Anlage');
    expect(params.containsKey('Name'), isFalse);

    csv.writeDisplayNameToParams(params, 'Pumpe 1');
    expect(params['Name'], 'Pumpe 1');
  });

  test('listSubtitleValueFromParams nutzt konfigurierten Key', () {
    final csv = _settings(listSubtitleParamKey: 'Fabrikat');
    expect(
      csv.listSubtitleValueFromParams({'Fabrikat': 'Wilo', 'Hersteller': 'X'}),
      'Wilo',
    );
    expect(csv.listSubtitleValueFromParams({'Hersteller': 'X'}), isNull);

    final emptySub = _settings(listSubtitleParamKey: '');
    expect(emptySub.listSubtitleValueFromParams({'Hersteller': 'X'}), isNull);
  });

  test('JSON roundtrip behält listSubtitleParamKey', () {
    final csv = _settings(listSubtitleParamKey: 'Typ');
    final restored = CsvSettings.fromJson(csv.toJson());
    expect(restored.listSubtitleParamKey, 'Typ');
    expect(restored.displayNameParamKey, 'Name');
  });
}
