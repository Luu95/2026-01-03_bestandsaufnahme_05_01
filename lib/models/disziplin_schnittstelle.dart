import 'package:flutter/material.dart';

/// Modellklasse für eine technische Disziplin.
class Disziplin {
  String label;
  IconData icon;
  Color color;
  List<Map<String, String>> schema;
  String? groupingKey; // Optionaler Key für die Gruppierung (z.B. 'etage')

  Disziplin({
    required this.label,
    required this.icon,
    required this.color,
    required this.schema,
    this.groupingKey,
  });

  /// JSON-Deserialisierung
  factory Disziplin.fromJson(Map<String, dynamic> json) {
    return Disziplin(
      label: json['label'] as String,
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
      ),
      color: Color(json['colorValue'] as int),
      schema: (json['schema'] as List<dynamic>)
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      groupingKey: json['groupingKey'] as String?,
    );
  }

  /// JSON-Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'schema': schema,
      'groupingKey': groupingKey,
    };
  }

  /// Objektvergleich: Disziplinen mit gleichem Label gelten als gleich
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Disziplin &&
              runtimeType == other.runtimeType &&
              label == other.label;

  @override
  int get hashCode =>
      label.hashCode;
}
