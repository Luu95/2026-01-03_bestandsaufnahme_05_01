/// Wiederverwendbarer FAB mit einheitlichem Abstand und Elevation.

import 'package:flutter/material.dart';

/// Wiederverwendbarer FAB mit einheitlichem Abstand/Elevation.
class BuildingDetailsFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const BuildingDetailsFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: backgroundColor,
        elevation: 4,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
