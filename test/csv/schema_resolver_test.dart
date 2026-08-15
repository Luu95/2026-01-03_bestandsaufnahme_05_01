import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bestandsaufnahme_01/features/csv/csv_settings.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';
import 'package:bestandsaufnahme_01/features/csv/models/import_attribute_mapping.dart';
import 'package:bestandsaufnahme_01/features/csv/schema/schema_resolver.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';

Disziplin _discipline({
  List<Map<String, dynamic>> schema = const [],
  Map<String, List<Map<String, dynamic>>> ro = const {},
}) {
  return Disziplin(
    label: 'HLKS',
    icon: Icons.ac_unit,
    color: Colors.blue,
    schema: schema.map((e) => Map<String, dynamic>.from(e)).toList(),
    revisionsobjektSchemas: ro.map(
      (k, v) => MapEntry(
        k,
        v.map((e) => Map<String, dynamic>.from(e)).toList(),
      ),
    ),
  );
}

void main() {
  group('AttributeTripletColumn Pair-Dialekt', () {
    test('fromPair / toPair Roundtrip', () {
      const pair = AttributeColumnPair(
        nameColumn: 4,
        valueColumn: 5,
        attNumber: 2,
      );
      final t = AttributeTripletColumn.fromPair(pair);
      expect(t.isPairDialect, isTrue);
      expect(t.typeColumn, -1);
      expect(t.toPair().nameColumn, 4);
      expect(t.toPair().valueColumn, 5);
      expect(t.columnIndices, [4, 5]);
    });
  });

  group('CsvSettings.canonicalizeAttributeMapping', () {
    test('Pairs werden zu Triplets normalisiert', () {
      final settings = CsvSettings.defaults().copyWith(
        attributeColumnPairs: const [
          AttributeColumnPair(nameColumn: 2, valueColumn: 3, attNumber: 1),
        ],
      );
      final canon = CsvSettings.canonicalizeAttributeMapping(settings);
      expect(canon.attributeColumnPairs, isEmpty);
      expect(canon.attributeTripletColumns, hasLength(1));
      expect(canon.attributeTripletColumns.first.isPairDialect, isTrue);
      expect(canon.effectiveAttributePairs, hasLength(1));
    });

    test('fromJson kanonisiert Pair-JSON', () {
      final json = CsvSettings.defaults()
          .copyWith(
            attributeColumnPairs: const [
              AttributeColumnPair(nameColumn: 1, valueColumn: 2),
            ],
          )
          .toJson();
      // Simuliere altes Prefs-JSON nur mit pairs.
      json['attributeColumnPairs'] = [
        {'nameColumn': 1, 'valueColumn': 2, 'attNumber': 1},
      ];
      json['attributeTripletColumns'] = [];
      final loaded = CsvSettings.fromJson(json);
      expect(loaded.attributeColumnPairs, isEmpty);
      expect(loaded.canonicalAttributeTriplets.first.isPairDialect, isTrue);
    });
  });

  group('resolveImportAttributeMapping', () {
    test('Anlagen-Header → Pair-Dialekt mit Triplets', () {
      final mapping = CsvSettings.resolveImportAttributeMapping(
        headerRow: const ['ATT1', 'ATT1_WERT', 'ATT2', 'ATT2_WERT'],
        settings: CsvSettings.defaults(),
      );
      expect(mapping.isPair, isTrue);
      expect(mapping.triplets, isNotEmpty);
      expect(mapping.pairs, isNotEmpty);
      expect(mapping.dialect, AttributeDialect.anlagenPair);
    });
  });

  group('SchemaResolver', () {
    test('RO-Map gewinnt', () {
      final d = _discipline(
        schema: [
          {'key': 'Global', 'label': 'Global', 'type': 'text', 'isGlobal': true},
          {'key': 'Alt', 'label': 'Alt', 'type': 'text'},
        ],
        ro: {
          'Pumpe': [
            {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text'},
          ],
        },
      );
      final result = SchemaResolver.resolve(
        SchemaResolveInput(
          discipline: d,
          revisionsobjekt: 'Pumpe',
          allowLastResortInference: true,
        ),
      );
      expect(result.source, SchemaResolveSource.roMap);
      expect(result.fields.any((f) => f.key == 'Hersteller'), isTrue);
      expect(result.fields.any((f) => f.key == 'Alt'), isFalse);
    });

    test('Flat-Legacy wird nach RO promotet', () {
      final d = _discipline(
        schema: [
          {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text'},
        ],
      );
      final result = SchemaResolver.resolve(
        SchemaResolveInput(
          discipline: d,
          revisionsobjekt: 'Pumpe',
          allowLastResortInference: false,
        ),
      );
      expect(result.source, SchemaResolveSource.legacyFlat);
      expect(result.promotedDiscipline, isNotNull);
      expect(
        result.promotedDiscipline!.revisionsobjektSchemas.containsKey('Pumpe'),
        isTrue,
      );
      expect(result.fields.any((f) => f.key == 'Hersteller'), isTrue);
    });

    test('__csvRowCells greifen nicht, wenn RO-Schema schon Felder hat', () {
      final d = _discipline(
        ro: {
          'Pumpe': [
            {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text'},
          ],
        },
      );
      final result = SchemaResolver.resolve(
        SchemaResolveInput(
          discipline: d,
          revisionsobjekt: 'Pumpe',
          params: {
            CsvSettings.csvRowCellsParamKey: {
              'ATT1': 'Typ',
              'ATT1_WERT': 'X',
            },
          },
          importHeaders: const ['ATT1', 'ATT1_WERT'],
          allowLastResortInference: true,
        ),
      );
      expect(result.source, SchemaResolveSource.roMap);
      expect(result.fields.any((f) => f.key == 'Hersteller'), isTrue);
      expect(result.fields.any((f) => f.key == 'Typ'), isFalse);
    });

    test('Params-Inference nur als Last-Resort', () {
      final d = _discipline();
      final result = SchemaResolver.resolve(
        SchemaResolveInput(
          discipline: d,
          revisionsobjekt: 'Pumpe',
          params: {
            'Hersteller': 'Wilo',
            'Baujahr': '2020',
          },
          allowLastResortInference: true,
        ),
      );
      expect(
        result.source == SchemaResolveSource.paramsInference ||
            result.source == SchemaResolveSource.csvRowCells,
        isTrue,
      );
      expect(result.fields.any((f) => !f.isGlobal), isTrue);
    });
  });
}
