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
  /// Konfigurierter Untertitel (z. B. Hersteller) – leer/null = kein festes Attribut.
  final String? subtitleText;

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
    this.subtitleText,
    this.scrollKey,
    this.isChild = false,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  String? _subtitleText() {
    final configured = subtitleText?.trim() ?? '';
    if (configured.isNotEmpty) return configured;

    final typeDisplay = typeHint?.trim() ?? '';
    final previewDisplay = previewText?.trim() ?? '';
    final titleName = anlage.name.trim();
    final showPreview = previewDisplay.isNotEmpty &&
        previewDisplay.toLowerCase() != titleName.toLowerCase();

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
      return SystemsOverviewPalette.primary.withOpacity(0.06);
    }
    return Colors.transparent;
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
        size: SystemsListTileStyles.chevronSize,
      );
    } else if (!isChild && hasChildren) {
      trailing = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SystemsListTileStyles.expandIcon(
            isExpanded: isExpanded,
            level: _level,
          ),
        ),
      );
    } else if (isLastOpened && !isChild) {
      trailing = const Icon(
        Icons.history,
        size: 16,
        color: SystemsOverviewPalette.iconMuted,
      );
    }

    return Padding(
      key: scrollKey,
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: _backgroundColor(),
        elevation: 0,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: SystemsListTileStyles.rowPadding,
            child: Row(
              children: [
                _LeadingIcon(
                  discipline: discipline,
                  isChild: isChild,
                  isSelected: isSelected,
                  isValidated: isValidated,
                ),
                const SizedBox(width: SystemsListTileStyles.leadingGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        anlage.name,
                        style: SystemsListTileStyles.titleStyle.copyWith(
                          color: isSelected
                              ? SystemsOverviewPalette.primaryDark
                              : SystemsOverviewPalette.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: SystemsOverviewPalette.textSecondary,
                            fontSize: 12,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing,
                ],
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
    final level = isChild
        ? SystemsOverviewLevel.bauteil
        : SystemsOverviewLevel.anlage;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SystemsListTileStyles.leadingIcon(
          icon: isChild ? Icons.build_outlined : Icons.folder_outlined,
          level: level,
          emphasized: isSelected,
        ),
        if (isValidated)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: SystemsOverviewPalette.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 9),
            ),
          ),
      ],
    );
  }
}
