/// Represents different types of locations in the navigation system
enum LocationType {
  room,
  hallway,
  entrance,
  elevator,
  stairs,
  restroom,
  office;

  /// Convert enum to string for JSON serialization
  String toJson() => name;

  /// Create enum from string for JSON deserialization
  static LocationType fromJson(String value) {
    return LocationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LocationType.room,
    );
  }
}

/// Represents geographical coordinates
class Coordinates {
  final double latitude;
  final double longitude;
  final double? altitude;

  const Coordinates({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  /// Create Coordinates from JSON
  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
    );
  }

  /// Convert Coordinates to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coordinates &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude);

  @override
  String toString() => 'Coordinates(lat: $latitude, lng: $longitude${altitude != null ? ', alt: $altitude' : ''})';
}

/// Represents a location in the navigation system
class Location {
  final String id;
  final String name;
  final String description;
  final Coordinates coordinates;
  final List<String> connectedLocationIds;
  final LocationType type;
  final Map<String, dynamic> metadata;
  final String? nfcTagSerial; // NFC tag serial number for this location

  const Location({
    required this.id,
    required this.name,
    required this.description,
    required this.coordinates,
    required this.connectedLocationIds,
    required this.type,
    this.metadata = const {},
    this.nfcTagSerial,
  });

  /// Create Location from JSON
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      coordinates: Coordinates.fromJson(json['coordinates'] as Map<String, dynamic>),
      connectedLocationIds: List<String>.from(json['connectedLocationIds'] as List),
      type: LocationType.fromJson(json['type'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      nfcTagSerial: json['nfcTagSerial'] as String?,
    );
  }

  /// Convert Location to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coordinates': coordinates.toJson(),
      'connectedLocationIds': connectedLocationIds,
      'type': type.toJson(),
      'metadata': metadata,
      if (nfcTagSerial != null) 'nfcTagSerial': nfcTagSerial,
    };
  }

  /// Create a copy of this location with updated fields
  Location copyWith({
    String? id,
    String? name,
    String? description,
    Coordinates? coordinates,
    List<String>? connectedLocationIds,
    LocationType? type,
    Map<String, dynamic>? metadata,
    String? nfcTagSerial,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coordinates: coordinates ?? this.coordinates,
      connectedLocationIds: connectedLocationIds ?? this.connectedLocationIds,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      nfcTagSerial: nfcTagSerial ?? this.nfcTagSerial,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.coordinates == coordinates &&
        _listEquals(other.connectedLocationIds, connectedLocationIds) &&
        other.type == type &&
        _mapEquals(other.metadata, metadata) &&
        other.nfcTagSerial == nfcTagSerial;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      coordinates,
      Object.hashAll(connectedLocationIds),
      type,
      Object.hashAll(metadata.entries.map((e) => Object.hash(e.key, e.value))),
      nfcTagSerial,
    );
  }

  @override
  String toString() => 'Location(id: $id, name: $name, type: $type)';

  /// Helper method to compare lists
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps
  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}