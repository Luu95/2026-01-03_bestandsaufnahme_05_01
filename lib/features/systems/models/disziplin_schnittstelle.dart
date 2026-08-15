/// Domänenmodell und Schema-Logik für technische Disziplinen (Gewerke).
/// Steuert globale und revisionsobjekt-spezifische Attributfelder einer Anlage.

import 'package:flutter/material.dart';

/// Modellklasse für eine technische Disziplin (Gewerk / Revisionsfeld).
class Disziplin {
  String label;
  IconData icon;
  Color color;
  /// Globale Felder (isGlobal) und Legacy-Felder ohne RO-Zuordnung.
  List<Map<String, dynamic>> schema;
  /// Optionaler Schlüssel zur Gruppierung verwandter Disziplinen.
  String? groupingKey;
  /// Attribut-Schemas pro Revisionsobjekt (Anlagentyp).
  Map<String, List<Map<String, dynamic>>> revisionsobjektSchemas;

  Disziplin({
    required this.label,
    required this.icon,
    required this.color,
    required this.schema,
    this.groupingKey,
    Map<String, List<Map<String, dynamic>>>? revisionsobjektSchemas,
  }) : revisionsobjektSchemas = revisionsobjektSchemas ?? {};

  /// Parst die RO→Schema-Map aus JSON; ungültige Einträge werden verworfen.
  static Map<String, List<Map<String, dynamic>>> _parseRevisionsobjektSchemas(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, List<Map<String, dynamic>>>{};
    raw.forEach((key, value) {
      if (value is! List) return;
      final fields = value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (fields.isNotEmpty) {
        result[key.toString()] = fields;
      }
    });
    return result;
  }

  /// Nur als global markierte Schema-Felder.
  List<Map<String, dynamic>> get globalSchemaFields =>
      schema.where((f) => f['isGlobal'] == true).map((f) => Map<String, dynamic>.from(f)).toList();

  /// Nicht-globale Felder aus dem Flat-Schema (ältere Daten ohne RO-Map).
  List<Map<String, dynamic>> get legacyIndividualSchemaFields =>
      schema.where((f) => f['isGlobal'] != true).map((f) => Map<String, dynamic>.from(f)).toList();

  /// Findet den gespeicherten RO-Map-Key zu einem Anzeige-/Param-Wert (case-insensitive).
  String? resolveRevisionsobjektKey(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (revisionsobjektSchemas.containsKey(v)) return v;
    for (final k in revisionsobjektSchemas.keys) {
      if (k.trim().toLowerCase() == v.toLowerCase()) return k;
    }
    return null;
  }

  /// Effektives Schema für eine Anlage: global + RO-spezifisch.
  List<Map<String, dynamic>> effectiveSchemaFor({String? revisionsobjekt}) {
    final global = globalSchemaFields;
    final ro = revisionsobjekt?.trim() ?? '';
    if (ro.isNotEmpty) {
      final resolvedKey = resolveRevisionsobjektKey(ro) ?? ro;
      final roFields = revisionsobjektSchemas[resolvedKey];
      if (roFields != null && roFields.isNotEmpty) {
        return [...global, ...roFields.map((f) => Map<String, dynamic>.from(f))];
      }
      // RO gewählt, aber kein Map-Eintrag: gespeichertes Flat-Schema der Anlage nutzen
      // (z. B. nach Speichern, wenn revisionsobjektSchemas beim Laden verworfen wurde).
      final legacy = legacyIndividualSchemaFields;
      if (legacy.isNotEmpty) {
        return [...global, ...legacy];
      }
      return global;
    }
    // Legacy-Fallback: alte Daten ohne RO-Schemas (nur wenn kein RO gewählt)
    final legacy = legacyIndividualSchemaFields;
    if (legacy.isNotEmpty) {
      return [...global, ...legacy];
    }
    return global;
  }

  /// Kopie mit aufgelöstem Schema für UI/Anlage-Dialog.
  Disziplin withEffectiveSchema({String? revisionsobjekt}) {
    return Disziplin(
      label: label,
      icon: icon,
      color: color,
      schema: effectiveSchemaFor(revisionsobjekt: revisionsobjekt),
      groupingKey: groupingKey,
      revisionsobjektSchemas: revisionsobjektSchemas,
    );
  }

  /// Alle bekannten Revisionsobjekte (aus gespeicherten Schemas).
  List<String> get revisionsobjektNames {
    return revisionsobjektSchemas.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Deserialisiert eine Disziplin inkl. Icon-, Farb- und Schema-Daten.
  factory Disziplin.fromJson(Map<String, dynamic> json) {
    return Disziplin(
      label: json['label'] as String,
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
      ),
      color: Color(json['colorValue'] as int),
      schema: (json['schema'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      groupingKey: json['groupingKey'] as String?,
      revisionsobjektSchemas: _parseRevisionsobjektSchemas(json['revisionsobjektSchemas']),
    );
  }

  /// Serialisiert die Disziplin; leere RO-Schemas werden weggelassen.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'schema': schema,
      'groupingKey': groupingKey,
      if (revisionsobjektSchemas.isNotEmpty)
        'revisionsobjektSchemas': revisionsobjektSchemas.map(
          (key, value) => MapEntry(key, value),
        ),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Disziplin &&
              runtimeType == other.runtimeType &&
              label == other.label;

  @override
  int get hashCode => label.hashCode;
}
