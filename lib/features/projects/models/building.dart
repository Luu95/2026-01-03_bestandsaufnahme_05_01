/// Domänenmodell für ein Gebäude inkl. Etagen-/Grundriss-Metadaten.
/// Anlagen selbst liegen in der Drift-Tabelle `anlagen`, nicht in diesem Modell.

import 'package:bestandsaufnahme_01/features/floor_plans/models/floor_plan.dart';

/// Gebäude-Stammdaten. Anlagen leben in der Drift-Tabelle `anlagen`, nicht hier.
class Building {
  String id;
  String name;
  String address;
  String postalCode;
  String city;
  String type;
  double bgf;
  int constructionYear;
  List<int> renovationYears;
  bool protectedMonument;
  int units;
  double floorArea;
  List<FloorPlan> floors;

  Building({
    required this.id,
    required this.name,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.type,
    required this.bgf,
    required this.constructionYear,
    required this.renovationYears,
    required this.protectedMonument,
    required this.units,
    required this.floorArea,
    required this.floors,
  });

  /// Deserialisiert ein Gebäude inkl. Etagen ([FloorPlan]) aus JSON.
  factory Building.fromJson(Map<String, dynamic> json) {
    final floorsJson = json['floors'] as List<dynamic>?;
    final floorsList = floorsJson != null
        ? floorsJson
            .map((e) => FloorPlan.fromJson(e as Map<String, dynamic>))
            .toList()
        : <FloorPlan>[];

    return Building(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      city: json['city'] as String? ?? '',
      type: json['type'] as String? ?? '',
      bgf: (json['bgf'] as num?)?.toDouble() ?? 0.0,
      constructionYear: json['constructionYear'] as int? ?? 0,
      renovationYears: (json['renovationYears'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          <int>[],
      protectedMonument: json['protectedMonument'] as bool? ?? false,
      units: json['units'] as int? ?? 0,
      floorArea: (json['floorArea'] as num?)?.toDouble() ?? 0.0,
      floors: floorsList,
    );
  }

  /// Serialisiert Stammdaten und Etagen für Speicherung/Export.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'postalCode': postalCode,
        'city': city,
        'type': type,
        'bgf': bgf,
        'constructionYear': constructionYear,
        'renovationYears': renovationYears,
        'protectedMonument': protectedMonument,
        'units': units,
        'floorArea': floorArea,
        'floors': floors.map((e) => e.toJson()).toList(),
      };
}
