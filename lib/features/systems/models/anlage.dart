/// Domänenmodell einer technischen Anlage (inkl. optionaler Marker-Daten).
/// Parameter und Disziplin-Schema steuern Dialog, CSV-Import und Validierung.

import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';

/// Eine Anlage bzw. ein Revisionsobjekt im Gebäude, ggf. als Marker auf dem Grundriss.
class Anlage {
  String id;
  String? parentId;
  String name;
  Map<String, dynamic> params;
  String floorId;
  String buildingId;
  bool isMarker;
  Map<String, dynamic>? markerInfo;
  String markerType;
  Disziplin discipline;

  Anlage({
    required this.id,
    this.parentId,
    required this.name,
    required this.params,
    required this.floorId,
    required this.buildingId,
    required this.isMarker,
    this.markerInfo,
    required this.markerType,
    required this.discipline,
  });

  /// Serialisiert eine Anlage zu JSON, inkl. voller Disziplin-Daten.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'name': name,
      'params': params,
      'floorId': floorId,
      'buildingId': buildingId,
      'isMarker': isMarker,
      'markerInfo': markerInfo,
      'markerType': markerType,
      // Volle Disziplin in JSON
      'discipline': discipline.toJson(),
    };
  }

  /// Erzeugt eine Anlage aus JSON, inklusive Disziplin.
  factory Anlage.fromJson(Map<String, dynamic> map) {
    // Disziplin aus JSON rekonstruiert
    final discJson = map['discipline'] as Map<String, dynamic>;
    final disc = Disziplin.fromJson(discJson);

    return Anlage(
      id: map['id'] as String,
      parentId: map['parentId'] as String?,
      name: map['name'] as String,
      params: Map<String, dynamic>.from(map['params'] as Map),
      floorId: map['floorId'] as String,
      buildingId: map['buildingId'] as String,
      isMarker: map['isMarker'] as bool,
      markerInfo: map['markerInfo'] != null
          ? Map<String, dynamic>.from(map['markerInfo'] as Map)
          : null,
      markerType: map['markerType'] as String,
      discipline: disc,
    );
  }
}
