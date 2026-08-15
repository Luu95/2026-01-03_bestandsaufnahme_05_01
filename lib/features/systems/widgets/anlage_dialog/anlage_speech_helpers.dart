/// Speech-/Diktier-Helfer für Formularfelder.
///
/// UI-Callbacks (SnackBar, setState) bleiben beim Caller; hier nur Orchestrierung.

import 'package:bestandsaufnahme_01/features/media/services/speech_service.dart';

/// true für Felder, die sich per Spracheingabe füllen lassen.
bool isSpeechEligibleFieldType(String type) {
  final t = type.toLowerCase();
  return t != 'date' && t != 'dropdown' && t != 'select';
}

/// Startet/stoppt Offline-Diktat. [onRecognized] erhält Partial- und Finaltext.
///
/// Rückgabe: `false`, wenn Spracherkennung nicht verfügbar war.
Future<bool> runFieldDictation({
  required void Function(String text) onRecognized,
  required void Function(bool listening) onListeningChanged,
}) async {
  if (SpeechService.instance.isListening) {
    await SpeechService.instance.cancel();
    onListeningChanged(false);
    return true;
  }

  final available = await SpeechService.instance.ensureInitialized();
  if (!available) {
    return false;
  }

  onListeningChanged(true);
  final result = await SpeechService.instance.dictate(
    onPartial: (partial) {
      if (partial.trim().isNotEmpty) onRecognized(partial);
    },
  );
  onListeningChanged(false);

  if (result != null && result.trim().isNotEmpty) {
    onRecognized(result.trim());
  }
  return true;
}
