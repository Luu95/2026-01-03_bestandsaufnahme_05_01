// models/project.dart

import 'building.dart';

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

  // JSON → Project
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

  // Project → JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'customer': customer,
    'buildings': buildings.map((b) => b.toJson()).toList(),
  };
}
