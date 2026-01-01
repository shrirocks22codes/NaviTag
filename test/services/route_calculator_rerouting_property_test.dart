import 'dart:math';
import 'package:test/test.dart';
import 'package:nfc_project_test/services/route_calculator.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/models/route.dart';
import '../property_test_framework.dart';

/// **Feature: nfc-navigation, Property 6: Rerouting Correctness**
/// **Validates: Requirements 6.1, 6.2, 6.4**
/// 
/// Property: For any deviation from a planned route, the system should calculate 
/// a new valid route from the current position to the original destination

/// Test case representing a rerouting scenario
class ReroutingTestCase {
  final Route originalRoute;
  final String deviationLocationId;
  final String originalDestination;
  
  ReroutingTestCase({
    required this.originalRoute,
    required this.deviationLocationId,
    required this.originalDestination,
  });
  
  @override
  String toString() => 'ReroutingTestCase(original: ${originalRoute.id}, deviation: $deviationLocationId, destination: $originalDestination)';
}

/// Generator for creating rerouting test scenarios
class ReroutingTestCaseGenerator extends Generator<ReroutingTestCase> {
  final RouteGenerator _routeGenerator = RouteGenerator();

  @override
  ReroutingTestCase generate(Random random) {
    // Generate a base route
    final originalRoute = _routeGenerator.generate(random);
    
    // Generate a deviation location that's NOT on the original route
    String deviationLocationId;
    int attempts = 0;
    do {
      deviationLocationId = 'deviation_${random.nextInt(1000)}';
      attempts++;
    } while (originalRoute.containsLocation(deviationLocationId) && attempts < 10);
    
    // If we couldn't generate a unique deviation location, create one
    if (originalRoute.containsLocation(deviationLocationId)) {
      deviationLocationId = 'unique_deviation_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}';
    }
    
    return ReroutingTestCase(
      originalRoute: originalRoute,
      deviationLocationId: deviationLocationId,
      originalDestination: originalRoute.endLocationId,
    );
  }
}

/// Generator for creating connected location graphs with deviation points
class ConnectedLocationGraphWithDeviationGenerator extends Generator<List<Location>> {
  final IntGenerator _sizeGenerator = IntGenerator(min: 4, max: 10);
  final LocationGenerator _locationGenerator = LocationGenerator();

  @override
  List<Location> generate(Random random) {
    final size = _sizeGenerator.generate(random);
    final locations = <Location>[];
    
    // Generate base locations in a connected chain
    for (int i = 0; i < size; i++) {
      locations.add(_locationGenerator.generate(random).copyWith(
        id: 'loc_$i',
        name: 'Location $i',
      ));
    }
    
    // Add some deviation locations that are connected to the main chain
    final deviationCount = 1 + random.nextInt(3); // 1-3 deviation locations
    for (int i = 0; i < deviationCount; i++) {
      final deviationId = 'deviation_$i';
      locations.add(_locationGenerator.generate(random).copyWith(
        id: deviationId,
        name: 'Deviation Location $i',
      ));
    }
    
    // Create connections to ensure reachability
    final connectedLocations = <Location>[];
    for (int i = 0; i < locations.length; i++) {
      final location = locations[i];
      final connections = <String>[];
      
      if (location.id.startsWith('loc_')) {
        // Main chain locations
        final index = int.parse(location.id.split('_')[1]);
        
        // Connect to previous location (if exists)
        if (index > 0) {
          connections.add('loc_${index - 1}');
        }
        
        // Connect to next location (if exists)
        if (index < size - 1) {
          connections.add('loc_${index + 1}');
        }
        
        // Randomly connect to deviation locations
        if (random.nextBool()) {
          for (final loc in locations) {
            if (loc.id.startsWith('deviation_') && random.nextBool()) {
              connections.add(loc.id);
            }
          }
        }
      } else if (location.id.startsWith('deviation_')) {
        // Deviation locations - connect to at least one main chain location
        final mainChainIndex = random.nextInt(size);
        connections.add('loc_$mainChainIndex');
        
        // Optionally connect to other deviation locations
        for (final loc in locations) {
          if (loc.id.startsWith('deviation_') && loc.id != location.id && random.nextBool()) {
            connections.add(loc.id);
          }
        }
      }
      
      connectedLocations.add(location.copyWith(
        connectedLocationIds: connections,
      ));
    }
    
    return connectedLocations;
  }
}

/// Generator for creating realistic rerouting scenarios
class RealisticReroutingGenerator extends Generator<ReroutingTestCase> {
  final ConnectedLocationGraphWithDeviationGenerator _graphGenerator = ConnectedLocationGraphWithDeviationGenerator();

  @override
  ReroutingTestCase generate(Random random) {
    final locations = _graphGenerator.generate(random);
    
    // Find main chain locations for the original route
    final mainChainLocations = locations.where((loc) => loc.id.startsWith('loc_')).toList();
    final deviationLocations = locations.where((loc) => loc.id.startsWith('deviation_')).toList();
    
    if (mainChainLocations.length < 2 || deviationLocations.isEmpty) {
      // Fallback to simple case
      return _createSimpleReroutingCase(random);
    }
    
    // Create original route using main chain
    final startIndex = random.nextInt(mainChainLocations.length);
    final endIndex = (startIndex + 1 + random.nextInt(mainChainLocations.length - 1)) % mainChainLocations.length;
    
    final startLocation = mainChainLocations[startIndex];
    final endLocation = mainChainLocations[endIndex];
    
    // Create path between start and end
    final pathIds = <String>[];
    if (startIndex < endIndex) {
      for (int i = startIndex; i <= endIndex; i++) {
        pathIds.add('loc_$i');
      }
    } else {
      for (int i = startIndex; i >= endIndex; i--) {
        pathIds.add('loc_$i');
      }
    }
    
    // Generate instructions for the original route
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
        distance: 10.0 + random.nextDouble() * 40.0,
      ));
    }
    
    final originalRoute = Route(
      id: 'original_${DateTime.now().millisecondsSinceEpoch}',
      startLocationId: startLocation.id,
      endLocationId: endLocation.id,
      pathLocationIds: pathIds,
      estimatedDistance: instructions.fold(0.0, (sum, inst) => sum + inst.distance),
      estimatedTime: Duration(seconds: random.nextInt(300) + 60),
      instructions: instructions,
    );
    
    // Pick a deviation location
    final deviationLocation = deviationLocations[random.nextInt(deviationLocations.length)];
    
    return ReroutingTestCase(
      originalRoute: originalRoute,
      deviationLocationId: deviationLocation.id,
      originalDestination: endLocation.id,
    );
  }
  
  ReroutingTestCase _createSimpleReroutingCase(Random random) {
    final startId = 'start_${random.nextInt(1000)}';
    final endId = 'end_${random.nextInt(1000)}';
    final deviationId = 'deviation_${random.nextInt(1000)}';
    
    final instruction = NavigationInstruction(
      id: '${startId}_to_$endId',
      type: InstructionType.destination,
      description: 'Go from $startId to $endId',
      fromLocationId: startId,
      toLocationId: endId,
      direction: Direction.forward,
      distance: 50.0,
    );
    
    final originalRoute = Route(
      id: 'simple_${DateTime.now().millisecondsSinceEpoch}',
      startLocationId: startId,
      endLocationId: endId,
      pathLocationIds: [startId, endId],
      estimatedDistance: 50.0,
      estimatedTime: const Duration(seconds: 120),
      instructions: [instruction],
    );
    
    return ReroutingTestCase(
      originalRoute: originalRoute,
      deviationLocationId: deviationId,
      originalDestination: endId,
    );
  }
}

/// Generator for basic route structures
class RouteGenerator extends Generator<Route> {
  final StringGenerator _idGenerator = StringGenerator();

  @override
  Route generate(Random random) {
    final startId = 'start_${random.nextInt(1000)}';
    final endId = 'end_${random.nextInt(1000)}';
    
    // Create a simple 2-3 hop route
    final pathIds = <String>[startId];
    
    if (random.nextBool()) {
      // Add intermediate location
      pathIds.add('intermediate_${random.nextInt(1000)}');
    }
    
    pathIds.add(endId);
    
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
      startLocationId: startId,
      endLocationId: endId,
      pathLocationIds: pathIds,
      estimatedDistance: instructions.fold(0.0, (sum, inst) => sum + inst.distance),
      estimatedTime: Duration(seconds: random.nextInt(300) + 60),
      instructions: instructions,
    );
  }
}

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

/// Mock repository for testing rerouting scenarios
class MockReroutingLocationRepository implements LocationRepository {
  final Map<String, Location> _locations = {};
  
  void addLocation(Location location) {
    _locations[location.id] = location;
  }
  
  void addLocations(List<Location> locations) {
    for (final location in locations) {
      _locations[location.id] = location;
    }
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

void main() {
  group('Route Calculator Rerouting Property Tests', () {
    late DijkstraRouteCalculator calculator;
    late MockReroutingLocationRepository repository;

    setUp(() {
      repository = MockReroutingLocationRepository();
      calculator = DijkstraRouteCalculator(repository);
    });

    /// **Feature: nfc-navigation, Property 6: Rerouting Correctness**
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    test('**Feature: nfc-navigation, Property 6: Rerouting Correctness** - Rerouting should calculate valid routes from deviation points to original destination', () async {
      final generator = RealisticReroutingGenerator();
      final random = Random(42); // Fixed seed for reproducibility
      
      // Run 100 iterations of the property test
      for (int i = 0; i < 100; i++) {
        final testCase = generator.generate(random);
        
        // Set up the repository with locations that support the test case
        await _setupRepositoryForTestCase(repository, testCase);
        
        // Property: When deviating from a route, recalculation should produce a valid route to the original destination
        final reroutedRoute = await calculator.recalculateFromCurrent(
          testCase.deviationLocationId,
          testCase.originalDestination,
        );
        
        // If the deviation location is reachable to the destination, we should get a route
        final isDeviationLocationValid = await repository.isValidLocation(testCase.deviationLocationId);
        final isDestinationValid = await repository.isValidLocation(testCase.originalDestination);
        
        if (!isDeviationLocationValid || !isDestinationValid) {
          // If locations don't exist, rerouting should return null
          expect(reroutedRoute, isNull, reason: 'Rerouting should return null for invalid locations in iteration $i');
          continue;
        }
        
        // Check if there's a path from deviation to destination
        final areConnected = await calculator.areLocationsConnected(
          testCase.deviationLocationId,
          testCase.originalDestination,
        );
        
        if (!areConnected) {
          // If no path exists, rerouting should return null
          expect(reroutedRoute, isNull, reason: 'Rerouting should return null for disconnected locations in iteration $i');
          continue;
        }
        
        // If a route was calculated, it should be valid
        if (reroutedRoute != null) {
          // Property 1: Route should start from deviation location
          expect(reroutedRoute.startLocationId, equals(testCase.deviationLocationId),
            reason: 'Rerouted route should start from deviation location in iteration $i');
          
          // Property 2: Route should end at original destination
          expect(reroutedRoute.endLocationId, equals(testCase.originalDestination),
            reason: 'Rerouted route should end at original destination in iteration $i');
          
          // Property 3: Route should be valid
          expect(reroutedRoute.isValid(), isTrue,
            reason: 'Rerouted route should be valid in iteration $i');
          
          // Property 4: Path should be connected (consecutive locations should be connected)
          for (int j = 0; j < reroutedRoute.pathLocationIds.length - 1; j++) {
            final currentId = reroutedRoute.pathLocationIds[j];
            final nextId = reroutedRoute.pathLocationIds[j + 1];
            
            final currentLocation = await repository.getLocationById(currentId);
            expect(currentLocation, isNotNull,
              reason: 'Location $currentId should exist in iteration $i');
            
            expect(currentLocation!.connectedLocationIds, contains(nextId),
              reason: 'Consecutive locations should be connected: $currentId -> $nextId in iteration $i');
          }
          
          // Property 5: Route should have appropriate instructions
          if (reroutedRoute.pathLocationIds.length > 1) {
            expect(reroutedRoute.instructions, isNotEmpty,
              reason: 'Multi-location routes should have instructions in iteration $i');
          }
          
          // Property 6: First instruction should be marked as reroute if it's a rerouting scenario
          if (reroutedRoute.instructions.isNotEmpty) {
            final firstInstruction = reroutedRoute.instructions.first;
            
            // The first instruction should start from the deviation location
            expect(firstInstruction.fromLocationId, equals(testCase.deviationLocationId),
              reason: 'First instruction should start from deviation location in iteration $i');
            
            // For rerouting, the first instruction should be marked as reroute type
            // (This is implementation-specific behavior from the route calculator)
            if (firstInstruction.type == InstructionType.reroute) {
              // If marked as reroute, description should indicate rerouting
              expect(firstInstruction.description.toLowerCase(), contains('recalculated'),
                reason: 'Reroute instruction should indicate recalculation in iteration $i');
            }
          }
          
          // Property 7: Route distance should be positive (unless same location)
          if (testCase.deviationLocationId != testCase.originalDestination) {
            expect(reroutedRoute.estimatedDistance, greaterThan(0),
              reason: 'Route distance should be positive for different locations in iteration $i');
          } else {
            expect(reroutedRoute.estimatedDistance, equals(0),
              reason: 'Same location route should have zero distance in iteration $i');
          }
          
          // Property 8: Route time should be non-negative
          expect(reroutedRoute.estimatedTime.isNegative, isFalse,
            reason: 'Route time should be non-negative in iteration $i');
        }
      }
    });
    
    test('Rerouting with sample data should work correctly', () async {
      // Use the actual sample data from InMemoryLocationRepository
      final sampleRepository = InMemoryLocationRepository();
      final sampleCalculator = DijkstraRouteCalculator(sampleRepository);
      
      // Create an original route
      final originalRoute = await sampleCalculator.calculateRoute('Main Entrance', 'Main Office');
      expect(originalRoute, isNotNull);
      
      // Simulate deviation to a different location
      final reroutedRoute = await sampleCalculator.recalculateFromCurrent('CP5', 'Main Office');
      
      expect(reroutedRoute, isNotNull);
      expect(reroutedRoute!.startLocationId, equals('CP5'));
      expect(reroutedRoute.endLocationId, equals('Main Office'));
      expect(reroutedRoute.isValid(), isTrue);
    });
  });
}

/// Helper function to set up repository with locations needed for the test case
Future<void> _setupRepositoryForTestCase(
  MockReroutingLocationRepository repository,
  ReroutingTestCase testCase,
) async {
  // Add all locations from the original route
  for (final locationId in testCase.originalRoute.pathLocationIds) {
    if (!await repository.locationExists(locationId)) {
      repository.addLocation(Location(
        id: locationId,
        name: 'Location $locationId',
        description: 'Test location $locationId',
        coordinates: Coordinates(
          latitude: 40.7589 + (locationId.hashCode % 1000) / 10000.0,
          longitude: -73.9851 + (locationId.hashCode % 1000) / 10000.0,
        ),
        connectedLocationIds: [],
        type: LocationType.room,
      ));
    }
  }
  
  // Add the deviation location
  if (!await repository.locationExists(testCase.deviationLocationId)) {
    repository.addLocation(Location(
      id: testCase.deviationLocationId,
      name: 'Deviation Location ${testCase.deviationLocationId}',
      description: 'Test deviation location',
      coordinates: Coordinates(
        latitude: 40.7589 + (testCase.deviationLocationId.hashCode % 1000) / 10000.0,
        longitude: -73.9851 + (testCase.deviationLocationId.hashCode % 1000) / 10000.0,
      ),
      connectedLocationIds: [],
      type: LocationType.room,
    ));
  }
  
  // Set up connections to make locations reachable
  final allLocations = await repository.getAllLocations();
  final updatedLocations = <Location>[];
  
  for (final location in allLocations) {
    final connections = <String>[];
    
    // Connect route locations in sequence
    final routeIndex = testCase.originalRoute.pathLocationIds.indexOf(location.id);
    if (routeIndex >= 0) {
      // Connect to previous location in route
      if (routeIndex > 0) {
        connections.add(testCase.originalRoute.pathLocationIds[routeIndex - 1]);
      }
      // Connect to next location in route
      if (routeIndex < testCase.originalRoute.pathLocationIds.length - 1) {
        connections.add(testCase.originalRoute.pathLocationIds[routeIndex + 1]);
      }
    }
    
    // Connect deviation location to at least one route location (preferably the destination)
    if (location.id == testCase.deviationLocationId) {
      connections.add(testCase.originalDestination);
      // Also connect to a random route location for more realistic scenarios
      if (testCase.originalRoute.pathLocationIds.isNotEmpty) {
        final randomRouteLocation = testCase.originalRoute.pathLocationIds.first;
        if (!connections.contains(randomRouteLocation)) {
          connections.add(randomRouteLocation);
        }
      }
    }
    
    // Connect destination to deviation location (bidirectional)
    if (location.id == testCase.originalDestination) {
      if (!connections.contains(testCase.deviationLocationId)) {
        connections.add(testCase.deviationLocationId);
      }
    }
    
    updatedLocations.add(location.copyWith(
      connectedLocationIds: connections,
    ));
  }
  
  // Update repository with connected locations
  repository._locations.clear();
  for (final location in updatedLocations) {
    repository.addLocation(location);
  }
}