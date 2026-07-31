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

/// Gemeinsames Styling für die Anlagenübersicht.
///
/// Eine äußere Fläche, darunter flache Zeilen mit einheitlichem Raster:
/// gleiche Icon-Box, gleicher Textstil, feste Einrückungsstufe.
class SystemsListTileStyles {
  SystemsListTileStyles._();

  static const BorderRadius groupRadius = BorderRadius.all(Radius.circular(10));

  /// Einheitliches Zeilen-Raster für alle Ebenen.
  static const double leadingBox = 28;
  static const double rowIconSize = 16;
  static const double leadingGap = 10;
  static const double indentStep = 16;
  static const double chevronSize = 20;
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const TextStyle titleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppPalette.textPrimary,
  );
  static const TextStyle titleStyleEmphasized = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppPalette.textPrimary,
  );

  static Color accentForLevel(SystemsOverviewLevel level) {
    // Eine Farbe für alle Ebenen → ruhigere, ausgerichtete Optik.
    switch (level) {
      case SystemsOverviewLevel.discipline:
      case SystemsOverviewLevel.group:
        return AppPalette.primary;
      case SystemsOverviewLevel.subGroup:
      case SystemsOverviewLevel.anlage:
      case SystemsOverviewLevel.bauteil:
        return AppPalette.iconMuted;
    }
  }

  static Color backgroundForLevel(SystemsOverviewLevel level) {
    switch (level) {
      case SystemsOverviewLevel.discipline:
      case SystemsOverviewLevel.group:
        return Colors.white;
      case SystemsOverviewLevel.subGroup:
      case SystemsOverviewLevel.anlage:
      case SystemsOverviewLevel.bauteil:
        return Colors.transparent;
    }
  }

  static BoxDecoration groupContainer({
    required bool isExpanded,
    required SystemsOverviewLevel level,
  }) {
    return BoxDecoration(
      color: backgroundForLevel(level),
      borderRadius: groupRadius,
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }

  /// Äußere Hülle nur für Disziplin/Gruppe. Untergruppen bleiben flach.
  static Widget groupShell({
    required BuildContext context,
    required bool isExpanded,
    required SystemsOverviewLevel level,
    EdgeInsetsGeometry? margin,
    BorderSide? borderSide,
    required Widget child,
  }) {
    final isNested = level == SystemsOverviewLevel.subGroup;
    final themed = Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(
          horizontalTitleGap: leadingGap,
          minLeadingWidth: leadingBox,
          minVerticalPadding: 0,
          dense: true,
          visualDensity: VisualDensity.compact,
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: Border(),
          collapsedShape: Border(),
          tilePadding: rowPadding,
          childrenPadding: EdgeInsets.zero,
          iconColor: AppPalette.iconMuted,
          collapsedIconColor: AppPalette.iconMuted,
        ),
      ),
      child: child,
    );

    if (isNested) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: themed,
      );
    }

    final side = borderSide ??
        const BorderSide(color: Color(0xFFE2E8F0), width: 1);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: groupRadius,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: themed,
      ),
    );
  }

  /// Einheitliche Leading-Box für alle Ebenen.
  static Widget leadingIcon({
    required IconData icon,
    required SystemsOverviewLevel level,
    bool emphasized = false,
  }) {
    final accent = accentForLevel(level);
    return SizedBox(
      width: leadingBox,
      height: leadingBox,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withOpacity(emphasized ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: accent, size: rowIconSize),
      ),
    );
  }

  static Widget countBadge(int count, [SystemsOverviewLevel? level]) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppPalette.textSecondary,
          height: 1.2,
        ),
      ),
    );
  }

  static Widget expandIcon({
    required bool isExpanded,
    SystemsOverviewLevel level = SystemsOverviewLevel.group,
  }) {
    return SizedBox(
      width: chevronSize,
      height: chevronSize,
      child: AnimatedRotation(
        turns: isExpanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 180),
        child: const Icon(
          Icons.chevron_right,
          color: AppPalette.iconMuted,
          size: chevronSize,
        ),
      ),
    );
  }

  /// Trailing: optional Badge + Chevron, feste Breite für Ausrichtung.
  static Widget expandTrailing({
    required bool isExpanded,
    required SystemsOverviewLevel level,
    int? count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count != null) ...[
          countBadge(count, level),
          const SizedBox(width: 6),
        ],
        expandIcon(isExpanded: isExpanded, level: level),
      ],
    );
  }

  /// Einrückung mit Führungslinie – feste Stufe, Icons bleiben im Raster.
  static Widget nestedContent({
    required Widget child,
    int depth = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indentStep * depth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFE8EDF2), width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: indentStep - 1),
          child: child,
        ),
      ),
    );
  }

  static Widget disciplineLeading(Disziplin discipline, {bool expanded = false}) {
    return leadingIcon(
      icon: discipline.icon,
      level: SystemsOverviewLevel.discipline,
      emphasized: expanded,
    );
  }
}
