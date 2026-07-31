import 'package:flutter/material.dart';

import '../../models/disziplin_schnittstelle.dart';
import '../../theme/app_palette.dart';

typedef SystemsOverviewPalette = AppPalette;

enum SystemsOverviewLevel {
  discipline,
  group,
  subGroup,
  anlage,
  bauteil,
}

/// Gemeinsames Styling für aufklappbare Gruppen in der Anlagenübersicht.
class SystemsListTileStyles {
  SystemsListTileStyles._();

  static Color accentForLevel(SystemsOverviewLevel level) {
    switch (level) {
      case SystemsOverviewLevel.discipline:
        return AppPalette.primaryDark;
      case SystemsOverviewLevel.group:
        return AppPalette.primary;
      case SystemsOverviewLevel.subGroup:
        return AppPalette.primaryLight;
      case SystemsOverviewLevel.anlage:
        return AppPalette.icon;
      case SystemsOverviewLevel.bauteil:
        return AppPalette.iconChild;
    }
  }

  static Color backgroundForLevel(SystemsOverviewLevel level) {
    switch (level) {
      case SystemsOverviewLevel.discipline:
        return AppPalette.surface;
      case SystemsOverviewLevel.group:
        return AppPalette.surface;
      case SystemsOverviewLevel.subGroup:
        return AppPalette.surfaceNested;
      case SystemsOverviewLevel.anlage:
        return AppPalette.surfaceCard;
      case SystemsOverviewLevel.bauteil:
        return AppPalette.surfaceChild;
    }
  }

  static const BorderRadius groupRadius = BorderRadius.all(Radius.circular(12));

  static BoxDecoration groupContainer({
    required bool isExpanded,
    required SystemsOverviewLevel level,
  }) {
    final accent = accentForLevel(level);
    return BoxDecoration(
      color: backgroundForLevel(level),
      borderRadius: groupRadius,
      border: Border.all(
        color: isExpanded
            ? AppPalette.borderExpanded
            : AppPalette.borderMuted,
        width: isExpanded ? 1.25 : 1,
      ),
      boxShadow: isExpanded
          ? [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  /// Clipped shell so ExpansionTile/Material fills don't spill past rounded corners.
  static Widget groupShell({
    required BuildContext context,
    required bool isExpanded,
    required SystemsOverviewLevel level,
    EdgeInsetsGeometry? margin,
    BorderSide? borderSide,
    required Widget child,
  }) {
    final accent = accentForLevel(level);
    final side = borderSide ??
        BorderSide(
          color: isExpanded
              ? AppPalette.borderExpanded
              : AppPalette.borderMuted,
          width: isExpanded ? 1.25 : 1,
        );

    return Container(
      margin: margin,
      decoration: isExpanded
          ? BoxDecoration(
              borderRadius: groupRadius,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            )
          : null,
      child: Material(
        color: backgroundForLevel(level),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: groupRadius,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            expansionTileTheme: const ExpansionTileThemeData(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: Border(),
              collapsedShape: Border(),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  static Widget countBadge(int count, SystemsOverviewLevel level) {
    final accent = accentForLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }

  static Widget expandIcon({
    required bool isExpanded,
    SystemsOverviewLevel level = SystemsOverviewLevel.group,
  }) {
    return Icon(
      isExpanded ? Icons.expand_more : Icons.chevron_right,
      color: isExpanded ? accentForLevel(level) : AppPalette.iconMuted,
      size: 22,
    );
  }

  static Widget disciplineLeading(Disziplin discipline, {bool expanded = false}) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.primary.withOpacity(expanded ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        discipline.icon,
        color: AppPalette.icon,
        size: 22,
      ),
    );
  }
}
