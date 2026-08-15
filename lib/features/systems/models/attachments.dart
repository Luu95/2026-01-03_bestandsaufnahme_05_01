/// Domänenmodell für Anlagen-Anhänge: Fotopfade, Planpfade und Freitext-Notizen.
/// Wird in Params/JSON mitgeführt und beim Export/Import berücksichtigt.

/// Sammlung von Foto-/Plan-Pfaden und Notizen zu einer Anlage.
class Attachments {
  List<String> photos;
  List<String> plans;
  String notes;

  Attachments({
    required this.photos,
    required this.plans,
    required this.notes,
  });

  /// Deserialisiert Anhänge aus JSON (fehlende Listen werden leer).
  factory Attachments.fromJson(Map<String, dynamic> json) => Attachments(
    photos: List<String>.from(json['photos'] ?? []),
    plans: List<String>.from(json['plans'] ?? []),
    notes: json['notes'] ?? '',
  );

  /// Serialisiert Anhänge für Speicherung/Export.
  Map<String, dynamic> toJson() => {
    'photos': photos,
    'plans': plans,
    'notes': notes,
  };
}
