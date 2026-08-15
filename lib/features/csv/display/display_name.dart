/// Display-Name: Platzhalter-Erkennung und Auflösung des Anzeige-Param-Keys.
///
/// Extension auf [CsvSettings] (`part of` derselben Library). Statische API
/// bleibt auf der Klasse; private Helfer sind library-privat.

part of '../csv_settings.dart';

// --- Abschnitt: Display-Name ---

/// Anzeigenamen und Platzhalter-Logik für Listen-/Dialog-Titel.
extension CsvSettingsDisplayName on CsvSettings {
  /// True bei leerem Wert oder generischen Labels (Eintrag, Ebenen-Label, …).
  bool isPlaceholderDisplayValue(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return true;
    if (t == 'Eintrag') return true;
    if (t == labelGewerk || t == labelAnlage || t == labelBauteil) return true;
    final leafLabel = resolveLeafLevelLabel().trim();
    if (leafLabel.isNotEmpty && t == leafLabel) return true;
    final underRoLabel = resolveDatensatzUnderRevisionsobjektLabel().trim();
    if (underRoLabel.isNotEmpty && t == underRoLabel) return true;
    for (var level = 1; level <= 3; level++) {
      final headerLabel = hierarchyLevelHeaderLabel(level).trim();
      if (headerLabel.isNotEmpty && t == headerLabel) return true;
    }
    return false;
  }

  /// True, wenn [value] kein eigenständiger Anzeigename ist (Platzhalter oder
  /// identisch mit Hierarchie-/Schema-Wert, z. B. Revisionsobjekt).
  bool isNonDistinctDisplayValue(
    String? value,
    Map<String, dynamic> params,
  ) {
    final t = value?.trim() ?? '';
    if (isPlaceholderDisplayValue(t)) return true;

    final schemaValue = schemaItemValueFromParams(params)?.trim() ?? '';
    if (schemaValue.isNotEmpty &&
        t.toLowerCase() == schemaValue.toLowerCase()) {
      return true;
    }
    final roValue = revisionsobjektValueFromParams(params)?.trim() ?? '';
    if (roValue.isNotEmpty && t.toLowerCase() == roValue.toLowerCase()) {
      return true;
    }

    final enabled = enabledLevelsOrdered;
    final leafNum = enabled.isEmpty
        ? null
        : levelNumberAtEnabledIndex(enabled.length - 1);
    for (var level = 1; level <= 3; level++) {
      // Blatt-Hierarchie-Wert nicht als „Duplikat“ werten (Import-Name).
      if (leafNum != null && level == leafNum) continue;
      final hv = hierarchyLevelValueFromParams(params, level)?.trim() ?? '';
      if (hv.isNotEmpty && t.toLowerCase() == hv.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// True, wenn die Anlage bewusst ohne echten Listen-Titel gespeichert wurde.
  bool hasListNamePlaceholder(Map<String, dynamic> params) {
    final v = params[CsvSettings.listNamePlaceholderParamKey];
    return v == true || v?.toString() == 'true';
  }

  /// Param-Key für die Titelzeile in der Anlagenliste.
  /// Priorität: expliziter Param-Key → Anzeige-Spalte → Blatt-Spalte → „Bezeichnung“.
  /// Niemals Hierarchie-/Ebene-Keys (sonst landet der Anzeigename in Ebene2).
  String? resolveDisplayNameParamKey() {
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty) {
      return mustNotReceiveDisplayName(explicit) ? null : explicit;
    }
    final fromDisplayColumn = _headerLabelAt(displayNameSpalte);
    if (fromDisplayColumn != null &&
        fromDisplayColumn.isNotEmpty &&
        !mustNotReceiveDisplayName(fromDisplayColumn) &&
        !CsvSettings.isEbeneHierarchyHeader(fromDisplayColumn)) {
      return fromDisplayColumn;
    }
    final leafKey = resolveNameParamKey();
    if (leafKey != null &&
        leafKey.isNotEmpty &&
        !mustNotReceiveDisplayName(leafKey) &&
        !CsvSettings.isEbeneHierarchyHeader(leafKey) &&
        !isUpperHierarchyParamKey(leafKey)) {
      return leafKey;
    }
    return 'Bezeichnung';
  }
}
