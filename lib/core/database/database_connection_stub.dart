/// Stub für die Datenbankverbindung, wenn weder IO noch HTML verfügbar sind.
/// Wird nur als Conditional-Import-Fallback geladen und wirft dann.
import 'package:drift/drift.dart';

/// Nicht unterstützte Plattform – wirft [UnsupportedError].
LazyDatabase createConnection() {
  throw UnsupportedError('No suitable database implementation found');
}
