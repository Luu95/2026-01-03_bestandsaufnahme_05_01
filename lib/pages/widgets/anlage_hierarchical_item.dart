import 'package:flutter/material.dart';

import '../../models/anlage.dart';
import '../../models/disziplin_schnittstelle.dart';

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

  /// Key, der am äußeren Container hängt (wird u.a. für Auto-Scrolling genutzt).
  final Key? scrollKey;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? typeHint;

  const AnlageHierarchicalItem({
    super.key,
    required this.anlage,
    required this.discipline,
    required this.isSelected,
    required this.showSelectionCircles,
    required this.isValidated,
    required this.isLastOpened,
    required     this.onTap,
    this.onLongPress,
    this.typeHint,
    this.scrollKey,
    this.isChild = false,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final typeDisplay = typeHint?.trim() ?? '';

    final baseTrailing = showSelectionCircles
        ? (isSelected
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              )
            : Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ))
        : null;

    Widget? trailing;
    if (showSelectionCircles) {
      trailing = baseTrailing;
    } else {
      final actions = <Widget>[];

      // Expand-Arrow nur wenn Kinder vorhanden
      if (!isChild && hasChildren) {
        actions.add(
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleExpanded,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: isExpanded
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (actions.isNotEmpty) {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        );
      }
    }

    // Bestimme die Hintergrundfarbe basierend auf dem Status und Typ
    Color? cardBackgroundColor;
    if (isSelected) {
      cardBackgroundColor = Theme.of(context).primaryColor.withOpacity(0.05);
    } else if (isLastOpened && !isChild) {
      // Zuletzt geöffnete Anlage: subtiler blauer Ton (hat Vorrang vor Validierung)
      cardBackgroundColor = Colors.blue.withOpacity(0.04);
    } else if (isValidated) {
      // Vollständige Anlage: keine grüne Färbung, nur Haken
      cardBackgroundColor = isChild
          ? Color.lerp(
              Colors.white,
              Color.lerp(discipline.color, Colors.orange.shade50, 0.3) ??
                  Colors.white,
              0.1,
            )
          : Color.lerp(
              Colors.white,
              Color.lerp(discipline.color, Colors.green.shade50, 0.25) ??
                  Colors.white,
              0.08,
            );
    } else {
      // Feine Nuancen für visuelle Unterscheidung:
      // Anlagen: sehr subtiler grünlicher Ton
      // Bauteile: sehr subtiler orange/beige Ton
      if (isChild) {
        // Bauteil: sehr subtiler orange/beige Ton
        cardBackgroundColor = Color.lerp(
          Colors.white,
          Color.lerp(discipline.color, Colors.orange.shade50, 0.3) ??
              Colors.white,
          0.1,
        );
      } else {
        // Anlage: sehr subtiler grünlicher Ton
        cardBackgroundColor = Color.lerp(
          Colors.white,
          Color.lerp(discipline.color, Colors.green.shade50, 0.25) ??
              Colors.white,
          0.08,
        );
      }
    }

    return Container(
      key: scrollKey, // GlobalKey für Auto-Scrolling
      margin: EdgeInsets.only(
        bottom: 4,
        top: 1,
        left: isChild ? 12 : 0,
        right: isChild ? 12 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.15)
                : (isLastOpened && !isChild
                    ? Colors.blue.withOpacity(0.12)
                    : (isValidated
                        ? Colors.black.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05))),
            blurRadius: isValidated || (isLastOpened && !isChild) ? 8 : 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isChild
                // Bauteil: subtiler orange/beige Border
                ? (Color.lerp(
                      Colors.blue.withOpacity(0.2),
                      Colors.orange.withOpacity(0.25),
                      0.4,
                    ) ??
                    Colors.blue.withOpacity(0.2))
                : (isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.4)
                    : (isLastOpened && !isChild
                        // Zuletzt geöffnete Anlage: blauer Border (hat Vorrang vor Validierung)
                        ? Colors.blue.withOpacity(0.5)
                        : (isValidated
                            // Vollständige Anlage: keine grüne Border-Farbe
                            ? (Color.lerp(
                                  Colors.grey.withOpacity(0.15),
                                  Colors.green.withOpacity(0.1),
                                  0.3,
                                ) ??
                                Colors.grey.withOpacity(0.15))
                            // Anlage: subtiler grünlicher Border
                            : (Color.lerp(
                                  Colors.grey.withOpacity(0.15),
                                  Colors.green.withOpacity(0.1),
                                  0.3,
                                ) ??
                                Colors.grey.withOpacity(0.15))))),
            width: isSelected || isValidated || (isLastOpened && !isChild)
                ? 1.5
                : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Leading Icon mit verbessertem Design
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.2),
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                ]
                              : (isValidated
                                  // Vollständige Anlage: keine grüne Färbung im Icon-Container
                                  ? (isChild
                                      // Bauteil: subtiler orange/beige Gradient
                                      ? [
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.15),
                                                Colors.orange.withOpacity(0.2),
                                                0.4,
                                              ) ??
                                              discipline.color.withOpacity(0.15),
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.08),
                                                Colors.orange.withOpacity(0.1),
                                                0.4,
                                              ) ??
                                              discipline.color.withOpacity(0.08),
                                        ]
                                      // Anlage: subtiler grünlicher Gradient
                                      : [
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.15),
                                                Colors.green.withOpacity(0.15),
                                                0.2,
                                              ) ??
                                              discipline.color.withOpacity(0.15),
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.08),
                                                Colors.green.withOpacity(0.08),
                                                0.2,
                                              ) ??
                                              discipline.color.withOpacity(0.08),
                                        ])
                                  : isChild
                                      // Bauteil: subtiler orange/beige Gradient
                                      ? [
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.15),
                                                Colors.orange.withOpacity(0.2),
                                                0.4,
                                              ) ??
                                              discipline.color.withOpacity(0.15),
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.08),
                                                Colors.orange.withOpacity(0.1),
                                                0.4,
                                              ) ??
                                              discipline.color.withOpacity(0.08),
                                        ]
                                      // Anlage: subtiler grünlicher Gradient
                                      : [
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.15),
                                                Colors.green.withOpacity(0.15),
                                                0.2,
                                              ) ??
                                              discipline.color.withOpacity(0.15),
                                          Color.lerp(
                                                discipline.color
                                                    .withOpacity(0.08),
                                                Colors.green.withOpacity(0.08),
                                                0.2,
                                              ) ??
                                              discipline.color.withOpacity(0.08),
                                        ]),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isChild
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.green.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isChild ? Icons.build : discipline.icon,
                        color: isChild
                            ? (Color.lerp(
                                  discipline.color,
                                  Colors.orange.shade700,
                                  0.3,
                                ) ??
                                discipline.color)
                            : discipline.color,
                        size: isChild ? 20 : 24,
                      ),
                    ),
                    if (isValidated)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Titel und Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    anlage.name,
                                    style: TextStyle(
                                      fontWeight: isChild
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[900],
                                      fontSize: isChild ? 15 : 16,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLastOpened && !isChild) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Zuletzt angesehen',
                                    child: Icon(
                                      Icons.visibility,
                                      size: 16,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              () {
                                final herstellerEntries = anlage.params.entries
                                    .where((e) =>
                                        e.key.toLowerCase() == 'hersteller')
                                    .toList();
                                return herstellerEntries.isEmpty
                                    ? (typeDisplay.isNotEmpty
                                        ? 'Typ: $typeDisplay'
                                        : '')
                                    : herstellerEntries.first.value.toString();
                              }(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing
                if (trailing != null) ...[
                  const SizedBox(width: 8),
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
