/// Feste Gruppierungsarten in der Anlagenliste (Technik-Tab).
enum SystemsGroupingMode {
  none,
  etage,
  revisionsfeld,
}

extension SystemsGroupingModeX on SystemsGroupingMode {
  static SystemsGroupingMode? fromStorage(String? value) {
    switch (value) {
      case 'etage':
        return SystemsGroupingMode.etage;
      case 'revisionsfeld':
        return SystemsGroupingMode.revisionsfeld;
      case null:
      case '':
        return SystemsGroupingMode.none;
      default:
        return null;
    }
  }

  String get storageValue {
    switch (this) {
      case SystemsGroupingMode.none:
        return '';
      case SystemsGroupingMode.etage:
        return 'etage';
      case SystemsGroupingMode.revisionsfeld:
        return 'revisionsfeld';
    }
  }

  String get label {
    switch (this) {
      case SystemsGroupingMode.none:
        return 'Keine Gruppierung';
      case SystemsGroupingMode.etage:
        return 'Etage';
      case SystemsGroupingMode.revisionsfeld:
        return 'Revisionsfeld';
    }
  }
}
