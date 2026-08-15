/// Kleine, gemeinsame CSV-Helfer (Encoding, Delimiter, Zellenlesen).
/// Import/Export und Templates sollen diese Klasse nutzen statt Logik zu kopieren.
import 'dart:convert';

/// Encoding-, Delimiter- und Zellen-Utilities für CSV-Import/-Export.
class CsvUtils {
  /// Entfernt ein UTF-8-BOM am Dateianfang, falls vorhanden.
  static List<int> stripUtf8Bom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  /// Robust: BOM entfernen, UTF-8 bevorzugen, Latin1 Fallback, EOL normalisieren.
  static String normalizeCsvStringFromBytes(List<int> bytes) {
    final cleanBytes = stripUtf8Bom(bytes);

    String csvString;
    try {
      csvString = utf8.decode(cleanBytes, allowMalformed: false);
    } catch (_) {
      // Viele Excel-Exporte sind Latin1/Windows-1252 statt UTF-8.
      csvString = latin1.decode(cleanBytes);
    }

    // Zeilenenden normalisieren (Windows/Mac legacy)
    csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return csvString.trim();
  }

  /// Einfache Delimiter-Heuristik für die erste Zeile.
  static String detectDelimiterFromLine(String line) {
    if (line.contains('\t')) return '\t';
    if (line.contains(',') && !line.contains(';')) return ',';
    return ';';
  }

  /// Sicheres Lesen einer CSV-Zelle (leerer String bei fehlendem Index).
  static String safeCell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString() ?? '';
  }

  /// Wie [safeCell], zusätzlich getrimmt (Gewerkevorlagen-Parser).
  static String safeCellTrimmed(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString().trim();
  }
}
