import 'package:flutter_test/flutter_test.dart';

import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';
import 'package:bestandsaufnahme_01/features/csv/schema/schema_fields_from_row.dart';

void main() {
  const headers = ['ATT1', 'ATT1_TYPE', 'ATT1_ART'];
  const triplets = [
    AttributeTripletColumn(
      nameColumn: 0,
      typeColumn: 1,
      artColumn: 2,
    ),
  ];

  test('Gewerke-Triplet behält art als Gruppe', () {
    final fields = schemaFieldsFromGewerkeTripletRow(
      row: ['Hersteller', 'text', 'Allgemein'],
      headerRow: headers,
      triplets: triplets,
    );
    expect(fields, hasLength(1));
    expect(fields.first['key'], 'Hersteller');
    expect(fields.first['art'], 'Allgemein');
    expect(fields.first['type'], 'text');
  });

  test('Anlagen-Triplet speichert art nicht als Schema-Gruppe', () {
    final fields = schemaFieldsFromAnlagenTripletRow(
      row: ['Hersteller', 'text', 'Siemens'],
      headerRow: headers,
      triplets: triplets,
    );
    expect(fields, hasLength(1));
    expect(fields.first['key'], 'Hersteller');
    expect(fields.first.containsKey('art'), isFalse);
  });
}
