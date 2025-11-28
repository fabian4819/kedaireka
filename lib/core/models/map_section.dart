import 'package:latlong2/latlong.dart';

class MapSectionBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  MapSectionBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  Map<String, dynamic> toJson() {
    return {
      'north': north,
      'south': south,
      'east': east,
      'west': west,
    };
  }

  factory MapSectionBounds.fromJson(Map<String, dynamic> json) {
    return MapSectionBounds(
      north: json['north'],
      south: json['south'],
      east: json['east'],
      west: json['west'],
    );
  }
}

class MapSection {
  final String id;
  final String name;
  final String description;
  final MapSectionBounds bounds;
  final String wmsUrl;
  final List<String> layers;
  final double area; // in square meters
  final String category; // e.g., 'cadastral', 'topographic', 'land_use'
  final DateTime lastUpdated;
  final bool isDownloaded;
  final String? localPath;

  MapSection({
    required this.id,
    required this.name,
    required this.description,
    required this.bounds,
    required this.wmsUrl,
    required this.layers,
    required this.area,
    required this.category,
    required this.lastUpdated,
    this.isDownloaded = false,
    this.localPath,
  });

  MapSection copyWith({
    String? id,
    String? name,
    String? description,
    MapSectionBounds? bounds,
    String? wmsUrl,
    List<String>? layers,
    double? area,
    String? category,
    DateTime? lastUpdated,
    bool? isDownloaded,
    String? localPath,
  }) {
    return MapSection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bounds: bounds ?? this.bounds,
      wmsUrl: wmsUrl ?? this.wmsUrl,
      layers: layers ?? this.layers,
      area: area ?? this.area,
      category: category ?? this.category,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'bounds': bounds.toJson(),
      'wmsUrl': wmsUrl,
      'layers': layers,
      'area': area,
      'category': category,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isDownloaded': isDownloaded,
      'localPath': localPath,
    };
  }

  factory MapSection.fromJson(Map<String, dynamic> json) {
    return MapSection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      bounds: MapSectionBounds.fromJson(json['bounds']),
      wmsUrl: json['wmsUrl'],
      layers: List<String>.from(json['layers']),
      area: json['area'],
      category: json['category'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isDownloaded: json['isDownloaded'] ?? false,
      localPath: json['localPath'],
    );
  }

  String get formattedArea {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(2)} m²';
    }
  }

  LatLng get center {
    return LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
  }
}
