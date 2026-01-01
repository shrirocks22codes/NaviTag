import 'dart:math';
import '../models/location.dart';
import '../models/route.dart';
import '../repositories/location_repository.dart';

/// Enumeration of deviation severity levels
enum DeviationSeverity {
  none,     // On route
  minor,    // Close to route (< 50m)
  moderate, // Moderately off route (50-200m)
  major,    // Far from route (> 200m)
  unknown,  // Cannot determine
}

/// Abstract interface for route calculation operations
abstract class RouteCalculator {
  /// Calculate the optimal route between two locations
  Future<Route?> calculateRoute(String from, String to);
  
  /// Recalculate route from current location to destination
  Future<Route?> recalculateFromCurrent(String currentId, String destinationId);
  
  /// Generate navigation instructions for a route
  List<NavigationInstruction> getInstructions(Route route);
  
  /// Get the next instruction for current location on route
  NavigationInstruction? getNextInstruction(Route route, String currentLocationId);
  
  /// Check if two locations are connected (reachable)
  Future<bool> areLocationsConnected(String from, String to);
}

/// Implementation of RouteCalculator using Dijkstra's algorithm
class DijkstraRouteCalculator implements RouteCalculator {
  final LocationRepository _locationRepository;
  
  /// Average walking speed in meters per minute for time estimation
  static const double _walkingSpeedMPerMin = 80.0; // ~4.8 km/h
  
  DijkstraRouteCalculator(this._locationRepository);
  
  @override
  Future<Route?> calculateRoute(String from, String to) async {
    // Validate input locations exist
    final fromLocation = await _locationRepository.getLocationById(from);
    final toLocation = await _locationRepository.getLocationById(to);
    
    if (fromLocation == null || toLocation == null) {
      return null;
    }
    
    // Handle same location case
    if (from == to) {
      return _createSameLocationRoute(fromLocation);
    }
    
    // Get all locations to build the graph
    final allLocations = await _locationRepository.getAllLocations();
    final locationMap = {for (final loc in allLocations) loc.id: loc};
    
    // Run Dijkstra's algorithm
    final pathResult = await _dijkstraShortestPath(from, to, locationMap);
    
    if (pathResult == null) {
      return null; // No path found
    }
    
    // Build route from path result
    return _buildRouteFromPath(pathResult, locationMap);
  }
  
  @override
  Future<Route?> recalculateFromCurrent(String currentId, String destinationId) async {
    // Validate that both locations exist and are valid
    final currentLocation = await _locationRepository.getLocationById(currentId);
    final destinationLocation = await _locationRepository.getLocationById(destinationId);
    
    if (currentLocation == null || destinationLocation == null) {
      return null;
    }
    
    // Handle same location case
    if (currentId == destinationId) {
      return _createSameLocationRoute(currentLocation);
    }
    
    // For rerouting, we want to ensure we can actually reach the destination
    // Check if there's any path at all before doing expensive calculation
    final isReachable = await areLocationsConnected(currentId, destinationId);
    if (!isReachable) {
      return null;
    }
    
    // Calculate new route with rerouting flag for instruction generation
    final route = await calculateRoute(currentId, destinationId);
    
    if (route != null) {
      // Mark the first instruction as a reroute instruction
      final updatedInstructions = _markAsRerouteInstructions(route.instructions, currentId);
      
      return route.copyWith(
        instructions: updatedInstructions,
        id: 'reroute_${DateTime.now().millisecondsSinceEpoch}_${currentId}_to_$destinationId',
      );
    }
    
    return null;
  }

  /// Detect if current location represents a deviation from the planned route
  bool isLocationOffRoute(String currentLocationId, Route plannedRoute) {
    return !plannedRoute.containsLocation(currentLocationId);
  }

  /// Calculate deviation severity based on distance from planned route
  Future<DeviationSeverity> calculateDeviationSeverity(
    String currentLocationId, 
    Route plannedRoute,
  ) async {
    if (!isLocationOffRoute(currentLocationId, plannedRoute)) {
      return DeviationSeverity.none;
    }

    final currentLocation = await _locationRepository.getLocationById(currentLocationId);
    if (currentLocation == null) {
      return DeviationSeverity.unknown;
    }

    // Calculate minimum distance to any point on the planned route
    double minDistance = double.infinity;
    
    for (final routeLocationId in plannedRoute.pathLocationIds) {
      final routeLocation = await _locationRepository.getLocationById(routeLocationId);
      if (routeLocation != null) {
        final distance = _calculateDistance(
          currentLocation.coordinates,
          routeLocation.coordinates,
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    // Classify deviation severity based on distance
    if (minDistance < 50) { // Within 50 meters
      return DeviationSeverity.minor;
    } else if (minDistance < 200) { // Within 200 meters
      return DeviationSeverity.moderate;
    } else {
      return DeviationSeverity.major;
    }
  }

  /// Check if a location is directly reachable from another location
  Future<bool> isDirectlyReachable(String fromLocationId, String toLocationId) async {
    final fromLocation = await _locationRepository.getLocationById(fromLocationId);
    if (fromLocation == null) return false;
    
    return fromLocation.connectedLocationIds.contains(toLocationId);
  }

  /// Find alternative routes when primary route is blocked
  Future<List<Route>> findAlternativeRoutes(String fromId, String toId, {int maxAlternatives = 3}) async {
    final alternatives = <Route>[];
    
    // Get all locations to build the graph
    final allLocations = await _locationRepository.getAllLocations();
    final locationMap = {for (final loc in allLocations) loc.id: loc};
    
    // Try to find multiple paths using modified Dijkstra with path exclusion
    for (int attempt = 0; attempt < maxAlternatives; attempt++) {
      final excludedPaths = alternatives.map((route) => route.pathLocationIds).toList();
      final pathResult = await _dijkstraWithExclusion(fromId, toId, locationMap, excludedPaths);
      
      if (pathResult != null) {
        final route = _buildRouteFromPath(pathResult, locationMap);
        alternatives.add(route);
      } else {
        break; // No more alternative paths found
      }
    }
    
    return alternatives;
  }

  /// Mark instructions as reroute instructions for better user feedback
  List<NavigationInstruction> _markAsRerouteInstructions(
    List<NavigationInstruction> originalInstructions,
    String rerouteFromLocationId,
  ) {
    if (originalInstructions.isEmpty) return originalInstructions;
    
    final updatedInstructions = <NavigationInstruction>[];
    
    for (int i = 0; i < originalInstructions.length; i++) {
      final instruction = originalInstructions[i];
      
      if (i == 0 && instruction.fromLocationId == rerouteFromLocationId) {
        // Mark the first instruction as a reroute
        updatedInstructions.add(instruction.copyWith(
          type: InstructionType.reroute,
          description: 'Route recalculated. ${instruction.description}',
        ));
      } else {
        updatedInstructions.add(instruction);
      }
    }
    
    return updatedInstructions;
  }
  
  @override
  List<NavigationInstruction> getInstructions(Route route) {
    return List.from(route.instructions);
  }
  
  @override
  NavigationInstruction? getNextInstruction(Route route, String currentLocationId) {
    return route.getNextInstruction(currentLocationId);
  }
  
  @override
  Future<bool> areLocationsConnected(String from, String to) async {
    final route = await calculateRoute(from, to);
    return route != null;
  }
  
  /// Run Dijkstra's algorithm with path exclusion for alternative routes
  Future<_PathResult?> _dijkstraWithExclusion(
    String start,
    String end,
    Map<String, Location> locationMap,
    List<List<String>> excludedPaths,
  ) async {
    // For simplicity, we'll use a penalty system rather than complete exclusion
    // This allows finding truly alternative routes while still being practical
    
    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{};
    
    // Initialize all distances to infinity except start
    for (final locationId in locationMap.keys) {
      distances[locationId] = double.infinity;
      previous[locationId] = null;
      unvisited.add(locationId);
    }
    distances[start] = 0.0;
    
    while (unvisited.isNotEmpty) {
      // Find unvisited node with minimum distance
      String? current;
      double minDistance = double.infinity;
      
      for (final nodeId in unvisited) {
        final distance = distances[nodeId]!;
        if (distance < minDistance) {
          minDistance = distance;
          current = nodeId;
        }
      }
      
      // If no reachable unvisited nodes, break
      if (current == null || minDistance == double.infinity) {
        break;
      }
      
      // If we reached the destination, we can stop
      if (current == end) {
        break;
      }
      
      unvisited.remove(current);
      
      // Check all neighbors of current node
      final currentLocation = locationMap[current]!;
      for (final neighborId in currentLocation.connectedLocationIds) {
        if (!unvisited.contains(neighborId)) continue;
        
        final neighborLocation = locationMap[neighborId];
        if (neighborLocation == null) continue;
        
        // Calculate base distance between current and neighbor
        double edgeDistance = _calculateDistance(
          currentLocation.coordinates,
          neighborLocation.coordinates,
        );
        
        // Apply penalty if this edge is part of an excluded path
        for (final excludedPath in excludedPaths) {
          final currentIndex = excludedPath.indexOf(current);
          if (currentIndex >= 0 && 
              currentIndex < excludedPath.length - 1 && 
              excludedPath[currentIndex + 1] == neighborId) {
            edgeDistance *= 3.0; // 3x penalty for excluded edges
          }
        }
        
        final alternativeDistance = distances[current]! + edgeDistance;
        
        // If we found a shorter path, update it
        if (alternativeDistance < distances[neighborId]!) {
          distances[neighborId] = alternativeDistance;
          previous[neighborId] = current;
        }
      }
    }
    
    // If destination is unreachable
    if (distances[end] == double.infinity) {
      return null;
    }
    
    // Reconstruct path
    final path = <String>[];
    String? current = end;
    
    while (current != null) {
      path.insert(0, current);
      current = previous[current];
    }
    
    // Check if this path is significantly different from excluded paths
    bool isSufficientlyDifferent = true;
    for (final excludedPath in excludedPaths) {
      final commonNodes = path.where((node) => excludedPath.contains(node)).length;
      final similarity = commonNodes / max(path.length, excludedPath.length);
      if (similarity > 0.7) { // More than 70% similar
        isSufficientlyDifferent = false;
        break;
      }
    }
    
    if (!isSufficientlyDifferent) {
      return null; // Path too similar to existing ones
    }
    
    return _PathResult(
      path: path,
      totalDistance: distances[end]!,
    );
  }

  /// Run Dijkstra's algorithm to find shortest path
  Future<_PathResult?> _dijkstraShortestPath(
    String start,
    String end,
    Map<String, Location> locationMap,
  ) async {
    // For specific routes, force inclusion of intermediate checkpoints
    final forcedPath = _getForcedIntermediateCheckpoints(start, end);
    if (forcedPath != null) {
      return _calculatePathThroughWaypoints(start, end, forcedPath, locationMap);
    }
    
    // Initialize distances and previous nodes
    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{};
    
    // Initialize all distances to infinity except start
    for (final locationId in locationMap.keys) {
      distances[locationId] = double.infinity;
      previous[locationId] = null;
      unvisited.add(locationId);
    }
    distances[start] = 0.0;
    
    while (unvisited.isNotEmpty) {
      // Find unvisited node with minimum distance
      String? current;
      double minDistance = double.infinity;
      
      for (final nodeId in unvisited) {
        final distance = distances[nodeId]!;
        if (distance < minDistance) {
          minDistance = distance;
          current = nodeId;
        }
      }
      
      // If no reachable unvisited nodes, break
      if (current == null || minDistance == double.infinity) {
        break;
      }
      
      // If we reached the destination, we can stop
      if (current == end) {
        break;
      }
      
      unvisited.remove(current);
      
      // Check all neighbors of current node
      final currentLocation = locationMap[current]!;
      for (final neighborId in currentLocation.connectedLocationIds) {
        if (!unvisited.contains(neighborId)) continue;
        
        final neighborLocation = locationMap[neighborId];
        if (neighborLocation == null) continue;
        
        // Calculate distance between current and neighbor
        final edgeDistance = _calculateDistance(
          currentLocation.coordinates,
          neighborLocation.coordinates,
        );
        
        final alternativeDistance = distances[current]! + edgeDistance;
        
        // If we found a shorter path, update it
        if (alternativeDistance < distances[neighborId]!) {
          distances[neighborId] = alternativeDistance;
          previous[neighborId] = current;
        }
      }
    }
    
    // If destination is unreachable
    if (distances[end] == double.infinity) {
      return null;
    }
    
    // Reconstruct path
    final path = <String>[];
    String? current = end;
    
    while (current != null) {
      path.insert(0, current);
      current = previous[current];
    }
    
    return _PathResult(
      path: path,
      totalDistance: distances[end]!,
    );
  }
  
  /// Get forced intermediate checkpoints for specific routes
  List<String>? _getForcedIntermediateCheckpoints(String start, String end) {
    // Force CPA for routes between CP2 and CP3 (and vice versa)
    if ((start == 'CP2' && end == 'CP3') || (start == 'CP3' && end == 'CP2')) {
      return ['CPA'];
    }
    
    // Force CP9 for routes to/from Cafeteria that go through CP2
    if ((start == 'CP2' && end == 'Cafeteria') || (start == 'Cafeteria' && end == 'CP2')) {
      return ['CP9'];
    }
    
    // Force CP10 for routes to/from Media Center that go through CP3
    if ((start == 'CP3' && end == 'Media Center') || (start == 'Media Center' && end == 'CP3')) {
      return ['CP10'];
    }
    
    // For longer routes, check if they should include these checkpoints
    if (_shouldRouteIncludeCPA(start, end)) {
      return ['CPA'];
    }
    
    if (_shouldRouteIncludeCP9(start, end)) {
      return ['CP9'];
    }
    
    if (_shouldRouteIncludeCP10(start, end)) {
      return ['CP10'];
    }
    
    return null;
  }
  
  /// Check if route should include CPA
  bool _shouldRouteIncludeCPA(String start, String end) {
    // Routes that logically go through the CP2-CP3 corridor should include CPA
    final cp2ConnectedAreas = ['Gym', 'CP1', 'Bus Entrance'];
    final cp3ConnectedAreas = ['7 Red/7 Gold', 'CP11'];
    
    final startNearCP2 = cp2ConnectedAreas.contains(start) || start == 'CP2';
    final endNearCP3 = cp3ConnectedAreas.contains(end) || end == 'CP3';
    final startNearCP3 = cp3ConnectedAreas.contains(start) || start == 'CP3';
    final endNearCP2 = cp2ConnectedAreas.contains(end) || end == 'CP2';
    
    return (startNearCP2 && endNearCP3) || (startNearCP3 && endNearCP2);
  }
  
  /// Check if route should include CP9
  bool _shouldRouteIncludeCP9(String start, String end) {
    // Routes to/from Cafeteria should include CP9
    return start == 'Cafeteria' || end == 'Cafeteria';
  }
  
  /// Check if route should include CP10
  bool _shouldRouteIncludeCP10(String start, String end) {
    // Routes to/from Media Center should include CP10
    return start == 'Media Center' || end == 'Media Center';
  }
  
  /// Calculate path through specific waypoints
  Future<_PathResult?> _calculatePathThroughWaypoints(
    String start,
    String end,
    List<String> waypoints,
    Map<String, Location> locationMap,
  ) async {
    final fullPath = [start, ...waypoints, end];
    final pathSegments = <String>[];
    double totalDistance = 0.0;
    
    // Calculate path through each segment
    for (int i = 0; i < fullPath.length - 1; i++) {
      final segmentStart = fullPath[i];
      final segmentEnd = fullPath[i + 1];
      
      // Calculate segment using regular Dijkstra
      final segmentResult = await _dijkstraShortestPath(segmentStart, segmentEnd, locationMap);
      if (segmentResult == null) {
        return null; // Cannot reach waypoint
      }
      
      // Add segment to path (skip duplicate waypoints)
      if (pathSegments.isEmpty) {
        pathSegments.addAll(segmentResult.path);
      } else {
        pathSegments.addAll(segmentResult.path.skip(1)); // Skip first element to avoid duplication
      }
      
      totalDistance += segmentResult.totalDistance;
    }
    
    return _PathResult(
      path: pathSegments,
      totalDistance: totalDistance,
    );
  }
  
  /// Build a Route object from path result
  Route _buildRouteFromPath(_PathResult pathResult, Map<String, Location> locationMap) {
    final path = pathResult.path;
    final totalDistance = pathResult.totalDistance;
    
    // Generate unique route ID
    final routeId = 'route_${DateTime.now().millisecondsSinceEpoch}';
    
    // Calculate estimated time based on distance
    // For indoor navigation, ensure minimum time based on number of checkpoints
    final baseTimeMinutes = (totalDistance / _walkingSpeedMPerMin);
    final checkpointTimeMinutes = (path.length - 1) * 0.5; // 30 seconds per checkpoint
    final estimatedTimeMinutes = baseTimeMinutes + checkpointTimeMinutes; // Remove minimum clamp
    
    final estimatedTime = Duration(
      milliseconds: (estimatedTimeMinutes * 60 * 1000).round(),
    );
    
    // Generate navigation instructions
    final instructions = _generateInstructions(path, locationMap);
    
    return Route(
      id: routeId,
      startLocationId: path.first,
      endLocationId: path.last,
      pathLocationIds: path,
      estimatedDistance: totalDistance,
      estimatedTime: estimatedTime,
      instructions: instructions,
    );
  }
  
  /// Generate navigation instructions for a path
  List<NavigationInstruction> _generateInstructions(
    List<String> path,
    Map<String, Location> locationMap,
  ) {
    final instructions = <NavigationInstruction>[];
    
    if (path.length < 2) {
      return instructions;
    }
    
    for (int i = 0; i < path.length - 1; i++) {
      final fromId = path[i];
      final toId = path[i + 1];
      final fromLocation = locationMap[fromId]!;
      final toLocation = locationMap[toId]!;
      
      final distance = _calculateDistance(
        fromLocation.coordinates,
        toLocation.coordinates,
      );
      
      InstructionType type;
      Direction direction;
      String description;
      
      if (i == 0 && i == path.length - 2) {
        // Single hop route (direct connection) - this is both start and destination
        type = InstructionType.destination;
        direction = Direction.forward;
        description = 'Go directly to ${toLocation.name}';
      } else if (i == 0) {
        // Start instruction
        type = InstructionType.start;
        direction = Direction.forward;
        description = 'Start at ${fromLocation.name}';
      } else if (i == path.length - 2) {
        // Destination instruction
        type = InstructionType.destination;
        direction = Direction.forward;
        description = 'Arrive at ${toLocation.name}';
      } else {
        // Turn or straight instruction
        type = InstructionType.straight;
        direction = _calculateDirection(path, i, locationMap);
        description = _generateInstructionDescription(direction, toLocation.name);
      }
      
      instructions.add(NavigationInstruction(
        id: 'instruction_${i}_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        description: description,
        fromLocationId: fromId,
        toLocationId: toId,
        direction: direction,
        distance: distance,
      ));
    }
    
    return instructions;
  }
  
  /// Calculate direction based on path geometry
  Direction _calculateDirection(
    List<String> path,
    int currentIndex,
    Map<String, Location> locationMap,
  ) {
    // For simplicity, we'll determine direction based on location types
    // In a real implementation, this would use coordinate geometry
    
    final currentLocation = locationMap[path[currentIndex]]!;
    final nextLocation = locationMap[path[currentIndex + 1]]!;
    
    // Simple heuristic based on location types
    if (nextLocation.type == LocationType.elevator || 
        nextLocation.type == LocationType.stairs) {
      return Direction.up; // Assume going up for elevators/stairs
    }
    
    if (currentLocation.type == LocationType.elevator || 
        currentLocation.type == LocationType.stairs) {
      return Direction.down; // Coming down from elevators/stairs
    }
    
    // Default to forward for hallways and rooms
    return Direction.forward;
  }
  
  /// Generate instruction description based on direction
  String _generateInstructionDescription(Direction direction, String locationName) {
    switch (direction) {
      case Direction.forward:
        return 'Continue straight to $locationName';
      case Direction.left:
        return 'Turn left to $locationName';
      case Direction.right:
        return 'Turn right to $locationName';
      case Direction.back:
        return 'Turn around to $locationName';
      case Direction.up:
        return 'Go up to $locationName';
      case Direction.down:
        return 'Go down to $locationName';
    }
  }
  
  /// Create a route for same start and end location
  Route _createSameLocationRoute(Location location) {
    final routeId = 'route_same_${DateTime.now().millisecondsSinceEpoch}';
    
    return Route(
      id: routeId,
      startLocationId: location.id,
      endLocationId: location.id,
      pathLocationIds: [location.id],
      estimatedDistance: 0.0,
      estimatedTime: const Duration(seconds: 0), // No time needed for same location
      instructions: [
        NavigationInstruction(
          id: 'instruction_same_${DateTime.now().millisecondsSinceEpoch}',
          type: InstructionType.destination,
          description: 'You are already at ${location.name}',
          fromLocationId: location.id,
          toLocationId: location.id,
          direction: Direction.forward,
          distance: 0.0,
        ),
      ],
    );
  }
  
  /// Calculate distance between two coordinates using Euclidean distance for indoor maps
  double _calculateDistance(Coordinates from, Coordinates to) {
    // For indoor maps with converted pixel coordinates, use Euclidean distance
    // Convert back to approximate pixel coordinates for more accurate indoor distances
    const double baseLatitude = 40.7128;
    const double baseLongitude = -74.0060;
    const double latScale = 0.0001;
    const double lngScale = 0.0001;
    
    // Convert coordinates back to pixel space
    final fromX = (from.longitude - baseLongitude) / lngScale * 1615.0;
    final fromY = (from.latitude - baseLatitude) / latScale * 1255.0;
    final toX = (to.longitude - baseLongitude) / lngScale * 1615.0;
    final toY = (to.latitude - baseLatitude) / latScale * 1255.0;
    
    // Calculate Euclidean distance in pixels
    final pixelDistance = sqrt(pow(toX - fromX, 2) + pow(toY - fromY, 2));
    
    // Convert pixels to meters (assuming 1 pixel ≈ 0.5 meters for indoor navigation)
    const double pixelsToMeters = 0.5;
    
    return pixelDistance * pixelsToMeters;
  }
}

/// Internal class to hold path calculation results
class _PathResult {
  final List<String> path;
  final double totalDistance;
  
  _PathResult({
    required this.path,
    required this.totalDistance,
  });
}
