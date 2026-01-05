// lib/services/anlage_validation_service.dart

import '../models/anlage.dart';

/// Service zur Validierung von Anlagen
class AnlageValidationService {
  /// Prüft, ob eine Anlage vollständig ausgefüllt und validiert ist.
  /// Eine Anlage ist validiert, wenn:
  /// 1. Der Name nicht leer ist
  /// 2. Alle Schema-Felder der Disziplin in params vorhanden und nicht leer sind
  /// 3. Felder die als fehlend markiert sind, werden ignoriert
  static bool isAnlageValidated(Anlage anlage) {
    // Name muss vorhanden sein
    if (anlage.name.trim().isEmpty) {
      return false;
    }

    final schema = anlage.discipline.schema;
    
    // Prüfe alle Schema-Felder
    for (final fieldDef in schema) {
      final key = fieldDef['key'];
      if (key == null) continue;
      
      // Überspringe Felder, die als fehlend markiert sind
      if (isFieldMarkedAsMissing(anlage, key)) {
        continue;
      }
      
      // Prüfe ob das Feld in params existiert
      if (!anlage.params.containsKey(key)) {
        return false;
      }
      
      final value = anlage.params[key];
      
      // Prüfe ob der Wert nicht leer ist
      if (value == null || 
          value.toString().trim().isEmpty ||
          value.toString().trim() == 'null') {
        return false;
      }
      
      // Wenn Feld befüllt ist, muss es auch als validiert markiert sein
      if (!isFieldValidated(anlage, key)) {
        return false;
      }
    }
    
    return true;
  }

  /// Setzt den Validierungsstatus einer Anlage
  static Anlage setValidatedStatus(Anlage anlage, bool validated) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);
    updatedParams['_validated'] = validated;
    updatedParams['_validatedAt'] = validated 
        ? DateTime.now().toIso8601String() 
        : null;
    
    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Liest den gespeicherten Validierungsstatus (prüft auch automatisch)
  static bool getValidatedStatus(Anlage anlage) {
    // Wenn explizit als validiert markiert, verwende das
    if (anlage.params.containsKey('_validated')) {
      return anlage.params['_validated'] == true;
    }
    
    // Sonst prüfe automatisch
    return isAnlageValidated(anlage);
  }

  /// Berechnet den Fortschritt (Anzahl validierter / Gesamt)
  static ValidationProgress calculateProgress(List<Anlage> anlagen) {
    if (anlagen.isEmpty) {
      return ValidationProgress(total: 0, validated: 0, percentage: 0.0);
    }
    
    final validatedCount = anlagen.where((a) => getValidatedStatus(a)).length;
    final percentage = (validatedCount / anlagen.length) * 100.0;
    
    return ValidationProgress(
      total: anlagen.length,
      validated: validatedCount,
      percentage: percentage,
    );
  }

  /// Zählt fehlende Felder für eine Anlage (ignoriert als fehlend markierte Felder)
  static int getMissingFieldsCount(Anlage anlage) {
    if (anlage.name.trim().isEmpty) {
      return anlage.discipline.schema.length + 1; // Name + alle Schema-Felder
    }
    
    int missing = 0;
    final schema = anlage.discipline.schema;
    
    for (final fieldDef in schema) {
      final key = fieldDef['key'];
      if (key == null) continue;
      
      // Überspringe Felder, die als fehlend markiert sind
      if (isFieldMarkedAsMissing(anlage, key)) {
        continue;
      }
      
      if (!anlage.params.containsKey(key)) {
        missing++;
      } else {
        final value = anlage.params[key];
        if (value == null || 
            value.toString().trim().isEmpty ||
            value.toString().trim() == 'null') {
          missing++;
        }
      }
    }
    
    return missing;
  }

  /// Prüft, ob ein Feld als validiert markiert ist
  static bool isFieldValidated(Anlage anlage, String fieldKey) {
    return anlage.params['_field_${fieldKey}_validated'] == true;
  }

  /// Prüft, ob ein Feld als fehlend markiert ist
  static bool isFieldMarkedAsMissing(Anlage anlage, String fieldKey) {
    return anlage.params['_field_${fieldKey}_missing'] == true;
  }

  /// Setzt den Validierungsstatus eines einzelnen Feldes
  static Anlage setFieldValidated(Anlage anlage, String fieldKey, bool validated) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);
    updatedParams['_field_${fieldKey}_validated'] = validated;
    if (!validated) {
      // Wenn Validierung entfernt wird, auch fehlend-Status entfernen
      updatedParams.remove('_field_${fieldKey}_missing');
    }
    
    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Markiert ein Feld als fehlend (fällt aus Bewertung heraus)
  static Anlage setFieldAsMissing(Anlage anlage, String fieldKey, bool missing) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);
    updatedParams['_field_${fieldKey}_missing'] = missing;
    if (missing) {
      // Wenn als fehlend markiert, Validierung entfernen
      updatedParams.remove('_field_${fieldKey}_validated');
    }
    
    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Prüft, ob eine Anlage fehlende Parameter hat (Felder die als fehlend markiert sind)
  static bool hasMissingParameters(Anlage anlage) {
    final schema = anlage.discipline.schema;
    for (final fieldDef in schema) {
      final key = fieldDef['key'];
      if (key == null) continue;
      if (isFieldMarkedAsMissing(anlage, key)) {
        return true;
      }
    }
    return false;
  }

  /// Zählt die Anzahl der als fehlend markierten Felder
  static int getMissingParametersCount(Anlage anlage) {
    int count = 0;
    final schema = anlage.discipline.schema;
    for (final fieldDef in schema) {
      final key = fieldDef['key'];
      if (key == null) continue;
      if (isFieldMarkedAsMissing(anlage, key)) {
        count++;
      }
    }
    return count;
  }
}

/// Datenklasse für Validierungsfortschritt
class ValidationProgress {
  final int total;
  final int validated;
  final double percentage;

  ValidationProgress({
    required this.total,
    required this.validated,
    required this.percentage,
  });

  int get remaining => total - validated;
}

