import 'package:flutter/material.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import '../../providers/csv_settings_provider.dart';

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

  /// Optionaler Unter-Gruppierungs-Key (z. B. Revisionsobjekt innerhalb Revisionsfeld).
  final String? subGroupingKey;

  /// Param-Key für den Anzeigenamen, wenn Name und Untergruppe identisch sind.
  final String? displayNameParamKey;

  /// Auflösung des Listen-Anzeigenamens (z. B. aus CSV-Einstellungen Ebene 3).
  final String Function(Anlage anlage)? resolveListDisplayName;

  final Set<String> expandedGroups;
  final Set<String> expandedAnlagenIds;

  final void Function(String groupKey, bool expanded) onGroupExpansionChanged;
  final void Function(String anlageId) onToggleAnlageExpanded;
  /// Long-Press auf Gruppen-Header (Param-Key der Gruppe, Wert, zusätzliche Params).
  final void Function(
    String groupingKey,
    String groupValue,
    Map<String, dynamic> additionalParams,
  )? onGroupLongPress;

  final AnlageItemBuilder itemBuilder;

  /// Wenn true: eigenständige scrollbare Liste (kein shrinkWrap).
  final bool usePrimaryScroll;

  const SystemsAnlageList({
    super.key,
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.disc,
    required this.parents,
    required this.getChildren,
    this.usePrimaryScroll = false,
    this.groupingKey,
    this.subGroupingKey,
    this.displayNameParamKey,
    this.resolveListDisplayName,
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
        return _buildUngroupedList(context);
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

      // Eine Gruppe = Disziplin-Name → Ebene 1 ist schon das Gewerk-Tab, nicht nochmal gruppieren.
      if (sortedGroupKeys.length == 1) {
        final only = sortedGroupKeys.first.trim();
        if (only.isNotEmpty &&
            only.toLowerCase() == disc.label.trim().toLowerCase()) {
          return _buildUngroupedList(context);
        }
      }

      return ListView.builder(
        shrinkWrap: !usePrimaryScroll,
        physics: usePrimaryScroll
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 4,
          bottom: 8,
          left: usePrimaryScroll ? 12 : 0,
          right: usePrimaryScroll ? 12 : 0,
        ),
        itemCount: sortedGroupKeys.length,
        itemBuilder: (context, index) {
          final groupKey = sortedGroupKeys[index];
          final groupAnlagen = grouped[groupKey]!;
          return _buildGroupExpansionTile(
            context,
            effectiveGroupingKey: effectiveGroupingKey,
            groupKey: groupKey,
            groupAnlagen: groupAnlagen,
          );
        },
      );
    }

    return _buildUngroupedList(context);
  }

  bool _shouldApplyRootSubGrouping(List<Anlage> items) {
    if (subGroupingKey == null || subGroupingKey!.isEmpty) return false;
    for (final a in items) {
      if (getChildren(a).isNotEmpty) continue;
      if (_resolveSubGroupValue(a).isNotEmpty) return true;
      if (a.name.trim().isNotEmpty) return true;
    }
    return false;
  }

  Widget _buildUngroupedList(BuildContext context) {
    if (_shouldApplyRootSubGrouping(parents)) {
      return ListView(
        shrinkWrap: !usePrimaryScroll,
        physics: usePrimaryScroll
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 4,
          bottom: 8,
          left: usePrimaryScroll ? 12 : 0,
          right: usePrimaryScroll ? 12 : 0,
        ),
        children: _buildGroupChildren(context, '', parents),
      );
    }

    return ListView.builder(
      shrinkWrap: !usePrimaryScroll,
      physics: usePrimaryScroll
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 4,
        bottom: 8,
        left: usePrimaryScroll ? 12 : 0,
        right: usePrimaryScroll ? 12 : 0,
      ),
      itemCount: parents.length,
      itemBuilder: (context, index) =>
          _buildParentWithChildren(parents[index]),
    );
  }

  Anlage _withDisplayName(Anlage anlage, String name) {
    if (name == anlage.name) return anlage;
    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: name,
      params: anlage.params,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  String _listDisplayName(Anlage anlage, {String? override}) {
    if (override != null && override.isNotEmpty) return override;
    final resolver = resolveListDisplayName;
    if (resolver != null) return resolver(anlage);
    return _resolveDisplayName(anlage);
  }

  Widget _buildParentWithChildren(Anlage parent, {String? displayNameOverride}) {
    final children = getChildren(parent);
    final hasChildren = children.isNotEmpty;
    final isExpanded = expandedAnlagenIds.contains(parent.id);
    final resolvedParentName = displayNameOverride ??
        (!hasChildren ? _listDisplayName(parent) : null);
    final displayParent = resolvedParentName != null
        ? _withDisplayName(parent, resolvedParentName)
        : parent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        itemBuilder(
          displayParent,
          disc,
          isChild: false,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onToggleExpanded:
              hasChildren ? () => onToggleAnlageExpanded(parent.id) : null,
        ),
        if (hasChildren && isExpanded)
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: itemBuilder(
                _withDisplayName(child, _listDisplayName(child)),
                disc,
                isChild: true,
                hasChildren: false,
                isExpanded: false,
              ),
            ),
      ],
    );
  }

  String _resolveSubGroupValue(Anlage anlage) {
    final key = subGroupingKey;
    if (key == null || key.isEmpty) return '';
    final fromParams = anlage.params[key]?.toString().trim() ?? '';
    if (fromParams.isNotEmpty) return fromParams;
    return '';
  }

  String _resolveDisplayName(Anlage anlage) {
    final key = displayNameParamKey;
    if (key != null && key.isNotEmpty) {
      final direct = anlage.params[key]?.toString().trim() ?? '';
      if (direct.isNotEmpty) return direct;
      for (final entry in anlage.params.entries) {
        if (!CsvSettings.paramKeysMatch(entry.key.toString(), key)) continue;
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return anlage.name;
  }

  bool _needsSubGroupNest(List<Anlage> items, String subKey) {
    // Untergruppe immer einblenden, damit Long-Press auf das Revisionsobjekt
    // (grünes Plus → neue Anlage) auch bei nur einem Eintrag möglich ist.
    if (subGroupingKey != null &&
        subGroupingKey!.isNotEmpty &&
        subKey.isNotEmpty) {
      return true;
    }
    if (items.length > 1) return true;
    if (items.isEmpty) return false;
    final item = items.first;
    if (getChildren(item).isNotEmpty) return false;
    if (item.name.trim() == subKey.trim()) return true;
    final displayName = _resolveDisplayName(item);
    return displayName.trim() != item.name.trim();
  }

  List<Widget> _buildGroupChildren(
    BuildContext context,
    String parentGroupValue,
    List<Anlage> groupAnlagen, {
    String? parentGroupingKey,
  }) {
    final subKey = subGroupingKey;
    if (subKey == null || subKey.isEmpty) {
      return groupAnlagen
          .map((a) => _buildParentWithChildren(a))
          .toList();
    }

    final hasSubValues = groupAnlagen.any((a) {
      final v = _resolveSubGroupValue(a);
      return v.isNotEmpty || (a.name.trim().isNotEmpty && getChildren(a).isEmpty);
    });
    if (!hasSubValues) {
      return groupAnlagen.map((a) => _buildParentWithChildren(a)).toList();
    }

    final withChildren = <Anlage>[];
    final subGroups = <String, List<Anlage>>{};

    for (final anlage in groupAnlagen) {
      if (getChildren(anlage).isNotEmpty) {
        withChildren.add(anlage);
        continue;
      }
      var subValue = _resolveSubGroupValue(anlage);
      if (subValue.isEmpty) subValue = anlage.name.trim();
      subGroups.putIfAbsent(subValue, () => []).add(anlage);
    }

    final widgets = <Widget>[
      ...withChildren.map((a) => _buildParentWithChildren(a)),
    ];

    final sortedSubKeys = subGroups.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });

    for (final sk in sortedSubKeys) {
      final items = subGroups[sk]!;
      if (sk.isEmpty) {
        widgets.addAll(items.map((a) => _buildParentWithChildren(a)));
      } else if (!_needsSubGroupNest(items, sk)) {
        widgets.add(_buildParentWithChildren(items.first));
      } else {
        widgets.add(_buildSubGroupExpansionTile(
          context,
          parentGroupValue: parentGroupValue,
          parentGroupingKey: parentGroupingKey,
          subGroupKey: sk,
          subGroupAnlagen: items,
        ));
      }
    }

    return widgets;
  }

  Widget _buildSubGroupExpansionTile(
    BuildContext context, {
    required String parentGroupValue,
    required String? parentGroupingKey,
    required String subGroupKey,
    required List<Anlage> subGroupAnlagen,
  }) {
    final compositeKey = parentGroupValue.isEmpty
        ? subGroupKey
        : '$parentGroupValue|$subGroupKey';
    final isSubExpanded = expandedGroups.contains(compositeKey);
    final subKey = subGroupingKey;

    return GestureDetector(
      onLongPress: onGroupLongPress != null && subKey != null && subKey.isNotEmpty
          ? () {
              final additional = <String, dynamic>{};
              if (parentGroupValue.isNotEmpty &&
                  parentGroupingKey != null &&
                  parentGroupingKey.isNotEmpty) {
                additional[parentGroupingKey] = parentGroupValue;
              }
              if (subGroupAnlagen.isNotEmpty) {
                additional['__sampleAnlageId'] = subGroupAnlagen.first.id;
              }
              onGroupLongPress!(subKey, subGroupKey, additional);
            }
          : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSubExpanded
              ? disc.color.withOpacity(0.2)
              : Colors.grey.withOpacity(0.12),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('subgroup_$compositeKey'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(Icons.subdirectory_arrow_right, color: disc.color.withOpacity(0.7), size: 18),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  subGroupKey,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: disc.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${subGroupAnlagen.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: disc.color),
                ),
              ),
            ],
          ),
          trailing: Icon(
            isSubExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            color: Colors.grey[600],
            size: 20,
          ),
          initiallyExpanded: isSubExpanded,
          onExpansionChanged: (expanded) =>
              onGroupExpansionChanged(compositeKey, expanded),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 6),
              child: Column(
                children: [
                  for (final anlage in subGroupAnlagen)
                    _buildParentWithChildren(
                      anlage,
                      displayNameOverride: _listDisplayName(anlage),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildGroupExpansionTile(
    BuildContext context, {
    required String effectiveGroupingKey,
    required String groupKey,
    required List<Anlage> groupAnlagen,
  }) {
    final groupDisplayName =
        groupKey.isEmpty ? '(Ohne $effectiveGroupingKey)' : groupKey;
    final isGroupExpanded = expandedGroups.contains(groupKey);

    return GestureDetector(
      onLongPress: onGroupLongPress != null
          ? () {
              final additional = <String, dynamic>{};
              if (groupAnlagen.isNotEmpty) {
                additional['__sampleAnlageId'] = groupAnlagen.first.id;
              }
              onGroupLongPress!(effectiveGroupingKey, groupKey, additional);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.white,
            Color.lerp(disc.color, Colors.purple.shade50, 0.25) ?? Colors.white,
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: _buildGroupChildren(
                    context,
                    groupKey,
                    groupAnlagen,
                    parentGroupingKey: effectiveGroupingKey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
