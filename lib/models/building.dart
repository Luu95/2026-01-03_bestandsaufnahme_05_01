// lib/models/building.dart

import 'envelope.dart';
import 'floor_plan.dart';
import 'anlage.dart';

/// Verwaltet alle Anlagen-Listen pro Disziplin anhand von String-Keys.
class BuildingSystems {
  /// Map, in der der Key das Disziplin-Label ist.
  final Map<String, List<Anlage>> systemsMap;

  /// Neuer Konstruktor: Nimmt eine Map von Label zu Anlage-Liste oder erstellt eine leere Map.
  BuildingSystems({Map<String, List<Anlage>>? systems})
      : systemsMap = systems ?? {};

  /// Factory zum Erzeugen aus JSON, wobei Schlüssel-Strings direkt verwendet werden.
  factory BuildingSystems.fromJson(Map<String, dynamic>? json) {
    final temp = <String, List<Anlage>>{};
    if (json != null) {
      for (final entry in json.entries) {
        final rawList = (entry.value as List<dynamic>? ) ?? [];
        temp[entry.key] = rawList
            .map((e) => Anlage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return BuildingSystems(systems: temp);
  }

  /// Wandelt die Map in JSON um, Keys sind Disziplin-Labels.
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    systemsMap.forEach((key, list) {
      out[key] = list.map((a) => a.toJson()).toList();
    });
    return out;
  }
}

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
  Envelope envelope;
  BuildingSystems systems;
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
    required this.envelope,
    required this.systems,
    required this.floors,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    // Envelope
    final envelopeJson = json['envelope'] as Map<String, dynamic>?;
    final envelope = envelopeJson != null
        ? Envelope.fromJson(envelopeJson)
        : Envelope(
      walls: [],
      roof: Roof(type: '', uValue: 0.0, area: 0.0, insulation: false),
      floor: FloorSurface(type: '', uValue: 0.0, area: 0.0, insulated: false),
      windows: [],
    );

    // Systems
    final systemsJson = json['systems'] as Map<String, dynamic>?;
    final systems = BuildingSystems.fromJson(systemsJson);

    // Floors
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
          .toList() ?? <int>[],
      protectedMonument: json['protectedMonument'] as bool? ?? false,
      units: json['units'] as int? ?? 0,
      floorArea: (json['floorArea'] as num?)?.toDouble() ?? 0.0,
      envelope: envelope,
      systems: systems,
      floors: floorsList,
    );
  }

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
    'envelope': envelope.toJson(),
    'systems': systems.toJson(),
    'floors': floors.map((e) => e.toJson()).toList(),
  };
}
