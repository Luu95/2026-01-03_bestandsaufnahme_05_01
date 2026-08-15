// Charakterisierungstests für CSV-Mapping, Legacy-JSON und Listen-Titel.
//
// Zweck: Refactor/Legacy-Kill ohne stille Regressionen.
// Einstieg: resolveImportAttributeMapping, fromJson, listTitle vs displayName.

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/csv/models/import_attribute_mapping.dart';
import 'package:bestandsaufnahme_01/features/csv/utils/csv_column_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CsvSettings _baseSettings({
  List<String> importHeaderRow = const [],
  List<AttributeColumnPair> pairs = const [],
  List<AttributeTripletColumn> triplets = const [],
  int? attributeStartColumn,
  int? attributeCount,
  String displayNameParamKey = 'Name',
  int listTitleInputFieldIndex = 1,
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
    importHeaderRow: importHeaderRow,
    attributeColumnPairs: pairs,
    attributeTripletColumns: triplets,
    attributeStartColumn: attributeStartColumn,
    attributeCount: attributeCount,
    displayNameParamKey: displayNameParamKey,
    listTitleInputFieldIndex: listTitleInputFieldIndex,
  );
}

void main() {
  group('resolveImportAttributeMapping', () {
    test('erkennt Anlagen-Pair-Header (ATT + ATT_WERT)', () {
      final header = [
        'Gewerk',
        'Anlage',
        'ATT1',
        'ATT1_WERT',
        'ATT2',
        'ATT2_WERT',
      ];
      final mapping = CsvSettings.resolveImportAttributeMapping(
        headerRow: header,
        settings: _baseSettings(),
      );
      expect(mapping.pairs, isNotEmpty);
      expect(mapping.pairs.length, 2);
      expect(mapping.triplets, isNotEmpty);
      expect(mapping.triplets.every((t) => t.isPairDialect), isTrue);
      expect(mapping.isPair, isTrue);
      expect(mapping.isTriplet, isFalse);
      expect(mapping.isEmpty, isFalse);
      expect(mapping.dialect, AttributeDialect.anlagenPair);
    });

    test('erkennt Gewerke-Triplet-Header (ATT + TYPE + ART)', () {
      // ART statt WERT: sonst greift zuerst das Anlagen-Pair-Format (_WERT).
      final header = [
        'Gewerk',
        'Anlage',
        'ATT1',
        'ATT1_TYPE',
        'ATT1_ART',
        'ATT2',
        'ATT2_TYPE',
        'ATT2_ART',
      ];
      final mapping = CsvSettings.resolveImportAttributeMapping(
        headerRow: header,
        settings: _baseSettings(),
      );
      expect(mapping.triplets, isNotEmpty);
      expect(mapping.triplets.length, 2);
      expect(mapping.pairs, isEmpty);
      expect(mapping.isTriplet, isTrue);
      expect(mapping.isPair, isFalse);
    });

    test('manuelle Range ohne ATT-Header liefert Triplets', () {
      final settings = _baseSettings(
        attributeStartColumn: 3,
        attributeCount: 2,
      );
      expect(settings.hasManualAttributeRange, isTrue);
      final mapping = CsvSettings.resolveImportAttributeMapping(
        headerRow: const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'],
        settings: settings,
      );
      // Ohne ATT-Erkennung: manuelle Range (Triplet-Dialekt).
      expect(mapping.triplets.length, 2);
      expect(mapping.pairs, isEmpty);
    });
  });

  group('CsvSettings.fromJson', () {
    test('neues JSON mit level1/2/3', () {
      final settings = CsvSettings.fromJson({
        'level1': {'enabled': true, 'nameColumn': 0},
        'level2': {'enabled': true, 'nameColumn': 1},
        'level3': {'enabled': true, 'nameColumn': 2},
        'delimiterMode': 'auto',
        'anlageKuerzel': 'A',
        'bauteilKuerzel': 'B',
        'useDisciplineGrouping': true,
        'labelGewerk': 'Gewerk',
        'labelAnlage': 'Anlage',
        'labelBauteil': 'Bauteil',
        'listTitleInputFieldIndex': 2,
      });
      expect(settings.level1.nameColumn, 0);
      expect(settings.level2.nameColumn, 1);
      expect(settings.level3.nameColumn, 2);
      expect(settings.listTitleInputFieldIndex, 2);
    });

    test('Legacy-JSON gewerkSpalte/nameSpalte → level1/level3', () {
      final settings = CsvSettings.fromJson({
        'gewerkSpalte': 2,
        'nameSpalte': 1,
        'lfdNummerSpalte': 0,
        'useDisciplineGrouping': true,
        'delimiterMode': 'auto',
        'anlageKuerzel': 'A',
        'bauteilKuerzel': 'B',
        'labelGewerk': 'Gewerk',
        'labelAnlage': 'Anlage',
        'labelBauteil': 'Bauteil',
      });
      expect(settings.level1.nameColumn, 2);
      expect(settings.level1.enabled, isTrue);
      expect(settings.level3.nameColumn, 1);
      expect(settings.level3.useIdColumn, isTrue);
      expect(settings.level3.idColumn, 0);
    });
  });

  group('Listen-Titel vs displayNameParamKey', () {
    test('listTitleInputFieldIndex liefert Titel aus Schema-Feld', () {
      final csv = _baseSettings(
        displayNameParamKey: 'AndererKey',
        listTitleInputFieldIndex: 1,
      );
      final schema = [
        {'key': 'Türnummer', 'label': 'Türnummer', 'type': 'text', 'attSlot': 1},
        {'key': 'Hersteller', 'label': 'Hersteller', 'type': 'text', 'attSlot': 2},
      ];
      expect(
        csv.listTitleValueFromParams(
          {'Türnummer': 'T-12', 'AndererKey': 'Ignorieren'},
          schemaFields: schema,
        ),
        'T-12',
      );
    });

    test('gespeicherter __listTitle hat Vorrang vor displayNameParamKey', () {
      final csv = _baseSettings(displayNameParamKey: 'Türnummer');
      expect(
        csv.listTitleValueFromParams({
          CsvSettings.listTitleParamKey: 'Gespeichert',
          'Türnummer': 'T-01',
        }),
        'Gespeichert',
      );
    });
  });

  group('Export Roundtrip', () {
    test('Import-Header-Export erhält __csvRowCells 1:1', () {
      final header = ['Gewerk', 'Anlage', 'ATT1', 'ATT1_WERT'];
      final csv = _baseSettings(importHeaderRow: header);
      final discipline = Disziplin(
        label: 'Test',
        icon: Icons.ac_unit,
        color: Colors.blue,
        schema: const [],
      );
      final anlage = Anlage(
        id: 'a1',
        name: 'A-1',
        params: {
          CsvSettings.csvRowCellsParamKey: {
            'Gewerk': 'HLK',
            'Anlage': 'Pumpe',
            'ATT1': 'Hersteller',
            'ATT1_WERT': 'Wilo',
          },
          'Hersteller': 'Wilo',
        },
        floorId: 'f1',
        buildingId: 'b1',
        isMarker: false,
        markerType: '',
        discipline: discipline,
      );

      final row = buildAnlageExportRow(
        anlage: anlage,
        csvSettings: csv,
        discipline: discipline,
      );
      expect(row.length, header.length);
      // Hierarchie-Spalten werden aus Params/Disziplin overlayed; ATT-Zellen 1:1.
      expect(row[2], 'Hersteller');
      expect(row[3], 'Wilo');
      expect(row[0], isNotEmpty);
      expect(row[1], isNotEmpty);
    });
  });
}
