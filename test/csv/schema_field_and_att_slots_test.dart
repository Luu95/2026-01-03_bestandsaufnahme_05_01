import 'package:flutter_test/flutter_test.dart';

import 'package:bestandsaufnahme_01/features/csv/csv_settings.dart';
import 'package:bestandsaufnahme_01/features/csv/models/schema_field.dart';

void main() {
  group('SchemaField', () {
    test('roundtrip map ↔ model', () {
      final map = {
        'key': 'Hersteller',
        'label': 'Hersteller',
        'type': 'text',
        'attSlot': 2,
        'art': 'Allgemein',
        'options': ['a', 'b'],
      };
      final field = SchemaField.fromMap(map);
      expect(field.key, 'Hersteller');
      expect(field.attSlot, 2);
      expect(field.options, ['a', 'b']);
      final back = field.toMap();
      expect(back['key'], 'Hersteller');
      expect(back['attSlot'], 2);
      expect(back['options'], ['a', 'b']);
    });
  });

  group('AnlageAttSlots', () {
    test('looksLikeTypeOrOptionsDefinition erkennt Tokens und Pipes', () {
      expect(CsvSettings.looksLikeTypeOrOptionsDefinition('text'), isTrue);
      expect(CsvSettings.looksLikeTypeOrOptionsDefinition('A|B|C'), isTrue);
      expect(CsvSettings.looksLikeTypeOrOptionsDefinition('Siemens'), isFalse);
    });

    test('ensureAttSlotsForDialog setzt Slot aus Schema', () {
      final params = <String, dynamic>{
        'Hersteller': 'Wilo',
      };
      final schema = [
        {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text', 'attSlot': 1},
      ];
      CsvSettings.ensureAttSlotsForDialog(
        params: params,
        schemaFields: schema,
      );
      expect(params['Hersteller'], 'Wilo');
      expect(CsvSettings.attSlotForParam(params, 'Hersteller'), 1);
    });

    test('effectiveSchemaArtGroup ignoriert Typ-Tokens', () {
      expect(
        CsvSettings.effectiveSchemaArtGroup({
          'key': 'Hersteller',
          'label': 'Hersteller',
          'art': 'Allgemein',
        }),
        'Allgemein',
      );
      expect(
        CsvSettings.effectiveSchemaArtGroup({
          'key': 'Hersteller',
          'label': 'Hersteller',
          'art': 'text',
        }),
        isNull,
      );
    });
  });
}
