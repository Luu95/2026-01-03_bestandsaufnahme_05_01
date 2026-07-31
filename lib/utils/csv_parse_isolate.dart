import 'package:csv/csv.dart';

/// Top-level CSV-Parser für [compute] / [Isolate.run] (nur sendable Argumente).
List<List<dynamic>> parseCsvRowsIsolate(Map<String, String> args) {
  final csvString = args['csv'] ?? '';
  final delimiter = args['delimiter'] ?? ';';
  return CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csvString);
}
