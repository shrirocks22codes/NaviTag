import 'dart:math';
import 'package:test/test.dart';
import 'package:nfc_project_test/models/route.dart';
import '../property_test_framework.dart';

/// **Feature: nfc-navigation, Property 5: Navigation State Consistency**
/// **Validates: Requirements 4.1, 4.2, 4.3**
/// 
/// Property: For any valid route and current position along that route, 
/// the navigation instructions should correctly reflect the next required action

/// Simple test for navigation state consistency
void main() {
  group('Navigation State Consistency Property Tests', () {
    createPropertyTest<Route>(
      description: 'Navigation instructions should be consistent with route structure',
      generator: SimpleRouteGenerator(),
      property: (route) {
        // **Feature: nfc-navigation, Property 5: Navigation State Consistency**
        // **Validates: Requirements 4.1, 4.2, 4.3**
        
        // Property: Route instructions should form a valid sequence
        if (route.instructions.isEmpty) {
          // Empty instructions are valid for single-location routes
          return route.pathLocationIds.length <= 1;
        }
        
        // First instruction should start from the route start
        if (route.instructions.first.fromLocationId != route.startLocationId) {
          return false;
        }
        
        // Last instruction should end at the route end
        if (route.instructions.last.toLocationId != route.endLocationId) {
          return false;
        }
        
        // Instructions should form a continuous chain
        for (int i = 0; i < route.instructions.length - 1; i++) {
          if (route.instructions[i].toLocationId != route.instructions[i + 1].fromLocationId) {
            return false;
          }
        }
        
        // All instruction locations should be in the path
        for (final instruction in route.instructions) {
          if (!route.pathLocationIds.contains(instruction.fromLocationId) ||
              !route.pathLocationIds.contains(instruction.toLocationId)) {
            return false;
          }
        }
        
        return true;
      },
      iterations: 100,
      featureName: 'nfc-navigation',
      propertyNumber: 5,
      propertyText: 'Navigation State Consistency',
    );
    
    createPropertyTest<NavigationTestCase>(
      description: 'Next instruction should be consistent with current position',
      generator: NavigationTestCaseGenerator(),
      property: (testCase) {
        final route = testCase.route;
        final currentLocationId = testCase.currentLocationId;
        
        // If current location is not on route, this is a deviation case
        if (!route.containsLocation(currentLocationId)) {
          return true; // Property doesn't apply to deviation cases
        }
        
        final nextInstruction = route.getNextInstruction(currentLocationId);
        final currentIndex = route.getLocationIndex(currentLocationId);
        
        // If we're at the destination, there should be no next instruction
        if (currentLocationId == route.endLocationId) {
          return nextInstruction == null;
        }
        
        // If we're not at the destination, there should be a next instruction
        if (currentIndex < route.pathLocationIds.length - 1) {
          if (nextInstruction == null) {
            return false; // Should have an instruction
          }
          
          // The instruction should start from the current location
          if (nextInstruction.fromLocationId != currentLocationId) {
            return false;
          }
          
          // The instruction should point to a location that exists in the path
          if (!route.pathLocationIds.contains(nextInstruction.toLocationId)) {
            return false;
          }
        }
        
        return true;
      },
      iterations: 100,
    );
  });
}

/// Simple route generator for testing
class SimpleRouteGenerator extends Generator<Route> {
  final StringGenerator _idGenerator = StringGenerator(minLength: 3, maxLength: 10);

  @override
  Route generate(Random random) {
    final numLocations = 2 + random.nextInt(4); // 2-5 locations
    final locationIds = List.generate(numLocations, (i) => 'loc_$i');
    
    // Generate instructions
    final instructions = <NavigationInstruction>[];
    for (int i = 0; i < locationIds.length - 1; i++) {
      instructions.add(NavigationInstruction(
        id: '${locationIds[i]}_to_${locationIds[i + 1]}',
        type: i == 0 ? InstructionType.start : 
              i == locationIds.length - 2 ? InstructionType.destination : 
              InstructionType.straight,
        description: 'Go from ${locationIds[i]} to ${locationIds[i + 1]}',
        fromLocationId: locationIds[i],
        toLocationId: locationIds[i + 1],
        direction: Direction.forward,
        distance: 10.0 + random.nextDouble() * 90.0,
      ));
    }
    
    return Route(
      id: _idGenerator.generate(random),
      startLocationId: locationIds.first,
      endLocationId: locationIds.last,
      pathLocationIds: locationIds,
      estimatedDistance: instructions.fold(0.0, (sum, inst) => sum + inst.distance),
      estimatedTime: Duration(seconds: random.nextInt(300) + 60),
      instructions: instructions,
    );
  }
}

/// Test data structure combining route and current position
class NavigationTestCase {
  final Route route;
  final String currentLocationId;
  
  NavigationTestCase(this.route, this.currentLocationId);
  
  @override
  String toString() => 'NavigationTestCase(route: ${route.id}, current: $currentLocationId)';
}

/// Generator for navigation test cases
class NavigationTestCaseGenerator extends Generator<NavigationTestCase> {
  final SimpleRouteGenerator _routeGenerator = SimpleRouteGenerator();

  @override
  NavigationTestCase generate(Random random) {
    final route = _routeGenerator.generate(random);
    
    // Pick a random location from the route path
    final currentLocationId = route.pathLocationIds.isNotEmpty 
        ? route.pathLocationIds[random.nextInt(route.pathLocationIds.length)]
        : route.startLocationId;
    
    return NavigationTestCase(route, currentLocationId);
  }
}