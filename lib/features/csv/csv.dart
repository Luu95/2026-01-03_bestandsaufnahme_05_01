/// Barrel der CSV-Domäne (Modelle, Einstellungen, Cleanup, Schema-Ableitung).
///
/// Bevorzugter Import in App-Code:
/// `import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';`
/// (re-exportiert diese Datei plus Riverpod-Provider).
library;

export 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
export 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';
export 'package:bestandsaufnahme_01/features/csv/models/import_attribute_mapping.dart';
export 'package:bestandsaufnahme_01/features/csv/models/schema_field.dart';
export 'package:bestandsaufnahme_01/features/csv/csv_settings.dart';
export 'package:bestandsaufnahme_01/features/csv/anlage_params_cleanup.dart';
export 'package:bestandsaufnahme_01/features/csv/schema/schema_fields_from_row.dart';
