/// Listenzeile einer Anlage bzw. eines Bauteils in der hierarchischen Übersicht.
///
/// Wird in der Systems-/Technik-Liste genutzt, um Parent-Anlagen und Child-Bauteile
/// einheitlich darzustellen (Auswahlmodus, Expand/Collapse, Validierungs-Badge).

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/systems/widgets/systems_list_tile_styles.dart';

/// Eine Zeile in der Anlagenhierarchie (Parent-Anlage oder Child-Bauteil).
///
/// Layout: Leading-Icon → Titel/Untertitel → optionales Trailing
/// (Auswahlkreis, Expand-Chevron oder „zuletzt geöffnet“-Hinweis).
class AnlageHierarchicalItem extends StatelessWidget {
  /// Die anzuzeigende Anlage bzw. das Bauteil.
  final Anlage anlage;

  /// Disziplin der Zeile (aktuell vor allem für Kontext; Icon hängt an [isChild]).
  final Disziplin discipline;

  /// `true` = eingerücktes Bauteil (Child), sonst Parent-Anlage.
  final bool isChild;

  /// Ob die Parent-Anlage Kinder hat (steuert Expand-Chevron).
  final bool hasChildren;

  /// Ob die Kindliste dieser Parent-Anlage ausgeklappt ist.
  final bool isExpanded;

  /// Tippen auf das Expand-Icon; nur relevant bei Parent mit Kindern.
  final VoidCallback? onToggleExpanded;

  /// Ob die Zeile im Mehrfachauswahl-Modus markiert ist.
  final bool isSelected;

  /// Auswahlkreise statt Expand/History anzeigen (Mehrfachauswahl aktiv).
  final bool showSelectionCircles;

  /// Validierungsstatus – zeigt ein Häkchen-Badge am Leading-Icon.
  final bool isValidated;

  /// Markiert die zuletzt geöffnete Parent-Anlage (Hintergrund + History-Icon).
  final bool isLastOpened;

  /// Optionaler Key zum Scrollen zu dieser Zeile (z. B. nach Navigation zurück).
  final Key? scrollKey;

  /// Tippen auf die Zeile (Öffnen/Detail bzw. Auswahl umschalten).
  final VoidCallback onTap;

  /// Langer Druck (typisch: Auswahlmodus starten).
  final VoidCallback? onLongPress;

  /// Fallback-Untertitel „Typ: …“, wenn kein konfigurierter Untertitel gesetzt ist.
  final String? typeHint;

  /// Vorschau-Text (z. B. Anzeigename); wird nur genutzt, wenn er vom Titel abweicht.
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

  /// Ermittelt den Untertitel mit fester Priorität:
  /// 1) konfigurierter [subtitleText],
  /// 2) [previewText], sofern er sich vom Anlagennamen unterscheidet,
  /// 3) sonst „Typ: …“ aus [typeHint].
  String? _subtitleText() {
    final configured = subtitleText?.trim() ?? '';
    if (configured.isNotEmpty) return configured;

    final typeDisplay = typeHint?.trim() ?? '';
    final previewDisplay = previewText?.trim() ?? '';
    final titleName = anlage.name.trim();
    // Identische Preview wie der Titel würde nur redundant wirken.
    final showPreview = previewDisplay.isNotEmpty &&
        previewDisplay.toLowerCase() != titleName.toLowerCase();

    if (showPreview) return previewDisplay;
    if (typeDisplay.isNotEmpty) return 'Typ: $typeDisplay';
    return null;
  }

  /// Stil-Ebene für Abstände/Icons: Bauteil vs. Anlage.
  SystemsOverviewLevel get _level =>
      isChild ? SystemsOverviewLevel.bauteil : SystemsOverviewLevel.anlage;

  /// Hintergrund: Auswahl hat Vorrang vor „zuletzt geöffnet“; Kinder ohne Extra-Tint.
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

    // Trailing-Priorität: Auswahlmodus > Expand (nur Parent mit Kindern) > History.
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
      // Eigenes GestureDetector, damit Expand den Zeilen-onTap nicht auslöst.
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
      // Leichter Abstand zwischen Zeilen ohne ListView.separator.
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

/// Leading-Icon links: Ordner (Anlage) bzw. Werkzeug (Bauteil), optional Validierungs-Badge.
class _LeadingIcon extends StatelessWidget {
  /// Disziplin-Kontext der Zeile (für künftige Icon-/Farbvarianten reserviert).
  final Disziplin discipline;

  /// Steuert Icon und Stil-Ebene (Bauteil vs. Anlage).
  final bool isChild;

  /// Hervorgehobenes Leading bei Auswahl.
  final bool isSelected;

  /// Zeigt das kleine Häkchen-Badge unten rechts am Icon.
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
      // Badge darf leicht über den Icon-Rand ragen.
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
