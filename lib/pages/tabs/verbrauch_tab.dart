// lib/pages/tabs/verbrauch_tab.dart

import 'package:flutter/material.dart';
import '../../models/building.dart';

// Platzhalter-Tab für „VerbrauchTab“
class VerbrauchTab extends StatelessWidget {
  final Building building;

  const VerbrauchTab({super.key, required this.building});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Verbrauchsdaten für ${building.name}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
