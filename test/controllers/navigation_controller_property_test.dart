import 'dart:math';
import 'package:test/test.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/models/route.dart';
import 'package:nfc_project_test/models/nfc_tag_data.dart';
import 'package:nfc_project_test/services/nfc_service.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import '../property_test_framework.dart';

/// **Feature: nfc-navigation, Property 5: Navigation State Consistency**
/// **Validates: Requirements 4.1, 4.2, 4.3**
/// 
/// Property: For any valid route and current position along that route, 
/// the navigation instructions should correctly reflect the next required action

/// Generator for creating test locations
class LocationGenerator extends Generator<Location> {
  final StringGenerator _idGenerator = StringGenerator(minLength: 3, maxLength: 10);
  final StringGenerator _nameGenerator = StringGenerator(minLength: 5, maxLength: 20);
  final DoubleGenerator _coordGenerator = DoubleGenerator(min: -90.0, max: 90.0);
  final ChoiceGenerator<LocationType> _typeGenerator = ChoiceGenerator(LocationType.values);

  @override
  Location generate(Random random) {
    return Location(
      id: _idGenerator.generate(random),
      name: _nameGenerator.generate(random),
      description: '${_nameGenerator.generate(random)} description',
      coordinates: Coordinates(
        latitude: _coordGenerator.generate(random),
        longitude: _coordGenerator.generate(random),
      ),
      connectedLocationIds: [], // Will be set up by the test
      type: _typeGenerator.generate(random),
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
    
    // Generate base locations
    for (int i = 0; i < size; i++) {
      locations.add(_locationGenerator.generate(random).copyWith(
        id: 'loc_$i', // Ensure unique IDs
        name: 'Location $i',
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
      
      // Add some random additional connections
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

/// Generator for creating valid routes from location graphs
class RouteGenerator extends Generator<Route> {
  final ConnectedLocationGraphGenerator _graphGenerator = ConnectedLocationGraphGenerator();
  final StringGenerator _idGenerator = StringGenerator();

  @override
  Route generate(Random random) {
    final locations = _graphGenerator.generate(random);
    if (locations.length < 2) {
      // Fallback for small graphs
      return _createSimpleRoute(random);
    }
    
    final startIndex = random.nextInt(locations.length);
    final endIndex = (startIndex + 1 + random.nextInt(locations.length - 1)) % locations.length;
    
    final start = locations[startIndex];
    final end = locations[endIndex];
    
    // Create a simple path (in real implementation, this would use pathfinding)
    final pathIds = <String>[start.id];
    if (start.connectedLocationIds.contains(end.id)) {
      pathIds.add(end.id);
    } else {
      // Add intermediate location if available
      if (start.connectedLocationIds.isNotEmpty) {
        final intermediate = start.connectedLocationIds.first;
        pathIds.add(intermediate);
        pathIds.add(end.id);
      } else {
        pathIds.add(end.id);
      }
    }
    
    // Generate instructions
    final instructions = <NavigationInstruction>[];
    for (int i = 0; i < pathIds.length - 1; i++) {
      instructions.add(NavigationInstruction(
        id: '${pathIds[i]}_to_${pathIds[i + 1]}',
        type: i == 0 ? InstructionType.start : 
              i == pathIds.length - 2 ? InstructionType.destination : 
              InstructionType.straight,
        description: 'Go from ${pathIds[i]} to ${pathIds[i + 1]}',
        fromLocationId: pathIds[i],
        toLocationId: pathIds[i + 1],
        direction: Direction.forward,
        distance: 10.0 + random.nextDouble() * 90.0,
      ));
    }
    
    return Route(
      id: _idGenerator.generate(random),
      startLocationId: start.id,
      endLocationId: end.id,
      pathLocationIds: pathIds,
      estimatedDistance: instructions.fold(0.0, (sum, inst) => sum + inst.distance),
      estimatedTime: Duration(seconds: random.nextInt(300) + 60),
      instructions: instructions,
    );
  }
  
  Route _createSimpleRoute(Random random) {
    final startId = 'start_${random.nextInt(1000)}';
    final endId = 'end_${random.nextInt(1000)}';
    
    final instruction = NavigationInstruction(
      id: '${startId}_to_$endId',
      type: InstructionType.start,
      description: 'Go from $startId to $endId',
      fromLocationId: startId,
      toLocationId: endId,
      direction: Direction.forward,
      distance: 50.0,
    );
    
    return Route(
      id: _idGenerator.generate(random),
      startLocationId: startId,
      endLocationId: endId,
      pathLocationIds: [startId, endId],
      estimatedDistance: 50.0,
      estimatedTime: const Duration(seconds: 120),
      instructions: [instruction],
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
  final RouteGenerator _routeGenerator = RouteGenerator();

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

/// Mock implementations for testing
class MockLocationRepository implements LocationRepository {
  final Map<String, Location> _locations = {};
  
  void addLocation(Location location) {
    _locations[location.id] = location;
  }
  
  @override
  Future<Location?> getLocationById(String id) async {
    return _locations[id];
  }
  
  @override
  Future<List<Location>> getAllLocations() async {
    return _locations.values.toList();
  }
  
  @override
  Future<List<Location>> getConnectedLocations(String locationId) async {
    final location = _locations[locationId];
    if (location == null) return [];
    
    final connected = <Location>[];
    for (final connectedId in location.connectedLocationIds) {
      final connectedLocation = _locations[connectedId];
      if (connectedLocation != null) {
        connected.add(connectedLocation);
      }
    }
    return connected;
  }
  
  @override
  Future<bool> locationExists(String id) async {
    return _locations.containsKey(id);
  }
  
  @override
  Future<bool> isValidLocation(String locationId) async {
    return _locations.containsKey(locationId);
  }
  
  @override
  Future<Location?> getLocationByNfcSerial(String nfcSerial) async {
    for (final location in _locations.values) {
      if (location.nfcTagSerial == nfcSerial) {
        return location;
      }
    }
    return null;
  }
}

class MockNFCService implements NFCService {
  @override
  Stream<NFCTagData> get tagStream => Stream.empty();
  
  @override
  Stream<bool> get scanningStatusStream => Stream.empty();
  
  @override
  bool get isScanning => false;
  
  @override
  Future<NFCAvailabilityStatus> checkNFCAvailability() async {
    return NFCAvailabilityStatus.available;
  }
  
  @override
  Future<NFCPermissionStatus> requestPermissions() async {
    return NFCPermissionStatus.granted;
  }
  
  @override
  Future<void> startScanning() async {}
  
  @override
  Future<void> stopScanning() async {}
  
  @override
  Future<bool> writeTag(NFCTagData tagData) async {
    return true;
  }
  
  @override
  void dispose() {}
}

void main() {
  group('Navigation Controller Property Tests', () {
    createPropertyTest<NavigationTestCase>(
      description: 'Navigation instructions should be consistent with route and current position',
      generator: NavigationTestCaseGenerator(),
      property: (testCase) {
        // **Feature: nfc-navigation, Property 5: Navigation State Consistency**
        // **Validates: Requirements 4.1, 4.2, 4.3**
        
        final route = testCase.route;
        final currentLocationId = testCase.currentLocationId;
        
        // Property: If current location is on the route, there should be a valid next instruction
        // or we should be at the destination
        
        if (!route.containsLocation(currentLocationId)) {
          // If current location is not on route, this is a deviation case
          // The property doesn't apply to deviation cases
          return true;
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
          
          // The instruction should have a valid type
          if (nextInstruction.type == InstructionType.start && currentIndex != 0) {
            return false; // Start instruction should only be at the beginning
          }
          
          if (nextInstruction.type == InstructionType.destination && 
              nextInstruction.toLocationId != route.endLocationId) {
            return false; // Destination instruction should only point to the end
          }
        }
        
        return true;
      },
      iterations: 100,
      featureName: 'nfc-navigation',
      propertyNumber: 5,
      propertyText: 'Navigation State Consistency',
    );
    
    createPropertyTest<Route>(
      description: 'Valid routes should have consistent instruction sequences',
      generator: RouteGenerator(),
      property: (route) {
        // Additional property: Route instructions should form a valid sequence
        
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
    );
  });
}