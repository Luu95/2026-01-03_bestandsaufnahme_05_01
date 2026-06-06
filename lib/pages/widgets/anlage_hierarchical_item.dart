import 'package:flutter/material.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';
import 'systems_list_tile_styles.dart';

class AnlageHierarchicalItem extends StatelessWidget {
  final Anlage anlage;
  final Disziplin discipline;
  final bool isChild;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  final bool isSelected;
  final bool showSelectionCircles;
  final bool isValidated;
  final bool isLastOpened;

  final Key? scrollKey;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? typeHint;
  final String? previewText;

  const AnlageHierarchicalItem({
    super.key,
    required this.anlage,
    required this.discipline,
    required this.isSelected,
    required this.showSelectionCircles,
    required this.isValidated,
    required this.isLastOpened,
    required this.onTap,
    this.onLongPress,
    this.typeHint,
    this.previewText,
    this.scrollKey,
    this.isChild = false,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  String? _subtitleText() {
    final typeDisplay = typeHint?.trim() ?? '';
    final previewDisplay = previewText?.trim() ?? '';
    final titleName = anlage.name.trim();
    final showPreview = previewDisplay.isNotEmpty &&
        previewDisplay.toLowerCase() != titleName.toLowerCase();

    final herstellerEntries = anlage.params.entries
        .where((e) => e.key.toLowerCase() == 'hersteller')
        .toList();
    if (herstellerEntries.isNotEmpty) {
      return herstellerEntries.first.value.toString();
    }
    if (showPreview) return previewDisplay;
    if (typeDisplay.isNotEmpty) return 'Typ: $typeDisplay';
    return null;
  }

  SystemsOverviewLevel get _level =>
      isChild ? SystemsOverviewLevel.bauteil : SystemsOverviewLevel.anlage;

  Color _backgroundColor() {
    if (isSelected) {
      return SystemsOverviewPalette.primary.withOpacity(0.1);
    }
    if (isLastOpened && !isChild) {
      return SystemsOverviewPalette.primary.withOpacity(0.08);
    }
    return SystemsListTileStyles.backgroundForLevel(_level);
  }

  Color _borderColor() {
    if (isSelected) {
      return SystemsOverviewPalette.borderExpanded;
    }
    if (isLastOpened && !isChild) {
      return SystemsOverviewPalette.primary;
    }
    return SystemsOverviewPalette.borderMuted;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleText();

    Widget? trailing;
    if (showSelectionCircles) {
      trailing = Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? SystemsOverviewPalette.primary
            : SystemsOverviewPalette.iconMuted,
        size: 24,
      );
    } else if (!isChild && hasChildren) {
      trailing = IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: onToggleExpanded,
        icon: Icon(
          isExpanded ? Icons.expand_more : Icons.chevron_right,
          color: isExpanded
              ? SystemsOverviewPalette.primary
              : SystemsOverviewPalette.iconMuted,
        ),
      );
    }

    return Container(
      key: scrollKey,
      margin: EdgeInsets.only(bottom: 6, left: isChild ? 4 : 0),
      child: Material(
        color: _backgroundColor(),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _borderColor()),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _LeadingIcon(
                  discipline: discipline,
                  isChild: isChild,
                  isSelected: isSelected,
                  isValidated: isValidated,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              anlage.name,
                              style: TextStyle(
                                fontWeight: isChild
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                fontSize: isChild ? 14 : 15,
                                color: isSelected
                                    ? SystemsOverviewPalette.primaryDark
                                    : SystemsOverviewPalette.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLastOpened && !isChild) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.history,
                              size: 16,
                              color: SystemsOverviewPalette.primary,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: SystemsOverviewPalette.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final Disziplin discipline;
  final bool isChild;
  final bool isSelected;
  final bool isValidated;

  const _LeadingIcon({
    required this.discipline,
    required this.isChild,
    required this.isSelected,
    required this.isValidated,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isChild
        ? SystemsOverviewPalette.iconChild
        : SystemsOverviewPalette.icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? SystemsOverviewPalette.primary.withOpacity(0.18)
                : SystemsOverviewPalette.primary.withOpacity(0.1),
          ),
          child: Icon(
            isChild ? Icons.build_outlined : discipline.icon,
            color: iconColor,
            size: isChild ? 20 : 22,
          ),
        ),
        if (isValidated)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: SystemsOverviewPalette.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 11),
            ),
          ),
      ],
    );
  }
}
