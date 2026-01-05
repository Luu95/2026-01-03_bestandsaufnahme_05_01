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

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pdfPath: json['pdfPath'] as String?,
      pdfName: json['pdfName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pdfPath': pdfPath,
      'pdfName': pdfName,
    };
  }
}
