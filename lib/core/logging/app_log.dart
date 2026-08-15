/// Zentrales Debug-Logging der App (`[Wisag]`-Prefix).
/// Nur in Debug-Builds aktiv; Release bleibt still.
import 'package:flutter/foundation.dart';

/// Signatur für austauschbare Log-Callbacks (Tests/Mocks).
typedef AppLogFn = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// Debug-only Logging (verschwindet in Release).
///
/// Ziel: `debugPrint`-Spam aus produktiven Builds rausziehen, ohne überall
/// `kDebugMode` zu duplizieren.
void appLog(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!kDebugMode) return;
  final base = '[Wisag] $message';
  if (error == null && stackTrace == null) {
    debugPrint(base);
    return;
  }
  debugPrint(
    [
      base,
      if (error != null) 'error=$error',
      if (stackTrace != null) 'stackTrace=$stackTrace',
    ].join(' | '),
  );
}
