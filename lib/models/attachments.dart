class Attachments {
  List<String> photos;
  List<String> plans;
  String notes;

  Attachments({
    required this.photos,
    required this.plans,
    required this.notes,
  });

  factory Attachments.fromJson(Map<String, dynamic> json) => Attachments(
    photos: List<String>.from(json['photos'] ?? []),
    plans: List<String>.from(json['plans'] ?? []),
    notes: json['notes'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'photos': photos,
    'plans': plans,
    'notes': notes,
  };
}
