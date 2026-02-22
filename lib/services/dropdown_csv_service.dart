import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DropdownCsvData {
  final String? path;
  final List<String> headers;
  final Map<String, List<String>> valuesByHeader;
  final String? error;

  const DropdownCsvData({
    required this.path,
    required this.headers,
    required this.valuesByHeader,
    required this.error,
  });

  bool get isAvailable => path != null && headers.isNotEmpty && error == null;
}

class DropdownCsvService {
  static String prefsKeyForBuilding(String buildingId) => 'dropdown_values_csv_$buildingId';
  static String prefsKeyValuesForBuilding(String buildingId) => 'dropdown_values_$buildingId';

  static List<String> _dedupSorted(List<String> values) {
    final set = <String>{};
    for (final v in values) {
      final t = v.toString().trim();
      if (t.isEmpty) continue;
      set.add(t);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<Map<String, List<String>>> loadSavedValuesForBuilding(String buildingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKeyValuesForBuilding(buildingId));
      if (raw == null || raw.trim().isEmpty) return <String, List<String>>{};
      final decoded = json.decode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      final map = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final k = entry.key.toString().trim();
        if (k.isEmpty) continue;
        final v = entry.value;
        if (v is List) {
          map[k] = _dedupSorted(v.map((e) => e.toString()).toList());
        }
      }
      return map;
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static Future<void> saveValuesForBuilding(String buildingId, Map<String, List<String>> valuesByHeader) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefsKeyValuesForBuilding(buildingId);
    final encoded = <String, dynamic>{};
    for (final entry in valuesByHeader.entries) {
      final header = entry.key.toString().trim();
      if (header.isEmpty) continue;
      encoded[header] = _dedupSorted(entry.value);
    }
    await prefs.setString(key, json.encode(encoded));
  }

  static Future<void> clearValuesForBuilding(String buildingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyValuesForBuilding(buildingId));
  }

  static Future<DropdownCsvData> loadForBuilding(String buildingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKeyForBuilding(buildingId));
      if (raw == null || raw.trim().isEmpty) {
        return const DropdownCsvData(
          path: null,
          headers: <String>[],
          valuesByHeader: <String, List<String>>{},
          error: null,
        );
      }

      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return const DropdownCsvData(
          path: null,
          headers: <String>[],
          valuesByHeader: <String, List<String>>{},
          error: 'Ungültige Dropdown-CSV-Konfiguration',
        );
      }

      final pathValue = decoded['path']?.toString();
      final configuredHeaders = (decoded['headers'] is List)
          ? (decoded['headers'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const <String>[];

      if (pathValue == null || pathValue.trim().isEmpty) {
        return const DropdownCsvData(
          path: null,
          headers: <String>[],
          valuesByHeader: <String, List<String>>{},
          error: null,
        );
      }

      final file = File(pathValue);
      if (!await file.exists()) {
        return DropdownCsvData(
          path: pathValue,
          headers: configuredHeaders,
          valuesByHeader: const <String, List<String>>{},
          error: 'Dropdown-CSV nicht gefunden: $pathValue',
        );
      }

      final bytes = await file.readAsBytes();
      String csvString;
      try {
        csvString = utf8.decode(bytes);
      } catch (_) {
        csvString = latin1.decode(bytes);
      }
      csvString = csvString.trim();
      if (csvString.isEmpty) {
        return DropdownCsvData(
          path: pathValue,
          headers: const <String>[],
          valuesByHeader: const <String, List<String>>{},
          error: 'Dropdown-CSV ist leer',
        );
      }

      final firstLine = csvString.split('\n').first;
      final delimiter = _detectDelimiter(firstLine);
      final rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) {
        return DropdownCsvData(
          path: pathValue,
          headers: const <String>[],
          valuesByHeader: const <String, List<String>>{},
          error: 'Keine Zeilen in Dropdown-CSV erkannt',
        );
      }

      final headerRow = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.length > 1 ? rows.sublist(1) : const <List<dynamic>>[];

      final valuesByHeader = <String, List<String>>{};
      for (var col = 0; col < headerRow.length; col++) {
        final header = headerRow[col];
        if (header.isEmpty) continue;
        final set = <String>{};
        for (final row in dataRows) {
          if (col >= row.length) continue;
          final v = row[col]?.toString().trim() ?? '';
          if (v.isEmpty) continue;
          set.add(v);
        }
        valuesByHeader[header] = _dedupSorted(set.toList());
      }

      final savedValues = await loadSavedValuesForBuilding(buildingId);
      for (final entry in savedValues.entries) {
        valuesByHeader[entry.key] = _dedupSorted(entry.value);
      }

      // Header-Liste: bevorzugt konfigurierte Headers (inkl. Custom), sonst aus Datei.
      final headers = (configuredHeaders.isNotEmpty
              ? configuredHeaders
              : headerRow.where((h) => h.trim().isNotEmpty).toList())
          .toList();

      // Stelle sicher, dass alle gespeicherten Custom-Dropdowns auch in der Header-Liste auftauchen.
      for (final k in savedValues.keys) {
        if (!headers.contains(k)) headers.add(k);
      }

      return DropdownCsvData(
        path: pathValue,
        headers: headers,
        valuesByHeader: valuesByHeader,
        error: null,
      );
    } catch (e) {
      return DropdownCsvData(
        path: null,
        headers: const <String>[],
        valuesByHeader: const <String, List<String>>{},
        error: e.toString(),
      );
    }
  }

  static String _detectDelimiter(String line) {
    if (line.contains('\t')) return '\t';
    if (line.contains(',') && !line.contains(';')) return ',';
    return ';';
  }
}
