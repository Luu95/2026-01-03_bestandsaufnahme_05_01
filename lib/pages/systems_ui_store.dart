/// In-Memory UI-State für `SystemsPage`.
///
/// Wichtig: Dies ist **keine** Persistenz für Geschäftsdaten. Der State lebt nur
/// für die Laufzeit der App und wird beim Neustart verworfen.
class SystemsUiStore {
  static final Map<String, Set<String>> _expandedGroupsByKey = {};
  static final Map<String, String> _lastOpenedAnlageByKey = {};
  static final Set<String> _hasScrolledToLastKeys = <String>{};

  static String _expandedGroupsKey(String buildingId, String disciplineLabel) =>
      'expanded_groups_${buildingId}_${disciplineLabel.toLowerCase()}';

  static String _lastOpenedKey(String buildingId, String floorId) =>
      'last_opened_anlage_${buildingId}_$floorId';

  static String _hasScrolledKey(
    String buildingId,
    String disciplineLabel,
    String floorId,
  ) =>
      'has_scrolled_to_last_${buildingId}_${disciplineLabel.toLowerCase()}_$floorId';

  // --- Expanded groups ---
  static Set<String> getExpandedGroups(String buildingId, String disciplineLabel) {
    final key = _expandedGroupsKey(buildingId, disciplineLabel);
    final set = _expandedGroupsByKey[key];
    return set == null ? <String>{} : Set<String>.from(set);
  }

  static void setExpandedGroups(
    String buildingId,
    String disciplineLabel,
    Set<String> expandedGroups,
  ) {
    final key = _expandedGroupsKey(buildingId, disciplineLabel);
    _expandedGroupsByKey[key] = Set<String>.from(expandedGroups);
  }

  // --- Last opened ---
  static String? getLastOpenedAnlageId(String buildingId, String floorId) {
    final key = _lastOpenedKey(buildingId, floorId);
    return _lastOpenedAnlageByKey[key];
  }

  static void setLastOpenedAnlageId(String buildingId, String floorId, String anlageId) {
    final key = _lastOpenedKey(buildingId, floorId);
    _lastOpenedAnlageByKey[key] = anlageId;
  }

  static void clearLastOpenedAnlageId(String buildingId, String floorId) {
    final key = _lastOpenedKey(buildingId, floorId);
    _lastOpenedAnlageByKey.remove(key);
  }

  // --- Scroll flags ---
  static bool getHasScrolledToLast(
    String buildingId,
    String disciplineLabel,
    String floorId,
  ) {
    final key = _hasScrolledKey(buildingId, disciplineLabel, floorId);
    return _hasScrolledToLastKeys.contains(key);
  }

  static void setHasScrolledToLast(
    String buildingId,
    String disciplineLabel,
    String floorId,
    bool value,
  ) {
    final key = _hasScrolledKey(buildingId, disciplineLabel, floorId);
    if (value) {
      _hasScrolledToLastKeys.add(key);
    } else {
      _hasScrolledToLastKeys.remove(key);
    }
  }

  static void resetHasScrolledForBuildingFloor(String buildingId, String floorId) {
    final prefix = 'has_scrolled_to_last_${buildingId}_';
    final suffix = '_$floorId';
    _hasScrolledToLastKeys.removeWhere((k) => k.startsWith(prefix) && k.endsWith(suffix));
  }
}







