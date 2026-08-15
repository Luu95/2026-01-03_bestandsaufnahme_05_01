/// Top-level CSV-Parser für Isolate/[compute] (nur sendable Argumente).
/// Parsed CSV-Text mit konfigurierbarem Delimiter ohne Zahlen-Autokonvertierung.
import 'package:csv/csv.dart';

/// Parst CSV-Zeilen in einem Isolate; [args] enthält `csv` und optional `delimiter`.
List<List<dynamic>> parseCsvRowsIsolate(Map<String, String> args) {
  final csvString = args['csv'] ?? '';
  final delimiter = args['delimiter'] ?? ';';
  return CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csvString);
}
