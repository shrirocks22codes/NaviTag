import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';
import '../models/route.dart';
import '../models/nfc_tag_data.dart';
import '../services/nfc_service.dart';
import '../repositories/location_repository.dart';

/// Enumeration of deviation severity levels
enum DeviationSeverity {
  none,     // On route
  minor,    // Close to route (< 50m)
  moderate, // Moderately off route (50-200m)
  major,    // Far from route (> 200m)
  unknown,  // Cannot determine
}

/// Enumeration of navigation states
enum NavigationState {
  idle,
  selectingDestination,
  calculating,
  navigating,
  arrived,
  error,
}

/// Represents the current navigation session data
class NavigationSession {
  final String? currentLocationId;
  final String? destinationLocationId;
  final Route? activeRoute;
  final NavigationState state;
  final String? errorMessage;
  final NavigationInstruction? currentInstruction;
  final int currentStepIndex;

  const NavigationSession({
    this.currentLocationId,
    this.destinationLocationId,
    this.activeRoute,
    this.state = NavigationState.idle,
    this.errorMessage,
    this.currentInstruction,
    this.currentStepIndex = 0,
  });

  /// Create a copy with updated fields
  NavigationSession copyWith({
    String? currentLocationId,
    String? destinationLocationId,
    Route? activeRoute,
    NavigationState? state,
    String? errorMessage,
    NavigationInstruction? currentInstruction,
    int? currentStepIndex,
  }) {
    return NavigationSession(
      currentLocationId: currentLocationId ?? this.currentLocationId,
      destinationLocationId: destinationLocationId ?? this.destinationLocationId,
      activeRoute: activeRoute ?? this.activeRoute,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      currentInstruction: currentInstruction ?? this.currentInstruction,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }

  /// Clear error state
  NavigationSession clearError() {
    return copyWith(
      state: NavigationState.idle,
      errorMessage: null,
    );
  }

  /// Check if navigation is active
  bool get isNavigating => state == NavigationState.navigating;

  /// Check if there's an active route
  bool get hasActiveRoute => activeRoute != null;

  /// Check if current location is set
  bool get hasCurrentLocation => currentLocationId != null;

  /// Check if destination is set
  bool get hasDestination => destinationLocationId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationSession &&
        other.currentLocationId == currentLocationId &&
        other.destinationLocationId == destinationLocationId &&
        other.activeRoute == activeRoute &&
        other.state == state &&
        other.errorMessage == errorMessage &&
        other.currentInstruction == currentInstruction &&
        other.currentStepIndex == currentStepIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      currentLocationId,
      destinationLocationId,
      activeRoute,
      state,
      errorMessage,
      currentInstruction,
      currentStepIndex,
    );
  }

  @override
  String toString() => 'NavigationSession(state: $state, current: $currentLocationId, destination: $destinationLocationId)';
}

/// Abstract interface for route calculation
abstract class RouteCalculator {
  Future<Route?> calculateRoute(String from, String to);
  Future<Route?> recalculateFromCurrent(String currentId, String destinationId);
  List<NavigationInstruction> getInstructions(Route route);
  NavigationInstruction? getNextInstruction(Route route, String currentLocationId);
}

/// Simple implementation of route calculator using basic pathfinding
class SimpleRouteCalculator implements RouteCalculator {
  final LocationRepository _locationRepository;

  SimpleRouteCalculator(this._locationRepository);

  @override
  Future<Route?> calculateRoute(String from, String to) async {
    if (from == to) {
      return null; // Same location
    }

    final startLocation = await _locationRepository.getLocationById(from);
    final endLocation = await _locationRepository.getLocationById(to);

    if (startLocation == null || endLocation == null) {
      return null; // Invalid locations
    }

    // Simple pathfinding using BFS
    final path = await _findPath(from, to);
    if (path == null || path.isEmpty) {
      return null; // No path found
    }

    // Calculate distance and time estimates
    final distance = await _calculatePathDistance(path);
    final estimatedTime = Duration(seconds: (distance * 2).round()); // 2 seconds per meter

    // Generate instructions
    final instructions = await _generateInstructions(path);

    return Route(
      id: '${from}_to_${to}_${DateTime.now().millisecondsSinceEpoch}',
      startLocationId: from,
      endLocationId: to,
      pathLocationIds: path,
      estimatedDistance: distance,
      estimatedTime: estimatedTime,
      instructions: instructions,
    );
  }

  @override
  Future<Route?> recalculateFromCurrent(String currentId, String destinationId) async {
    return calculateRoute(currentId, destinationId);
  }

  @override
  List<NavigationInstruction> getInstructions(Route route) {
    return route.instructions;
  }

  @override
  NavigationInstruction? getNextInstruction(Route route, String currentLocationId) {
    return route.getNextInstruction(currentLocationId);
  }

  /// Find path between two locations using BFS
  Future<List<String>?> _findPath(String from, String to) async {
    final visited = <String>{};
    final queue = <List<String>>[];
    
    queue.add([from]);
    visited.add(from);

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      if (current == to) {
        return path;
      }

      final connectedLocations = await _locationRepository.getConnectedLocations(current);
      for (final location in connectedLocations) {
        if (!visited.contains(location.id)) {
          visited.add(location.id);
          queue.add([...path, location.id]);
        }
      }
    }

    return null; // No path found
  }

  /// Calculate total distance for a path
  Future<double> _calculatePathDistance(List<String> path) async {
    double totalDistance = 0.0;
    
    for (int i = 0; i < path.length - 1; i++) {
      final from = await _locationRepository.getLocationById(path[i]);
      final to = await _locationRepository.getLocationById(path[i + 1]);
      
      if (from != null && to != null) {
        // Simple distance calculation (in a real app, this would be more sophisticated)
        totalDistance += _calculateDistance(from.coordinates, to.coordinates);
      }
    }
    
    return totalDistance;
  }

  /// Calculate distance between two coordinates (simplified)
  double _calculateDistance(Coordinates from, Coordinates to) {
    // Simple Euclidean distance for indoor navigation
    final dx = to.latitude - from.latitude;
    final dy = to.longitude - from.longitude;
    return (dx * dx + dy * dy) * 111000; // Rough conversion to meters
  }

  /// Generate navigation instructions for a path
  Future<List<NavigationInstruction>> _generateInstructions(List<String> path) async {
    final instructions = <NavigationInstruction>[];
    
    for (int i = 0; i < path.length - 1; i++) {
      final fromId = path[i];
      final toId = path[i + 1];
      final from = await _locationRepository.getLocationById(fromId);
      final to = await _locationRepository.getLocationById(toId);
      
      if (from != null && to != null) {
        final distance = _calculateDistance(from.coordinates, to.coordinates);
        
        InstructionType type;
        String description;
        
        if (i == 0) {
          type = InstructionType.start;
          description = 'Start at ${from.name}';
        } else if (i == path.length - 2) {
          type = InstructionType.destination;
          description = 'Arrive at ${to.name}';
        } else {
          type = InstructionType.straight;
          description = 'Continue to ${to.name}';
        }
        
        instructions.add(NavigationInstruction(
          id: '${fromId}_to_$toId',
          type: type,
          description: description,
          fromLocationId: fromId,
          toLocationId: toId,
          direction: Direction.forward,
          distance: distance,
        ));
      }
    }
    
    return instructions;
  }
}

/// Navigation controller that manages the navigation state and coordinates services
class NavigationController extends StateNotifier<NavigationSession> {
  final NFCService _nfcService;
  final LocationRepository _locationRepository;
  final RouteCalculator _routeCalculator;
  
  StreamSubscription<NFCTagData>? _nfcSubscription;
  
  NavigationController({
    required NFCService nfcService,
    required LocationRepository locationRepository,
    required RouteCalculator routeCalculator,
  }) : _nfcService = nfcService,
       _locationRepository = locationRepository,
       _routeCalculator = routeCalculator,
       super(const NavigationSession()) {
    _initializeNFCListener();
  }

  /// Initialize NFC tag listener
  void _initializeNFCListener() {
    _nfcSubscription = _nfcService.tagStream.listen(
      _handleNFCTagDetected,
      onError: _handleNFCError,
    );
  }

  /// Handle NFC tag detection
  Future<void> _handleNFCTagDetected(NFCTagData tagData) async {
    try {
      // Validate the location exists
      final isValid = await _locationRepository.isValidLocation(tagData.locationId);
      if (!isValid) {
        _setError('Invalid location detected: ${tagData.locationId}');
        return;
      }

      final previousLocationId = state.currentLocationId;
      
      // Update current location
      state = state.copyWith(
        currentLocationId: tagData.locationId,
        errorMessage: null,
      );

      // If we're navigating, check for route deviation
      if (state.isNavigating && state.activeRoute != null) {
        await _handleNavigationUpdate(tagData.locationId, previousLocationId);
      }
    } catch (e) {
      _setError('Failed to process NFC tag: $e');
    }
  }

  /// Handle NFC scanning errors
  void _handleNFCError(dynamic error) {
    _setError('NFC scanning error: $error');
  }

  /// Handle navigation updates when a new location is detected
  Future<void> _handleNavigationUpdate(String newLocationId, String? previousLocationId) async {
    final route = state.activeRoute!;
    
    // Check if the new location is on the planned route
    if (route.containsLocation(newLocationId)) {
      await _handleOnRouteUpdate(newLocationId, route);
    } else {
      // Route deviation detected - validate and handle appropriately
      await _handleRouteDeviation(newLocationId, previousLocationId, route);
    }
  }

  /// Handle route deviation with comprehensive validation and rerouting
  Future<void> _handleRouteDeviation(String newLocationId, String? previousLocationId, Route currentRoute) async {
    // First, validate that this is a legitimate location transition
    if (previousLocationId != null) {
      final isValidTransition = await _validateLocationTransition(previousLocationId, newLocationId);
      if (!isValidTransition) {
        _setError('Invalid location transition detected. Please scan a valid NFC tag.');
        return;
      }
    }

    // Calculate deviation severity to determine response
    final deviationSeverity = await _calculateDeviationSeverity(newLocationId, currentRoute);
    
    // Handle based on severity
    switch (deviationSeverity) {
      case DeviationSeverity.none:
        // This shouldn't happen since we already checked containsLocation
        await _handleOnRouteUpdate(newLocationId, currentRoute);
        break;
        
      case DeviationSeverity.minor:
        // Minor deviation - try to get back on route quickly
        await _handleMinorDeviation(newLocationId, currentRoute);
        break;
        
      case DeviationSeverity.moderate:
      case DeviationSeverity.major:
        // Significant deviation - full rerouting required
        await _handleSignificantDeviation(newLocationId, currentRoute);
        break;
        
      case DeviationSeverity.unknown:
        // Cannot determine - treat as moderate deviation
        await _handleSignificantDeviation(newLocationId, currentRoute);
        break;
    }
  }

  /// Validate that a location transition is physically possible
  Future<bool> _validateLocationTransition(String fromLocationId, String toLocationId) async {
    try {
      // Check direct connectivity
      final fromLocation = await _locationRepository.getLocationById(fromLocationId);
      if (fromLocation == null) return false;
      
      // Allow direct connections
      if (fromLocation.connectedLocationIds.contains(toLocationId)) {
        return true;
      }
      
      // Allow transitions within reasonable distance (for cases where connectivity data might be incomplete)
      final toLocation = await _locationRepository.getLocationById(toLocationId);
      if (toLocation == null) return false;
      
      final distance = _calculateDistance(fromLocation.coordinates, toLocation.coordinates);
      return distance <= 100.0; // Allow transitions within 100 meters
      
    } catch (e) {
      // If validation fails, assume transition is valid to avoid blocking navigation
      return true;
    }
  }

  /// Calculate deviation severity for the current location
  Future<DeviationSeverity> _calculateDeviationSeverity(String currentLocationId, Route route) async {
    final currentLocation = await _locationRepository.getLocationById(currentLocationId);
    if (currentLocation == null) {
      return DeviationSeverity.unknown;
    }

    // Calculate minimum distance to any point on the planned route
    double minDistance = double.infinity;
    
    for (final routeLocationId in route.pathLocationIds) {
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

  /// Handle minor deviations by finding quick path back to route
  Future<void> _handleMinorDeviation(String currentLocationId, Route originalRoute) async {
    try {
      // Try to find a quick path back to the original route
      final nearestRouteLocation = await _findNearestRouteLocation(currentLocationId, originalRoute);
      
      if (nearestRouteLocation != null) {
        // Calculate a short route back to the main route
        final returnRoute = await _routeCalculator.calculateRoute(currentLocationId, nearestRouteLocation);
        
        if (returnRoute != null && returnRoute.estimatedDistance < 100) {
          // Create a combined route: return to route + continue on original route
          final combinedRoute = await _createCombinedRoute(returnRoute, originalRoute, nearestRouteLocation);
          
          if (combinedRoute != null) {
            await _applyNewRoute(combinedRoute, isMinorReroute: true);
            return;
          }
        }
      }
      
      // If quick return fails, fall back to full rerouting
      await _handleSignificantDeviation(currentLocationId, originalRoute);
      
    } catch (e) {
      // If minor deviation handling fails, fall back to significant deviation handling
      await _handleSignificantDeviation(currentLocationId, originalRoute);
    }
  }

  /// Handle significant deviations with full rerouting
  Future<void> _handleSignificantDeviation(String currentLocationId, Route originalRoute) async {
    if (state.destinationLocationId == null) return;
    
    try {
      // Set state to calculating to show user that rerouting is happening
      state = state.copyWith(state: NavigationState.calculating);
      
      // Calculate new route from current position to original destination
      final newRoute = await _routeCalculator.recalculateFromCurrent(
        currentLocationId,
        state.destinationLocationId!,
      );
      
      if (newRoute != null && newRoute.isValid()) {
        await _applyNewRoute(newRoute, isMinorReroute: false);
      } else {
        // No route found from current position
        await _handleUnreachableDestination(currentLocationId);
      }
    } catch (e) {
      _setError('Route recalculation failed: $e');
    }
  }

  /// Find the nearest location on the original route
  Future<String?> _findNearestRouteLocation(String currentLocationId, Route route) async {
    final currentLocation = await _locationRepository.getLocationById(currentLocationId);
    if (currentLocation == null) return null;

    String? nearestLocationId;
    double minDistance = double.infinity;

    for (final routeLocationId in route.pathLocationIds) {
      final routeLocation = await _locationRepository.getLocationById(routeLocationId);
      if (routeLocation != null) {
        final distance = _calculateDistance(
          currentLocation.coordinates,
          routeLocation.coordinates,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestLocationId = routeLocationId;
        }
      }
    }

    return nearestLocationId;
  }

  /// Create a combined route that returns to the original route and continues
  Future<Route?> _createCombinedRoute(Route returnRoute, Route originalRoute, String rejoinLocationId) async {
    try {
      // Find the index where we rejoin the original route
      final rejoinIndex = originalRoute.getLocationIndex(rejoinLocationId);
      if (rejoinIndex == -1) return null;

      // Create the combined path
      final combinedPath = <String>[
        ...returnRoute.pathLocationIds,
        ...originalRoute.pathLocationIds.skip(rejoinIndex + 1), // Skip the rejoin location to avoid duplication
      ];

      // Calculate combined distance and time
      final combinedDistance = returnRoute.estimatedDistance + 
          originalRoute.estimatedDistance * (originalRoute.pathLocationIds.length - rejoinIndex - 1) / originalRoute.pathLocationIds.length;
      
      final combinedTime = returnRoute.estimatedTime + 
          Duration(milliseconds: (originalRoute.estimatedTime.inMilliseconds * (originalRoute.pathLocationIds.length - rejoinIndex - 1) / originalRoute.pathLocationIds.length).round());

      // Combine instructions
      final combinedInstructions = <NavigationInstruction>[
        ...returnRoute.instructions,
        ...originalRoute.instructions.where((instruction) => 
            originalRoute.pathLocationIds.indexOf(instruction.fromLocationId) > rejoinIndex),
      ];

      return Route(
        id: 'combined_${DateTime.now().millisecondsSinceEpoch}',
        startLocationId: returnRoute.startLocationId,
        endLocationId: originalRoute.endLocationId,
        pathLocationIds: combinedPath,
        estimatedDistance: combinedDistance,
        estimatedTime: combinedTime,
        instructions: combinedInstructions,
      );
    } catch (e) {
      return null;
    }
  }

  /// Apply a new route to the navigation state
  Future<void> _applyNewRoute(Route newRoute, {required bool isMinorReroute}) async {
    final firstInstruction = newRoute.instructions.isNotEmpty 
        ? newRoute.instructions.first 
        : null;
        
    state = state.copyWith(
      activeRoute: newRoute,
      state: NavigationState.navigating,
      currentInstruction: firstInstruction,
      currentStepIndex: 0,
    );
    
    // Log the rerouting for debugging/analytics
    _logRerouting(state.currentLocationId!, newRoute, isMinorReroute);
  }

  /// Enhanced logging for rerouting events
  void _logRerouting(String deviationLocationId, Route newRoute, bool isMinorReroute) {
    // In a real app, this would log to analytics service
    // For now, we'll use a debug print that can be disabled in production
    assert(() {
      final routeType = isMinorReroute ? 'Minor reroute' : 'Full reroute';
      print('$routeType: deviation at $deviationLocationId, '
            'new route distance: ${newRoute.estimatedDistance.toStringAsFixed(1)}m, '
            'estimated time: ${newRoute.estimatedTime.inMinutes}min');
      return true;
    }());
  }

  /// Handle updates when the user is still on the planned route
  Future<void> _handleOnRouteUpdate(String newLocationId, Route route) async {
    final currentIndex = route.getLocationIndex(newLocationId);
    final previousIndex = state.currentStepIndex;
    
    // Check if user is progressing forward on the route
    if (currentIndex >= previousIndex) {
      // Normal progression - update current instruction
      final nextInstruction = route.getNextInstruction(newLocationId);
      
      state = state.copyWith(
        currentInstruction: nextInstruction,
        currentStepIndex: currentIndex,
      );
      
      // Check if we've arrived at the destination
      if (newLocationId == route.endLocationId) {
        await _completeNavigation();
      }
    } else {
      // User went backwards on the route - this might be intentional
      // Update position but don't change the overall route
      final nextInstruction = route.getNextInstruction(newLocationId);
      
      state = state.copyWith(
        currentInstruction: nextInstruction,
        currentStepIndex: currentIndex,
      );
    }
  }

  /// Handle case where destination is unreachable from current position
  Future<void> _handleUnreachableDestination(String currentLocationId) async {
    // Try to find alternative routes or suggest manual navigation
    final currentLocation = await _locationRepository.getLocationById(currentLocationId);
    final destinationLocation = await _locationRepository.getLocationById(state.destinationLocationId!);
    
    String errorMessage = 'Unable to calculate route from current location to destination.';
    
    if (currentLocation != null && destinationLocation != null) {
      errorMessage = 'No route found from ${currentLocation.name} to ${destinationLocation.name}. '
                    'Please navigate to a connected location and try again.';
    }
    
    _setError(errorMessage);
    
    // Reset navigation state but keep destination for potential retry
    state = state.copyWith(
      activeRoute: null,
      currentInstruction: null,
      currentStepIndex: 0,
    );
  }

  /// Set current location manually (fallback when NFC is not available)
  Future<void> setCurrentLocation(String locationId) async {
    try {
      final isValid = await _locationRepository.isValidLocation(locationId);
      if (!isValid) {
        _setError('Invalid location: $locationId');
        return;
      }
      
      state = state.copyWith(
        currentLocationId: locationId,
        errorMessage: null,
      );
    } catch (e) {
      _setError('Failed to set current location: $e');
    }
  }

  /// Set destination and calculate route
  Future<void> setDestination(String destinationId) async {
    try {
      final isValid = await _locationRepository.isValidLocation(destinationId);
      if (!isValid) {
        _setError('Invalid destination: $destinationId');
        return;
      }
      
      state = state.copyWith(
        destinationLocationId: destinationId,
        state: NavigationState.selectingDestination,
        errorMessage: null,
      );
      
      // If we have a current location, calculate the route
      if (state.currentLocationId != null) {
        await _calculateRoute();
      }
    } catch (e) {
      _setError('Failed to set destination: $e');
    }
  }

  /// Calculate route from current location to destination
  Future<void> _calculateRoute() async {
    if (state.currentLocationId == null || state.destinationLocationId == null) {
      return;
    }
    
    try {
      state = state.copyWith(state: NavigationState.calculating);
      
      final route = await _routeCalculator.calculateRoute(
        state.currentLocationId!,
        state.destinationLocationId!,
      );
      
      if (route != null && route.isValid()) {
        state = state.copyWith(
          activeRoute: route,
          state: NavigationState.idle,
        );
      } else {
        _setError('No route found to destination');
      }
    } catch (e) {
      _setError('Route calculation failed: $e');
    }
  }

  /// Start navigation with the calculated route
  Future<void> startNavigation() async {
    if (state.activeRoute == null) {
      _setError('No route available to start navigation');
      return;
    }
    
    if (state.currentLocationId == null) {
      _setError('Current location not set');
      return;
    }
    
    try {
      // Start NFC scanning
      await _nfcService.startScanning();
      
      // Get first instruction
      final firstInstruction = state.activeRoute!.getNextInstruction(state.currentLocationId!);
      
      state = state.copyWith(
        state: NavigationState.navigating,
        currentInstruction: firstInstruction,
        currentStepIndex: 0,
      );
    } catch (e) {
      _setError('Failed to start navigation: $e');
    }
  }

  /// Stop navigation
  Future<void> stopNavigation() async {
    try {
      await _nfcService.stopScanning();
      
      state = state.copyWith(
        state: NavigationState.idle,
        currentInstruction: null,
        currentStepIndex: 0,
      );
    } catch (e) {
      _setError('Failed to stop navigation: $e');
    }
  }

  /// Complete navigation when destination is reached
  Future<void> _completeNavigation() async {
    try {
      await _nfcService.stopScanning();
      
      state = state.copyWith(
        state: NavigationState.arrived,
        currentInstruction: null,
      );
    } catch (e) {
      _setError('Failed to complete navigation: $e');
    }
  }

  /// Manually trigger rerouting (for testing or manual intervention)
  Future<void> triggerRerouting() async {
    if (state.currentLocationId != null && state.destinationLocationId != null && state.isNavigating && state.activeRoute != null) {
      await _handleSignificantDeviation(state.currentLocationId!, state.activeRoute!);
    }
  }

  /// Check if current location represents a significant deviation
  Future<bool> isSignificantDeviation(String currentLocationId, Route activeRoute) async {
    // If location is not on route at all, it's definitely a deviation
    if (!activeRoute.containsLocation(currentLocationId)) {
      return true;
    }
    
    // If user went backwards more than 2 steps, consider it a deviation
    final currentIndex = activeRoute.getLocationIndex(currentLocationId);
    final expectedIndex = state.currentStepIndex;
    
    if (currentIndex < expectedIndex - 2) {
      return true;
    }
    
    return false;
  }

  /// Get deviation distance from planned route
  Future<double?> getDeviationDistance(String currentLocationId) async {
    if (state.activeRoute == null) return null;
    
    final route = state.activeRoute!;
    
    // If on route, no deviation
    if (route.containsLocation(currentLocationId)) {
      return 0.0;
    }
    
    // Calculate distance to nearest point on route
    double minDistance = double.infinity;
    final currentLocation = await _locationRepository.getLocationById(currentLocationId);
    
    if (currentLocation == null) return null;
    
    for (final routeLocationId in route.pathLocationIds) {
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
    
    return minDistance == double.infinity ? null : minDistance;
  }

  /// Calculate distance between two coordinates (helper method)
  double _calculateDistance(Coordinates from, Coordinates to) {
    // Simple Euclidean distance for indoor navigation
    final dx = to.latitude - from.latitude;
    final dy = to.longitude - from.longitude;
    return sqrt(dx * dx + dy * dy) * 111000; // Rough conversion to meters
  }

  /// Clear the current route but keep destination
  void clearRoute() {
    state = state.copyWith(
      activeRoute: null,
      currentInstruction: null,
      currentStepIndex: 0,
      state: NavigationState.idle,
    );
  }

  /// Clear the current navigation session
  void clearSession() {
    state = const NavigationSession();
  }

  /// Clear error state
  void clearError() {
    state = state.clearError();
  }

  /// Set error state
  void _setError(String message) {
    state = state.copyWith(
      state: NavigationState.error,
      errorMessage: message,
    );
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    super.dispose();
  }
}

/// Providers for dependency injection
final nfcServiceProvider = Provider<NFCService>((ref) {
  final locationRepository = ref.watch(locationRepositoryProvider);
  return NFCServiceFactory.create(locationRepository);
});

final routeCalculatorProvider = Provider<RouteCalculator>((ref) {
  final locationRepository = ref.watch(locationRepositoryProvider);
  return SimpleRouteCalculator(locationRepository);
});

final navigationControllerProvider = StateNotifierProvider<NavigationController, NavigationSession>((ref) {
  final nfcService = ref.watch(nfcServiceProvider);
  final locationRepository = ref.watch(locationRepositoryProvider);
  final routeCalculator = ref.watch(routeCalculatorProvider);
  
  return NavigationController(
    nfcService: nfcService,
    locationRepository: locationRepository,
    routeCalculator: routeCalculator,
  );
});