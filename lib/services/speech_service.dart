import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/app_log.dart';

/// Offline-Spracherkennung über die Geräte-API (on-device).
///
/// Android: Erfordert ein installiertes Offline-Sprachpaket für Deutsch
/// (Einstellungen → Sprache → Spracheingabe → Offline-Spracherkennung).
/// iOS: Nutzt die lokale Spracherkennung des Geräts.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _germanLocaleId;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _initialized && _speech.isAvailable;

  Future<bool> ensureInitialized() async {
    if (_initialized) return _speech.isAvailable;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      appLog('SpeechService: Mikrofon-Berechtigung verweigert');
      return false;
    }

    _initialized = await _speech.initialize(
      onError: (error) => appLog('SpeechService Fehler: $error'),
      onStatus: (status) => appLog('SpeechService Status: $status'),
    );

    if (_initialized) {
      _germanLocaleId = await _resolveGermanLocaleId();
    }
    return _initialized && _speech.isAvailable;
  }

  Future<String?> _resolveGermanLocaleId() async {
    try {
      final locales = await _speech.locales();
      for (final id in ['de_DE', 'de-DE', 'de_AT', 'de-CH', 'de']) {
        final match = locales.where((l) => l.localeId == id);
        if (match.isNotEmpty) return match.first.localeId;
      }
      final dePrefix = locales.where((l) => l.localeId.startsWith('de'));
      if (dePrefix.isNotEmpty) return dePrefix.first.localeId;
      if (locales.isNotEmpty) return locales.first.localeId;
    } catch (e) {
      appLog('SpeechService: Locale-Auflösung fehlgeschlagen: $e');
    }
    return 'de_DE';
  }

  /// Startet Offline-Diktat. [onPartial] wird bei Zwischenergebnissen aufgerufen.
  /// Gibt den finalen Text zurück oder `null` bei Abbruch/Fehler.
  Future<String?> dictate({
    required void Function(String partial) onPartial,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    if (!await ensureInitialized()) return null;

    if (_speech.isListening) {
      await _speech.stop();
      return null;
    }

    final completer = Completer<String?>();
    var lastText = '';

    void complete(String? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        lastText = result.recognizedWords;
        if (lastText.isNotEmpty) onPartial(lastText);
        if (result.finalResult) complete(lastText.isEmpty ? null : lastText);
      },
      listenOptions: SpeechListenOptions(
        localeId: _germanLocaleId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        onDevice: true,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );

    // Fallback, falls kein finalResult kommt
    Future.delayed(listenFor + pauseFor + const Duration(milliseconds: 500), () async {
      if (_speech.isListening) await _speech.stop();
      final text = lastText.trim();
      complete(text.isEmpty ? null : text);
    });

    return completer.future;
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _speech.cancel();
  }
}
