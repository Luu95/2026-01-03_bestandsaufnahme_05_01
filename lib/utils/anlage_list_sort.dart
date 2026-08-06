/// Sortierhilfen für die Anlagen-Übersicht (Gruppen-/Untergruppen-Keys).
///
/// Die Anlagen selbst werden derzeit nicht nach Name sortiert – ihre
/// Reihenfolge bleibt DB-/Import-Reihenfolge.
library;

/// Comparator für Gruppen- bzw. Untergruppen-Keys.
///
/// Leere Keys kommen zuletzt. Vergleich ist case-sensitiv und lexikalisch
/// (kein Natural Sort, keine Locale).
int compareGroupKeys(String a, String b) {
  if (a.isEmpty) return 1;
  if (b.isEmpty) return -1;
  return a.compareTo(b);
}

/// Gruppenwert aus einem Parameter – aktuell **ohne** Trim (wie in
/// [SystemsAnlageList] beim Haupt-Grouping). Whitespace-only wird damit
/// nicht als „leer“ behandelt.
String groupingValueFromParam(dynamic raw) => raw?.toString() ?? '';

/// Untergruppenwert – mit Trim (wie `_resolveSubGroupValue`).
String subGroupingValueFromParam(dynamic raw) =>
    raw?.toString().trim() ?? '';

/// Sortiert Keys mit [compareGroupKeys] (leerer String zuletzt).
List<String> orderGroupKeys(Iterable<String> keys) {
  final list = keys.toList();
  list.sort(compareGroupKeys);
  return list;
}

/// Verbesserter Comparator (Vorschlag): Trim, case-insensitive, leere zuletzt,
/// bei Gleichheit stabiler Fall-back auf Original.
///
/// Noch nicht in der UI verdrahtet – dient Tests/Review.
int compareGroupKeysImproved(String a, String b) {
  final ta = a.trim();
  final tb = b.trim();
  final aEmpty = ta.isEmpty;
  final bEmpty = tb.isEmpty;
  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return 1;
  if (bEmpty) return -1;
  final byLower = ta.toLowerCase().compareTo(tb.toLowerCase());
  if (byLower != 0) return byLower;
  return ta.compareTo(tb);
}
