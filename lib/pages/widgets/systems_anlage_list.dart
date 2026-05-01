import 'package:flutter/material.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';

typedef AnlageItemBuilder = Widget Function(
  Anlage anlage,
  Disziplin disc, {
  required bool isChild,
  required bool hasChildren,
  required bool isExpanded,
  VoidCallback? onToggleExpanded,
});

class SystemsAnlageList extends StatelessWidget {
  final bool isLoading;
  final bool hasLoadedOnce;
  final Disziplin disc;
  final List<Anlage> parents;
  final List<Anlage> Function(Anlage parent) getChildren;

  /// Optionaler Gruppierungs-Key, mit dem die Liste dynamisch gruppiert werden kann.
  /// Wenn null oder leer, wird nicht gruppiert.
  final String? groupingKey;

  final Set<String> expandedGroups;
  final Set<String> expandedAnlagenIds;

  final void Function(String groupKey, bool expanded) onGroupExpansionChanged;
  final void Function(String anlageId) onToggleAnlageExpanded;
  /// Wird bei Long-Press auf einen Gruppen-Header aufgerufen (groupingKey, groupValue).
  final void Function(String groupingKey, String groupValue)? onGroupLongPress;

  final AnlageItemBuilder itemBuilder;

  const SystemsAnlageList({
    super.key,
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.disc,
    required this.parents,
    required this.getChildren,
    this.groupingKey,
    required this.expandedGroups,
    required this.expandedAnlagenIds,
    required this.onGroupExpansionChanged,
    required this.onToggleAnlageExpanded,
    this.onGroupLongPress,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Anlagen werden geladen...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Zeige Platzhalter nur an, wenn Daten bereits geladen wurden und Liste wirklich leer ist
    if (parents.isEmpty && hasLoadedOnce) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  disc.icon,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Keine ${disc.label} Anlagen vorhanden',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tippen Sie oben auf das + Symbol, um eine neue Anlage hinzuzufügen',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Gruppierung: Nur wenn ein expliziter groupingKey von außen gesetzt ist.
    // Die frühere fallback-Gruppierung über disc.groupingKey wird nicht mehr verwendet.
    final effectiveGroupingKey = (groupingKey != null && groupingKey!.isNotEmpty)
        ? groupingKey
        : null;

    if (effectiveGroupingKey != null && effectiveGroupingKey.isNotEmpty) {
      final hasAnyGroupingValue = parents.any((anlage) {
        final value = anlage.params[effectiveGroupingKey]?.toString().trim() ?? '';
        return value.isNotEmpty;
      });
      if (!hasAnyGroupingValue) {
        // Wenn das Feld in den aktuellen Anlagen keine Werte hat, ungegruppte Liste zeigen.
        return _buildUngroupedList();
      }

      // Gruppiere Anlagen nach dem Wert des groupingKey Parameters
      final Map<String, List<Anlage>> grouped = {};
      for (final anlage in parents) {
        final groupValue = anlage.params[effectiveGroupingKey]?.toString() ?? '';
        grouped.putIfAbsent(groupValue, () => []).add(anlage);
      }

      // Sortiere Gruppen nach Key (leerer String kommt zuletzt)
      final sortedGroupKeys = grouped.keys.toList()
        ..sort((a, b) {
          if (a.isEmpty) return 1;
          if (b.isEmpty) return -1;
          return a.compareTo(b);
        });

      final List<Widget> items = [];
      for (final groupKey in sortedGroupKeys) {
        final groupAnlagen = grouped[groupKey]!;
        final groupDisplayName =
            groupKey.isEmpty ? '(Ohne $effectiveGroupingKey)' : groupKey;
        final isGroupExpanded = expandedGroups.contains(groupKey);

        items.add(
          GestureDetector(
            onLongPress: onGroupLongPress != null
                ? () => onGroupLongPress!(effectiveGroupingKey, groupKey)
                : null,
            child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              // Feine Nuance für Gruppierung: sehr subtiler lila/grauer Ton
              color: Color.lerp(
                Colors.white,
                Color.lerp(disc.color, Colors.purple.shade50, 0.25) ??
                    Colors.white,
                0.12,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGroupExpanded
                    ? disc.color.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.15),
                width: isGroupExpanded ? 1.5 : 1,
              ),
              boxShadow: isGroupExpanded
                  ? [
                      BoxShadow(
                        color: disc.color.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('group_$groupKey'),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isGroupExpanded
                          ? [
                              disc.color.withOpacity(0.2),
                              disc.color.withOpacity(0.1),
                            ]
                          : [
                              disc.color.withOpacity(0.15),
                              disc.color.withOpacity(0.08),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.folder, color: disc.color, size: 20),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupDisplayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isGroupExpanded ? disc.color : Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: disc.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${groupAnlagen.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: disc.color,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isGroupExpanded
                        ? disc.color.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isGroupExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: isGroupExpanded ? disc.color : Colors.grey[600],
                    size: 22,
                  ),
                ),
                initiallyExpanded: isGroupExpanded,
                onExpansionChanged: (expanded) =>
                    onGroupExpansionChanged(groupKey, expanded),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      // Feine Nuance für Anlagen in Gruppierung: sehr subtiler grünlicher Ton
                      color: Color.lerp(
                        Colors.grey[50]!,
                        Color.lerp(disc.color, Colors.green.shade50, 0.2) ??
                            Colors.grey[50]!,
                        0.08,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    child: Column(
                      children: groupAnlagen.expand((parent) {
                        final children = getChildren(parent);
                        final hasChildren = children.isNotEmpty;
                        final isExpanded =
                            expandedAnlagenIds.contains(parent.id);

                        final widgets = <Widget>[
                          itemBuilder(
                            parent,
                            disc,
                            isChild: false,
                            hasChildren: hasChildren,
                            isExpanded: isExpanded,
                            onToggleExpanded: hasChildren
                                ? () => onToggleAnlageExpanded(parent.id)
                                : null,
                          ),
                        ];

                        if (hasChildren && isExpanded) {
                          widgets.addAll(
                            children.map(
                              (child) => Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: itemBuilder(
                                  child,
                                  disc,
                                  isChild: true,
                                  hasChildren: false,
                                  isExpanded: false,
                                ),
                              ),
                            ),
                          );
                        }

                        return widgets;
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      }

      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: items,
      );
    }

    return _buildUngroupedList();
  }

  Widget _buildUngroupedList() {
    // Aufklappbare Darstellung: Eltern-Anlage + Bauteile erst bei Expand anzeigen (ohne Gruppierung)
    final List<Widget> items = [];
    for (final parent in parents) {
      final children = getChildren(parent);
      final hasChildren = children.isNotEmpty;
      final isExpanded = expandedAnlagenIds.contains(parent.id);

      items.add(
        itemBuilder(
          parent,
          disc,
          isChild: false,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onToggleExpanded: hasChildren ? () => onToggleAnlageExpanded(parent.id) : null,
        ),
      );

      if (hasChildren && isExpanded) {
        for (final child in children) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: itemBuilder(
                child,
                disc,
                isChild: true,
                hasChildren: false,
                isExpanded: false,
              ),
            ),
          );
        }
      }
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: items,
    );
  }
}
