/// Leerer Scaffold der Gebäude-Hauptseite (keine Projekte / keine Gebäude).

import 'package:flutter/material.dart';

/// Leerer Zustand der Gebäude-Hauptseite (keine Projekte / keine Gebäude).
class BuildingDetailsEmptyScaffold extends StatelessWidget {
  final Widget drawer;
  final ValueChanged<bool>? onDrawerChanged;
  final String title;
  final String message;

  const BuildingDetailsEmptyScaffold({
    super.key,
    required this.drawer,
    this.onDrawerChanged,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      onDrawerChanged: onDrawerChanged,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}
