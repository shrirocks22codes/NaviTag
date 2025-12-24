/// Represents different types of navigation instructions
enum InstructionType {
  start,
  turn,
  straight,
  destination,
  reroute;

  /// Convert enum to string for JSON serialization
  String toJson() => name;

  /// Create enum from string for JSON deserialization
  static InstructionType fromJson(String value) {
    return InstructionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => InstructionType.straight,
    );
  }
}

/// Represents different directions for navigation
enum Direction {
  forward,
  left,
  right,
  back,
  up,
  down;

  /// Convert enum to string for JSON serialization
  String toJson() => name;

  /// Create enum from string for JSON deserialization
  static Direction fromJson(String value) {
    return Direction.values.firstWhere(
      (direction) => direction.name == value,
      orElse: () => Direction.forward,
    );
  }
}

/// Represents a single navigation instruction
class NavigationInstruction {
  final String id;
  final InstructionType type;
  final String description;
  final String fromLocationId;
  final String toLocationId;
  final Direction direction;
  final double distance;

  const NavigationInstruction({
    required this.id,
    required this.type,
    required this.description,
    required this.fromLocationId,
    required this.toLocationId,
    required this.direction,
    required this.distance,
  });

  /// Create NavigationInstruction from JSON
  factory NavigationInstruction.fromJson(Map<String, dynamic> json) {
    return NavigationInstruction(
      id: json['id'] as String,
      type: InstructionType.fromJson(json['type'] as String),
      description: json['description'] as String,
      fromLocationId: json['fromLocationId'] as String,
      toLocationId: json['toLocationId'] as String,
      direction: Direction.fromJson(json['direction'] as String),
      distance: (json['distance'] as num).toDouble(),
    );
  }

  /// Convert NavigationInstruction to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toJson(),
      'description': description,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
      'direction': direction.toJson(),
      'distance': distance,
    };
  }

  /// Create a copy of this instruction with updated fields
  NavigationInstruction copyWith({
    String? id,
    InstructionType? type,
    String? description,
    String? fromLocationId,
    String? toLocationId,
    Direction? direction,
    double? distance,
  }) {
    return NavigationInstruction(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      fromLocationId: fromLocationId ?? this.fromLocationId,
      toLocationId: toLocationId ?? this.toLocationId,
      direction: direction ?? this.direction,
      distance: distance ?? this.distance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationInstruction &&
        other.id == id &&
        other.type == type &&
        other.description == description &&
        other.fromLocationId == fromLocationId &&
        other.toLocationId == toLocationId &&
        other.direction == direction &&
        other.distance == distance;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      description,
      fromLocationId,
      toLocationId,
      direction,
      distance,
    );
  }

  @override
  String toString() => 'NavigationInstruction(id: $id, type: $type, description: $description)';
}

/// Represents a complete route between two locations
class Route {
  final String id;
  final String startLocationId;
  final String endLocationId;
  final List<String> pathLocationIds;
  final double estimatedDistance;
  final Duration estimatedTime;
  final List<NavigationInstruction> instructions;

  const Route({
    required this.id,
    required this.startLocationId,
    required this.endLocationId,
    required this.pathLocationIds,
    required this.estimatedDistance,
    required this.estimatedTime,
    required this.instructions,
  });

  /// Create Route from JSON
  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String,
      startLocationId: json['startLocationId'] as String,
      endLocationId: json['endLocationId'] as String,
      pathLocationIds: List<String>.from(json['pathLocationIds'] as List),
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      estimatedTime: Duration(milliseconds: json['estimatedTimeMs'] as int),
      instructions: (json['instructions'] as List)
          .map((instructionJson) => NavigationInstruction.fromJson(instructionJson as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert Route to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startLocationId': startLocationId,
      'endLocationId': endLocationId,
      'pathLocationIds': pathLocationIds,
      'estimatedDistance': estimatedDistance,
      'estimatedTimeMs': estimatedTime.inMilliseconds,
      'instructions': instructions.map((instruction) => instruction.toJson()).toList(),
    };
  }

  /// Validate that the route is properly formed
  bool isValid() {
    // Basic validation checks
    if (pathLocationIds.isEmpty) return false;
    if (pathLocationIds.first != startLocationId) return false;
    if (pathLocationIds.last != endLocationId) return false;
    if (estimatedDistance < 0) return false;
    if (estimatedTime.isNegative) return false;
    
    // Validate instructions match the path
    if (instructions.isEmpty && pathLocationIds.length > 1) return false;
    
    return true;
  }

  /// Calculate the total distance from all instructions
  double calculateTotalDistance() {
    return instructions.fold(0.0, (sum, instruction) => sum + instruction.distance);
  }

  /// Get the next instruction based on current location
  NavigationInstruction? getNextInstruction(String currentLocationId) {
    for (final instruction in instructions) {
      if (instruction.fromLocationId == currentLocationId) {
        return instruction;
      }
    }
    return null;
  }

  /// Check if a location is on this route
  bool containsLocation(String locationId) {
    return pathLocationIds.contains(locationId);
  }

  /// Get the index of a location in the path
  int getLocationIndex(String locationId) {
    return pathLocationIds.indexOf(locationId);
  }

  /// Create a copy of this route with updated fields
  Route copyWith({
    String? id,
    String? startLocationId,
    String? endLocationId,
    List<String>? pathLocationIds,
    double? estimatedDistance,
    Duration? estimatedTime,
    List<NavigationInstruction>? instructions,
  }) {
    return Route(
      id: id ?? this.id,
      startLocationId: startLocationId ?? this.startLocationId,
      endLocationId: endLocationId ?? this.endLocationId,
      pathLocationIds: pathLocationIds ?? this.pathLocationIds,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      instructions: instructions ?? this.instructions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Route &&
        other.id == id &&
        other.startLocationId == startLocationId &&
        other.endLocationId == endLocationId &&
        _listEquals(other.pathLocationIds, pathLocationIds) &&
        other.estimatedDistance == estimatedDistance &&
        other.estimatedTime == estimatedTime &&
        _listEquals(other.instructions, instructions);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      startLocationId,
      endLocationId,
      Object.hashAll(pathLocationIds),
      estimatedDistance,
      estimatedTime,
      Object.hashAll(instructions),
    );
  }

  @override
  String toString() => 'Route(id: $id, from: $startLocationId, to: $endLocationId, distance: ${estimatedDistance}m)';

  /// Helper method to compare lists
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}