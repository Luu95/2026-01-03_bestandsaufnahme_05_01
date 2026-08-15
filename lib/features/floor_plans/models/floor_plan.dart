/// Domänenmodell einer Etage bzw. eines Grundrisses mit optionaler PDF-Referenz.
/// Metadaten gehören zum Gebäude; die PDF-Datei liegt im lokalen Dateisystem.

/// Etage/Grundriss mit Anzeigename und optionalem PDF-Pfad/-Dateiname.
class FloorPlan {
  String id;
  String name;
  String? pdfPath;
  String? pdfName;

  FloorPlan({
    required this.id,
    required this.name,
    this.pdfPath,
    this.pdfName,
  });

  /// Deserialisiert einen Grundriss aus JSON.
  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pdfPath: json['pdfPath'] as String?,
      pdfName: json['pdfName'] as String?,
    );
  }

  /// Serialisiert den Grundriss für Speicherung/Export.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pdfPath': pdfPath,
      'pdfName': pdfName,
    };
  }
}
