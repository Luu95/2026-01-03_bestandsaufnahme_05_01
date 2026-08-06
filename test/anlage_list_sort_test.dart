import 'package:bestandsaufnahme_01/utils/anlage_list_sort.dart';
import 'package:bestandsaufnahme_01/utils/csv_column_layout.dart';
import 'package:bestandsaufnahme_01/providers/csv_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareGroupKeys (aktuelles UI-Verhalten)', () {
    test('leerer Key kommt nach nicht-leeren Keys', () {
      expect(orderGroupKeys(['', 'B', 'A']), ['A', 'B', '']);
    });

    test('lexikalische Reihenfolge, case-sensitiv (ASCII)', () {
      // Großbuchstaben vor Kleinbuchstaben (Unicode/ASCII)
      expect(orderGroupKeys(['beta', 'Alpha', 'alpha']), [
        'Alpha',
        'alpha',
        'beta',
      ]);
    });

    test('kein Natural Sort: "10" vor "2"', () {
      expect(orderGroupKeys(['2', '10', '1']), ['1', '10', '2']);
    });

    test('BUG: beide Keys leer → Comparator liefert 1 statt 0', () {
      // Verletzt die Comparator-Konvention (a==b ⇒ 0) und kann Sort
      // theoretisch instabil machen.
      expect(compareGroupKeys('', ''), 1);
    });

    test('Umlaute: keine deutsche Locale-Collation', () {
      // Lexikalisch nach Codepoint: A < Z < a < ä (kein de_DE)
      final ordered = orderGroupKeys(['Öfen', 'Zimmer', 'Anlage', 'äpfel']);
      expect(ordered, ['Anlage', 'Zimmer', 'Öfen', 'äpfel']);
    });
  });

  group('Grouping-Wert-Inkonsistenz Trim', () {
    test('Haupt-Grouping trimmt nicht → "FOO " und "FOO" sind verschiedene Gruppen',
        () {
      final keys = <String>{};
      for (final raw in ['FOO', 'FOO ', ' FOO']) {
        keys.add(groupingValueFromParam(raw));
      }
      expect(keys.length, 3);
      expect(orderGroupKeys(keys), [' FOO', 'FOO', 'FOO ']);
    });

    test('Untergruppen-Pfad trimmt → dieselben Werte fallen zusammen', () {
      final keys = <String>{};
      for (final raw in ['FOO', 'FOO ', ' FOO']) {
        keys.add(subGroupingValueFromParam(raw));
      }
      expect(keys, {'FOO'});
    });

    test('Whitespace-only ist beim Haupt-Grouping nicht leer', () {
      final v = groupingValueFromParam('   ');
      expect(v.isEmpty, isFalse);
      // compareGroupKeys behandelt nur '' als leer → "   " sortiert mittenrein
      expect(compareGroupKeys(v, 'A') < 0 || compareGroupKeys(v, 'A') > 0, isTrue);
      expect(orderGroupKeys(['B', v, 'A']), ['   ', 'A', 'B']);
    });
  });

  group('Anlagen-Reihenfolge (kein Namens-Sort in der Liste)', () {
    test('Eltern-Liste behält Einfügereihenfolge (Simulation _rebuildAnlagenIndexes)',
        () {
      // Spiegeln der Logik: roots = Filter-Reihenfolge, kein .sort nach name
      final idsInDbOrder = ['z-1', 'a-2', 'm-3'];
      final roots = List<String>.from(idsInDbOrder);
      expect(roots, ['z-1', 'a-2', 'm-3']);
      // Alphabetisch wäre a, m, z – wird bewusst nicht angewendet:
      final alpha = List<String>.from(idsInDbOrder)..sort();
      expect(alpha, ['a-2', 'm-3', 'z-1']);
      expect(roots, isNot(alpha));
    });

    test('Kinder innerhalb Parent behalten Einfügereihenfolge', () {
      final childrenByParent = <String, List<String>>{};
      for (final id in ['child-10', 'child-2', 'child-1']) {
        childrenByParent.putIfAbsent('p', () => []).add(id);
      }
      expect(childrenByParent['p'], ['child-10', 'child-2', 'child-1']);
    });
  });

  group('CSV-Export-Sortierung (Zeilenindex)', () {
    test('compareAnlagenCsvRowIndex sortiert numerisch', () {
      final a = {CsvSettings.csvRowIndexParamKey: 10};
      final b = {CsvSettings.csvRowIndexParamKey: 2};
      final c = {CsvSettings.csvRowIndexParamKey: '3'};
      expect(compareAnlagenCsvRowIndex(b, a), lessThan(0));
      expect(compareAnlagenCsvRowIndex(c, a), lessThan(0));
      expect(compareAnlagenCsvRowIndex(b, c), lessThan(0));
    });

    test('fehlender Index wird von csvRowIndexFromParams als 0 gelesen', () {
      expect(csvRowIndexFromParams({}), 0);
      expect(csvRowIndexFromParams({CsvSettings.csvRowIndexParamKey: 'x'}), 0);
    });
  });

  group('compareGroupKeysImproved (Vorschlag)', () {
    test('beide leer → 0', () {
      expect(compareGroupKeysImproved('', ''), 0);
      expect(compareGroupKeysImproved('  ', '\t'), 0);
    });

    test('case-insensitive + Trim', () {
      expect(
        orderWith(compareGroupKeysImproved, ['beta', 'Alpha', 'alpha ', '']),
        ['Alpha', 'alpha ', 'beta', ''],
      );
    });

    test('Whitespace-only wie leer (zuletzt)', () {
      expect(
        orderWith(compareGroupKeysImproved, ['B', '   ', 'A']),
        ['A', 'B', '   '],
      );
    });
  });
}

List<String> orderWith(int Function(String, String) cmp, List<String> keys) {
  final list = List<String>.from(keys);
  list.sort(cmp);
  return list;
}
