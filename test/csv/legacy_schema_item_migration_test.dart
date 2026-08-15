import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrateLegacySchemaItemKeys kopiert Revisionsobjekt auf Level-Key', () {
    final csv = CsvSettings(
      level1: const HierarchyLevelConfig(enabled: true, nameColumn: 0),
      level2: const HierarchyLevelConfig(enabled: true, nameColumn: 1),
      level3: const HierarchyLevelConfig(enabled: false, nameColumn: 2),
      delimiterMode: 'auto',
      anlageKuerzel: 'A',
      bauteilKuerzel: 'B',
      useDisciplineGrouping: true,
      labelGewerk: 'Gewerk',
      labelAnlage: 'Anlage',
      labelBauteil: 'Bauteil',
      importHeaderRow: const ['Gewerk', 'Anlagentyp', 'Name'],
    );
    final target = csv.resolveSchemaItemParamKey();
    expect(target, isNotNull);

    final params = <String, dynamic>{
      'Revisionsobjekt': 'Brandschutztür',
      'Türnummer': 'T-1',
    };
    csv.migrateLegacySchemaItemKeys(params);

    expect(params[target], 'Brandschutztür');
    expect(params.containsKey('Revisionsobjekt'), isFalse);
    expect(params['Türnummer'], 'T-1');
  });
}
