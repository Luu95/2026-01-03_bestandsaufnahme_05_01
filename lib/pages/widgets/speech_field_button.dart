import 'package:flutter/material.dart';

/// Kompakter Mikrofon-Button (FAB-Stil), erscheint nur beim fokussierten Feld.
class SpeechMicFab extends StatelessWidget {
  final bool listening;
  final VoidCallback onPressed;

  const SpeechMicFab({
    super.key,
    required this.listening,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: FloatingActionButton.small(
          heroTag: null,
          onPressed: onPressed,
          tooltip: listening ? 'Diktat beenden' : 'Diktieren (offline)',
          backgroundColor: listening
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
          child: Icon(
            listening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
