/// lib/models/marker.dart

import 'dart:convert';
import 'disziplin_schnittstelle.dart';
import 'package:flutter/material.dart';

/// Repräsentiert einen Marker im PDF-Grundriss.
class Marker {
  final String id;
  final Disziplin discipline;
  final String title;
  final double x;
  final double y;
  final int pageNumber;
  final Map<String, dynamic>? params;

  Marker({
    required this.id,
    required this.discipline,
    required this.title,
    required this.x,
    required this.y,
    required this.pageNumber,
    this.params,
  });

  /// Erstellt einen Marker aus JSON-Daten.
  factory Marker.fromJson(Map<String, dynamic> json) {
    // Disziplin anhand des Labels rekonstruieren
    final label = json['discipline'] as String;
    final disc = Disziplin(
      label: label,
      icon: Icons.build,
      color: Colors.grey,
      schema: [],
    );

    return Marker(
      id: json['id'] as String,
      discipline: disc,
      title: json['title'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pageNumber: json['pageNumber'] as int,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
    );
  }

  /// Wandelt den Marker in ein JSON-kompatibles Map um.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Speichere nur das Label der Disziplin
      'discipline': discipline.label,
      'title': title,
      'x': x,
      'y': y,
      'pageNumber': pageNumber,
      'params': params,
    };
  }
}
