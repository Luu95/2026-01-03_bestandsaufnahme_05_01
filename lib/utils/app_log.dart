import 'package:flutter/foundation.dart';

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

