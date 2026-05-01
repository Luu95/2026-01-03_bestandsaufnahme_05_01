import 'dart:convert';

class CsvUtils {
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
      csvString = latin1.decode(cleanBytes);
    }

    // Zeilenenden normalisieren (Windows/Mac legacy)
    csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return csvString.trim();
  }

  static String detectDelimiterFromLine(String line) {
    if (line.contains('\t')) return '\t';
    if (line.contains(',') && !line.contains(';')) return ',';
    return ';';
  }
}

