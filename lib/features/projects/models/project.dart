/// Domänenmodell für ein Bestandsaufnahme-Projekt inkl. zugehöriger Gebäude.
/// Dient der JSON-Persistenz und der Navigation in der App-Hierarchie.

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';

/// Ein Projekt mit Stammdaten und der Liste der zugeordneten [Building]s.
class Project {
  final String id;
  String name;
  String description;
  String customer;
  List<Building> buildings;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.customer,
    required this.buildings,
  });

  /// Deserialisiert ein Projekt inkl. aller Gebäude aus JSON.
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      customer: json['customer'] as String? ?? '',
      buildings: (json['buildings'] as List<dynamic>)
          .map((e) => Building.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serialisiert das Projekt inkl. Gebäude für Speicherung/Export.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'customer': customer,
    'buildings': buildings.map((b) => b.toJson()).toList(),
  };
}
