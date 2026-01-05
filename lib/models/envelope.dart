// lib/models/envelope.dart

class Wall {
  final String orientation;
  final String type;
  final double uValue;
  final double area;
  final bool insulation;

  Wall({
    required this.orientation,
    required this.type,
    required this.uValue,
    required this.area,
    required this.insulation,
  });

  factory Wall.fromJson(Map<String, dynamic> json) => Wall(
    orientation: json['orientation'] as String,
    type: json['type'] as String,
    uValue: (json['uValue'] as num).toDouble(),
    area: (json['area'] as num).toDouble(),
    insulation: json['insulation'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'orientation': orientation,
    'type': type,
    'uValue': uValue,
    'area': area,
    'insulation': insulation,
  };
}

class Roof {
  final String type;
  final double uValue;
  final double area;
  final bool insulation;

  Roof({
    required this.type,
    required this.uValue,
    required this.area,
    required this.insulation,
  });

  factory Roof.fromJson(Map<String, dynamic> json) => Roof(
    type: json['type'] as String,
    uValue: (json['uValue'] as num).toDouble(),
    area: (json['area'] as num).toDouble(),
    insulation: json['insulation'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'uValue': uValue,
    'area': area,
    'insulation': insulation,
  };
}

class FloorSurface {
  final String type;
  final double uValue;
  final double area;
  final bool insulated;

  FloorSurface({
    required this.type,
    required this.uValue,
    required this.area,
    required this.insulated,
  });

  factory FloorSurface.fromJson(Map<String, dynamic> json) => FloorSurface(
    type: json['type'] as String,
    uValue: (json['uValue'] as num).toDouble(),
    area: (json['area'] as num).toDouble(),
    insulated: json['insulated'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'uValue': uValue,
    'area': area,
    'insulated': insulated,
  };
}

class WindowElement {
  final String orientation;
  final int year;
  final String frame;
  final String glazing;
  final double uValue;
  final double area;

  WindowElement({
    required this.orientation,
    required this.year,
    required this.frame,
    required this.glazing,
    required this.uValue,
    required this.area,
  });

  factory WindowElement.fromJson(Map<String, dynamic> json) => WindowElement(
    orientation: json['orientation'] as String,
    year: json['year'] as int,
    frame: json['frame'] as String,
    glazing: json['glazing'] as String,
    uValue: (json['uValue'] as num).toDouble(),
    area: (json['area'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'orientation': orientation,
    'year': year,
    'frame': frame,
    'glazing': glazing,
    'uValue': uValue,
    'area': area,
  };
}

class Envelope {
  final List<Wall> walls;
  final Roof roof;
  final FloorSurface floor;
  final List<WindowElement> windows;

  Envelope({
    required this.walls,
    required this.roof,
    required this.floor,
    required this.windows,
  });

  factory Envelope.fromJson(Map<String, dynamic> json) => Envelope(
    walls: (json['walls'] as List<dynamic>)
        .map((e) => Wall.fromJson(e as Map<String, dynamic>))
        .toList(),
    roof: Roof.fromJson(json['roof'] as Map<String, dynamic>),
    floor: FloorSurface.fromJson(json['floor'] as Map<String, dynamic>),
    windows: (json['windows'] as List<dynamic>)
        .map((e) => WindowElement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'walls': walls.map((w) => w.toJson()).toList(),
    'roof': roof.toJson(),
    'floor': floor.toJson(),
    'windows': windows.map((w) => w.toJson()).toList(),
  };
}
