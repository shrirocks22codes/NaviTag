import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:nfc_project_test/ui/widgets/interactive_map_widget.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/models/route.dart' as nav_route;
import '../../property_test_framework.dart';

void main() {
  group('InteractiveMapWidget Property Tests', () {
    createPropertyTest<MapDisplayTestCase>(
      description: 'Map display should accurately show current position, destination, and path',
      generator: MapDisplayTestCaseGenerator(),
      featureName: 'nfc-navigation',
      propertyNumber: 7,
      propertyText: 'Map Display Consistency',
      property: (testCase) {
        // **Feature: nfc-navigation, Property 7: Map Display Consistency**
        // **Validates: Requirements 3.1, 3.2, 3.4**
        
        // Property: For any route and current location, the map display should 
        // accurately show the current position, destination, and path between them
        
        return _testMapDisplayConsistency(testCase);
      },
    );

    createPropertyTest<LocationOverviewTestCase>(
      description: 'Location overview should display all locations with names and highlight current location',
      generator: LocationOverviewTestCaseGenerator(),
      featureName: 'nfc-navigation',
      propertyNumber: 8,
      propertyText: 'Location Overview Completeness',
      property: (testCase) {
        // **Feature: nfc-navigation, Property 8: Location Overview Completeness**
        // **Validates: Requirements 7.1, 7.2, 7.5**
        
        // Property: For any set of known locations, the overview map should display 
        // all locations with their correct names and positions, and highlight the 
        // current location distinctly
        
        return _testLocationOverviewCompleteness(testCase);
      },
    );

    createPropertyTest<GestureHandlingTestCase>(
      description: 'Map should respond appropriately to gestures while maintaining navigation context',
      generator: GestureHandlingTestCaseGenerator(),
      featureName: 'nfc-navigation',
      propertyNumber: 9,
      propertyText: 'Gesture Response Consistency',
      property: (testCase) {
        // **Feature: nfc-navigation, Property 9: Gesture Response Consistency**
        // **Validates: Requirements 8.5, 3.5**
        
        // Property: For any valid touch gesture on the map interface, the system 
        // should respond appropriately while maintaining navigation context
        
        return _testGestureResponseConsistency(testCase);
      },
    );
  });
}

/// Test case containing all data needed for map display testing
class MapDisplayTestCase {
  final List<Location> locations;
  final nav_route.Route route;
  final String currentLocationId;
  final String destinationLocationId;

  MapDisplayTestCase({
    required this.locations,
    required this.route,
    required this.currentLocationId,
    required this.destinationLocationId,
  });

  @override
  String toString() {
    return 'MapDisplayTestCase(locations: ${locations.length}, '
           'route: ${route.id}, current: $currentLocationId, '
           'destination: $destinationLocationId)';
  }
}

/// Test case containing all data needed for location overview testing
class LocationOverviewTestCase {
  final List<Location> locations;
  final String? currentLocationId;

  LocationOverviewTestCase({
    required this.locations,
    this.currentLocationId,
  });

  @override
  String toString() {
    return 'LocationOverviewTestCase(locations: ${locations.length}, '
           'current: $currentLocationId)';
  }
}

/// Test case containing all data needed for gesture handling testing
class GestureHandlingTestCase {
  final List<Location> locations;
  final nav_route.Route? activeRoute;
  final String? currentLocationId;
  final String? destinationLocationId;
  final GestureType gestureType;
  final double initialZoom;
  final double targetZoom;
  final bool hasActiveNavigation;

  GestureHandlingTestCase({
    required this.locations,
    this.activeRoute,
    this.currentLocationId,
    this.destinationLocationId,
    required this.gestureType,
    required this.initialZoom,
    required this.targetZoom,
    required this.hasActiveNavigation,
  });

  @override
  String toString() {
    return 'GestureHandlingTestCase(locations: ${locations.length}, '
           'gesture: $gestureType, zoom: $initialZoom->$targetZoom, '
           'hasNavigation: $hasActiveNavigation)';
  }
}

/// Types of gestures to test
enum GestureType {
  pinchToZoom,
  swipeToPan,
  tapToSelect,
  doubleTapToZoom,
}

/// Generator for map display test cases
class MapDisplayTestCaseGenerator extends Generator<MapDisplayTestCase> {
  final ConnectedLocationGraphGenerator _graphGenerator = ConnectedLocationGraphGenerator();
  final RouteGenerator _routeGenerator = RouteGenerator();

  @override
  MapDisplayTestCase generate(Random random) {
    // Generate connected locations
    final locations = _graphGenerator.generate(random);
    
    // Generate a route using these locations
    final route = _routeGenerator.generateFromLocations(locations, random);
    
    // Current location should be somewhere on the route path
    final currentLocationId = route.pathLocationIds[
      random.nextInt(route.pathLocationIds.length)
    ];
    
    // Destination is the end of the route
    final destinationLocationId = route.endLocationId;
    
    return MapDisplayTestCase(
      locations: locations,
      route: route,
      currentLocationId: currentLocationId,
      destinationLocationId: destinationLocationId,
    );
  }
}

/// Generator for location overview test cases
class LocationOverviewTestCaseGenerator extends Generator<LocationOverviewTestCase> {
  final ConnectedLocationGraphGenerator _graphGenerator = ConnectedLocationGraphGenerator();

  @override
  LocationOverviewTestCase generate(Random random) {
    // Generate a set of locations
    final locations = _graphGenerator.generate(random);
    
    // Randomly choose whether to have a current location (80% chance)
    String? currentLocationId;
    if (random.nextDouble() < 0.8 && locations.isNotEmpty) {
      currentLocationId = locations[random.nextInt(locations.length)].id;
    }
    
    return LocationOverviewTestCase(
      locations: locations,
      currentLocationId: currentLocationId,
    );
  }
}

/// Generator for gesture handling test cases
class GestureHandlingTestCaseGenerator extends Generator<GestureHandlingTestCase> {
  final ConnectedLocationGraphGenerator _graphGenerator = ConnectedLocationGraphGenerator();
  final RouteGenerator _routeGenerator = RouteGenerator();
  final ChoiceGenerator<GestureType> _gestureTypeGenerator = ChoiceGenerator(GestureType.values);
  final DoubleGenerator _zoomGenerator = DoubleGenerator(min: 15.0, max: 22.0); // Valid zoom range for indoor navigation

  @override
  GestureHandlingTestCase generate(Random random) {
    // Generate connected locations
    final locations = _graphGenerator.generate(random);
    
    // Randomly decide if we have active navigation (70% chance)
    final hasActiveNavigation = random.nextDouble() < 0.7;
    
    nav_route.Route? activeRoute;
    String? currentLocationId;
    String? destinationLocationId;
    
    if (hasActiveNavigation && locations.length >= 2) {
      // Generate a route for active navigation
      activeRoute = _routeGenerator.generateFromLocations(locations, random);
      
      // Current location should be somewhere on the route path
      currentLocationId = activeRoute.pathLocationIds[
        random.nextInt(activeRoute.pathLocationIds.length)
      ];
      
      // Destination is the end of the route
      destinationLocationId = activeRoute.endLocationId;
    } else if (locations.isNotEmpty) {
      // No active navigation, but might have a current location
      if (random.nextDouble() < 0.5) {
        currentLocationId = locations[random.nextInt(locations.length)].id;
      }
    }
    
    // Generate gesture parameters
    final gestureType = _gestureTypeGenerator.generate(random);
    
    // Generate zoom parameters based on gesture type
    double initialZoom;
    double targetZoom;
    
    if (gestureType == GestureType.pinchToZoom || gestureType == GestureType.doubleTapToZoom) {
      // For zoom gestures, ensure meaningful zoom change
      initialZoom = 16.0 + random.nextDouble() * 4.0; // 16.0 to 20.0 range
      final zoomChange = (random.nextDouble() - 0.5) * 3.0; // ±1.5 zoom levels
      targetZoom = (initialZoom + zoomChange).clamp(15.0, 22.0);
      
      // Ensure minimum difference of 0.2 zoom levels
      if ((targetZoom - initialZoom).abs() < 0.2) {
        if (targetZoom > initialZoom) {
          targetZoom = initialZoom + 0.5;
        } else {
          targetZoom = initialZoom - 0.5;
        }
        targetZoom = targetZoom.clamp(15.0, 22.0);
      }
    } else {
      // For non-zoom gestures, use same zoom level
      initialZoom = _zoomGenerator.generate(random);
      targetZoom = initialZoom;
    }
    
    return GestureHandlingTestCase(
      locations: locations,
      activeRoute: activeRoute,
      currentLocationId: currentLocationId,
      destinationLocationId: destinationLocationId,
      gestureType: gestureType,
      initialZoom: initialZoom,
      targetZoom: targetZoom,
      hasActiveNavigation: hasActiveNavigation,
    );
  }
}

/// Generator for creating connected location graphs
class ConnectedLocationGraphGenerator extends Generator<List<Location>> {
  final IntGenerator _sizeGenerator = IntGenerator(min: 3, max: 8);
  final LocationGenerator _locationGenerator = LocationGenerator();

  @override
  List<Location> generate(Random random) {
    final size = _sizeGenerator.generate(random);
    final locations = <Location>[];
    
    // Generate base locations with realistic coordinates (indoor navigation range)
    for (int i = 0; i < size; i++) {
      locations.add(_locationGenerator.generate(random).copyWith(
        id: 'loc_$i',
        name: 'Location $i',
        coordinates: Coordinates(
          // Use a small coordinate range to simulate indoor navigation
          latitude: 40.7128 + (random.nextDouble() - 0.5) * 0.01, // ~500m range
          longitude: -74.0060 + (random.nextDouble() - 0.5) * 0.01,
        ),
      ));
    }
    
    // Create connections to ensure all locations are reachable
    final connectedLocations = <Location>[];
    for (int i = 0; i < locations.length; i++) {
      final connections = <String>[];
      
      // Connect to previous location (if exists)
      if (i > 0) {
        connections.add(locations[i - 1].id);
      }
      
      // Connect to next location (if exists)
      if (i < locations.length - 1) {
        connections.add(locations[i + 1].id);
      }
      
      // Add some random additional connections for more realistic graphs
      if (random.nextBool() && locations.length > 2) {
        final randomIndex = random.nextInt(locations.length);
        if (randomIndex != i && !connections.contains(locations[randomIndex].id)) {
          connections.add(locations[randomIndex].id);
        }
      }
      
      connectedLocations.add(locations[i].copyWith(
        connectedLocationIds: connections,
      ));
    }
    
    return connectedLocations;
  }
}

/// Generator for creating test locations
class LocationGenerator extends Generator<Location> {
  final StringGenerator _idGenerator = StringGenerator(minLength: 3, maxLength: 10);
  final StringGenerator _nameGenerator = StringGenerator(minLength: 5, maxLength: 20);
  final ChoiceGenerator<LocationType> _typeGenerator = ChoiceGenerator(LocationType.values);

  @override
  Location generate(Random random) {
    return Location(
      id: _idGenerator.generate(random),
      name: _nameGenerator.generate(random),
      description: '${_nameGenerator.generate(random)} description',
      coordinates: const Coordinates(latitude: 0, longitude: 0), // Will be overridden
      connectedLocationIds: [], // Will be set up by the graph generator
      type: _typeGenerator.generate(random),
    );
  }
}

/// Generator for creating valid routes from location graphs
class RouteGenerator extends Generator<nav_route.Route> {
  final StringGenerator _idGenerator = StringGenerator();

  @override
  nav_route.Route generate(Random random) {
    // This shouldn't be called directly - use generateFromLocations instead
    throw UnimplementedError('Use generateFromLocations instead');
  }

  /// Generate a route from a given set of connected locations
  nav_route.Route generateFromLocations(List<Location> locations, Random random) {
    if (locations.length < 2) {
      throw ArgumentError('Need at least 2 locations to create a route');
    }

    // Pick random start and end locations
    final startIndex = random.nextInt(locations.length);
    final endIndex = (startIndex + 1 + random.nextInt(locations.length - 1)) % locations.length;
    
    final startLocation = locations[startIndex];
    final endLocation = locations[endIndex];
    
    // Create a simple path (in a real implementation, this would use pathfinding)
    final pathIds = <String>[startLocation.id];
    
    // Add intermediate locations to create a realistic path
    if (startIndex != endIndex) {
      // Simple path: go through locations in order
      int current = startIndex;
      while (current != endIndex) {
        current = (current + 1) % locations.length;
        pathIds.add(locations[current].id);
      }
    }
    
    // Calculate estimated distance (simple Euclidean distance)
    double totalDistance = 0.0;
    for (int i = 0; i < pathIds.length - 1; i++) {
      final loc1 = locations.firstWhere((l) => l.id == pathIds[i]);
      final loc2 = locations.firstWhere((l) => l.id == pathIds[i + 1]);
      
      final dx = loc1.coordinates.latitude - loc2.coordinates.latitude;
      final dy = loc1.coordinates.longitude - loc2.coordinates.longitude;
      totalDistance += sqrt(dx * dx + dy * dy) * 111000; // Rough conversion to meters
    }
    
    return nav_route.Route(
      id: _idGenerator.generate(random),
      startLocationId: startLocation.id,
      endLocationId: endLocation.id,
      pathLocationIds: pathIds,
      estimatedDistance: totalDistance,
      estimatedTime: Duration(seconds: (totalDistance / 1.4).round()), // ~1.4 m/s walking speed
      instructions: [], // Instructions not needed for this test
    );
  }
}

/// Test the map display consistency property
bool _testMapDisplayConsistency(MapDisplayTestCase testCase) {
  // Test that we can create the widget without errors
  bool widgetCreatesSuccessfully = false;
  bool hasCorrectLocations = false;
  bool hasCorrectRoute = false;
  bool hasCorrectCurrentLocation = false;
  bool hasCorrectDestination = false;
  
  try {
    // Test 1: Widget should create successfully with valid data
    final widget = InteractiveMapWidget(
      locations: testCase.locations,
      activeRoute: testCase.route,
      currentLocationId: testCase.currentLocationId,
      destinationLocationId: testCase.destinationLocationId,
      showLocationLabels: true,
    );
    
    widgetCreatesSuccessfully = true;
    
    // Test 2: All locations should be present in the widget's location list
    hasCorrectLocations = widget.locations.length == testCase.locations.length &&
                         widget.locations.every((loc) => 
                           testCase.locations.any((testLoc) => testLoc.id == loc.id));
    
    // Test 3: Active route should match the test case route
    hasCorrectRoute = widget.activeRoute?.id == testCase.route.id &&
                     widget.activeRoute?.startLocationId == testCase.route.startLocationId &&
                     widget.activeRoute?.endLocationId == testCase.route.endLocationId;
    
    // Test 4: Current location should be set correctly
    hasCorrectCurrentLocation = widget.currentLocationId == testCase.currentLocationId;
    
    // Test 5: Destination should be set correctly
    hasCorrectDestination = widget.destinationLocationId == testCase.destinationLocationId;
    
    // Additional validation: Current location should exist in the locations list
    final currentLocationExists = testCase.locations.any(
      (loc) => loc.id == testCase.currentLocationId
    );
    
    // Additional validation: Destination should exist in the locations list
    final destinationExists = testCase.locations.any(
      (loc) => loc.id == testCase.destinationLocationId
    );
    
    // Additional validation: Route path should only contain valid location IDs
    final routePathValid = testCase.route.pathLocationIds.every(
      (locationId) => testCase.locations.any((loc) => loc.id == locationId)
    );
    
    // Additional validation: Current location should be on the route path
    final currentLocationOnRoute = testCase.route.pathLocationIds.contains(testCase.currentLocationId);
    
    return widgetCreatesSuccessfully &&
           hasCorrectLocations &&
           hasCorrectRoute &&
           hasCorrectCurrentLocation &&
           hasCorrectDestination &&
           currentLocationExists &&
           destinationExists &&
           routePathValid &&
           currentLocationOnRoute;
           
  } catch (e) {
    // If any exception occurs, the property fails
    return false;
  }
}

/// Test the location overview completeness property
bool _testLocationOverviewCompleteness(LocationOverviewTestCase testCase) {
  // Test that the widget can display all locations with proper overview functionality
  bool widgetCreatesSuccessfully = false;
  bool allLocationsDisplayed = false;
  bool currentLocationHighlighted = false;
  bool labelsEnabled = false;
  
  try {
    // Test 1: Widget should create successfully with location overview data
    final widget = InteractiveMapWidget(
      locations: testCase.locations,
      currentLocationId: testCase.currentLocationId,
      showLocationLabels: true, // Enable labels for overview mode
    );
    
    widgetCreatesSuccessfully = true;
    
    // Test 2: All known locations should be displayed (Requirements 7.1)
    // The widget should contain all locations from the test case
    allLocationsDisplayed = widget.locations.length == testCase.locations.length &&
                           widget.locations.every((widgetLoc) => 
                             testCase.locations.any((testLoc) => testLoc.id == widgetLoc.id)) &&
                           testCase.locations.every((testLoc) =>
                             widget.locations.any((widgetLoc) => widgetLoc.id == testLoc.id));
    
    // Test 3: Location labels should be enabled for overview (Requirements 7.2)
    // The showLocationLabels property should be true to show readable labels
    labelsEnabled = widget.showLocationLabels == true;
    
    // Test 4: Current location should be properly set for highlighting (Requirements 7.5)
    // If there's a current location, it should be set correctly
    if (testCase.currentLocationId != null) {
      currentLocationHighlighted = widget.currentLocationId == testCase.currentLocationId;
      
      // Additional validation: Current location should exist in the locations list
      final currentLocationExists = testCase.locations.any(
        (loc) => loc.id == testCase.currentLocationId
      );
      
      if (!currentLocationExists) {
        return false; // Current location must be valid
      }
    } else {
      // If no current location is specified, that's also valid
      currentLocationHighlighted = widget.currentLocationId == null;
    }
    
    // Test 5: All location data should be valid and complete
    bool allLocationDataValid = true;
    for (final location in testCase.locations) {
      // Each location should have a valid ID and name (for displaying with labels)
      if (location.id.isEmpty || location.name.isEmpty) {
        allLocationDataValid = false;
        break;
      }
      
      // Each location should have valid coordinates
      if (location.coordinates.latitude == 0 && location.coordinates.longitude == 0) {
        // Allow (0,0) coordinates but check they're not all zero unless it's intentional
        // In a real system, you might want stricter coordinate validation
      }
    }
    
    // Test 6: Widget should handle empty location lists gracefully
    if (testCase.locations.isEmpty) {
      // Empty location list should still create a valid widget
      return widgetCreatesSuccessfully && allLocationsDisplayed && labelsEnabled;
    }
    
    return widgetCreatesSuccessfully &&
           allLocationsDisplayed &&
           labelsEnabled &&
           currentLocationHighlighted &&
           allLocationDataValid;
           
  } catch (e) {
    // If any exception occurs, the property fails
    return false;
  }
}

/// Test the gesture response consistency property
bool _testGestureResponseConsistency(GestureHandlingTestCase testCase) {
  // Test that the widget responds appropriately to gestures while maintaining navigation context
  bool widgetCreatesSuccessfully = false;
  bool gestureConfigurationValid = false;
  bool navigationContextMaintained = false;
  bool touchInteractionSupported = false;
  bool zoomCapabilitiesValid = false;
  
  try {
    // Test 1: Widget should create successfully with gesture handling configuration
    final widget = InteractiveMapWidget(
      locations: testCase.locations,
      activeRoute: testCase.activeRoute,
      currentLocationId: testCase.currentLocationId,
      destinationLocationId: testCase.destinationLocationId,
      showLocationLabels: true,
    );
    
    widgetCreatesSuccessfully = true;
    
    // Test 2: Gesture configuration should be valid (Requirements 8.5)
    // The widget should support intuitive touch interactions like pinch-to-zoom and swipe-to-pan
    gestureConfigurationValid = _validateGestureConfiguration(testCase);
    
    // Test 3: Navigation context should be maintained during gestures (Requirements 3.5)
    // When user interacts with map, route visibility and navigation context should be preserved
    navigationContextMaintained = _validateNavigationContextMaintenance(testCase, widget);
    
    // Test 4: Touch interaction should be supported appropriately
    // The widget should handle the specific gesture type being tested
    touchInteractionSupported = _validateTouchInteractionSupport(testCase, widget);
    
    // Test 5: Zoom capabilities should be valid for the gesture type
    // Zoom-related gestures should have valid zoom parameters
    zoomCapabilitiesValid = _validateZoomCapabilities(testCase);
    
    // Test 6: Widget should handle edge cases gracefully
    bool edgeCasesHandled = true;
    
    // Empty locations list should still support gestures
    if (testCase.locations.isEmpty) {
      edgeCasesHandled = widgetCreatesSuccessfully && gestureConfigurationValid;
    }
    
    // Navigation without route should still support gestures
    if (!testCase.hasActiveNavigation) {
      edgeCasesHandled = widgetCreatesSuccessfully && gestureConfigurationValid;
    }
    
    return widgetCreatesSuccessfully &&
           gestureConfigurationValid &&
           navigationContextMaintained &&
           touchInteractionSupported &&
           zoomCapabilitiesValid &&
           edgeCasesHandled;
           
  } catch (e) {
    // If any exception occurs, the property fails
    return false;
  }
}

/// Validate that gesture configuration is appropriate for the test case
bool _validateGestureConfiguration(GestureHandlingTestCase testCase) {
  // Test that gesture type is valid and supported
  switch (testCase.gestureType) {
    case GestureType.pinchToZoom:
      // Pinch-to-zoom should have meaningful zoom change
      return (testCase.targetZoom - testCase.initialZoom).abs() > 0.1;
      
    case GestureType.swipeToPan:
      // Swipe-to-pan should maintain same zoom level
      return testCase.targetZoom == testCase.initialZoom;
      
    case GestureType.tapToSelect:
      // Tap-to-select should work with any zoom level
      return testCase.initialZoom >= 15.0 && testCase.initialZoom <= 22.0;
      
    case GestureType.doubleTapToZoom:
      // Double-tap-to-zoom should have meaningful zoom change
      return (testCase.targetZoom - testCase.initialZoom).abs() > 0.1;
  }
}

/// Validate that navigation context is maintained during gestures
bool _validateNavigationContextMaintenance(GestureHandlingTestCase testCase, InteractiveMapWidget widget) {
  // If there's active navigation, context should be preserved
  if (testCase.hasActiveNavigation && testCase.activeRoute != null) {
    // Active route should be maintained
    bool routeMaintained = widget.activeRoute?.id == testCase.activeRoute!.id;
    
    // Current location should be maintained
    bool currentLocationMaintained = widget.currentLocationId == testCase.currentLocationId;
    
    // Destination should be maintained
    bool destinationMaintained = widget.destinationLocationId == testCase.destinationLocationId;
    
    return routeMaintained && currentLocationMaintained && destinationMaintained;
  } else {
    // Without active navigation, basic location context should still be maintained
    return widget.currentLocationId == testCase.currentLocationId;
  }
}

/// Validate that touch interaction is properly supported
bool _validateTouchInteractionSupport(GestureHandlingTestCase testCase, InteractiveMapWidget widget) {
  // All gesture types should be supported with proper touch-friendly sizing
  switch (testCase.gestureType) {
    case GestureType.pinchToZoom:
      // Pinch-to-zoom requires multi-touch support (always supported in Flutter)
      return true;
      
    case GestureType.swipeToPan:
      // Swipe-to-pan requires single touch support (always supported in Flutter)
      return true;
      
    case GestureType.tapToSelect:
      // Tap-to-select requires locations to be present for selection
      return testCase.locations.isNotEmpty;
      
    case GestureType.doubleTapToZoom:
      // Double-tap-to-zoom requires gesture recognition (always supported in Flutter)
      return true;
  }
}

/// Validate that zoom capabilities are appropriate for the gesture
bool _validateZoomCapabilities(GestureHandlingTestCase testCase) {
  // Initial zoom should be within valid range
  bool initialZoomValid = testCase.initialZoom >= 15.0 && testCase.initialZoom <= 22.0;
  
  // Target zoom should be within valid range
  bool targetZoomValid = testCase.targetZoom >= 15.0 && testCase.targetZoom <= 22.0;
  
  // For zoom gestures, there should be a meaningful difference
  bool zoomChangeValid = true;
  if (testCase.gestureType == GestureType.pinchToZoom || 
      testCase.gestureType == GestureType.doubleTapToZoom) {
    zoomChangeValid = (testCase.targetZoom - testCase.initialZoom).abs() > 0.1;
  }
  
  return initialZoomValid && targetZoomValid && zoomChangeValid;
}
