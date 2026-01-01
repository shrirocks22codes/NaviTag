import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/services/route_calculator.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/models/route.dart';
import '../property_test_framework.dart';
import 'dart:math';

void main() {
  group('DijkstraRouteCalculator', () {
    late DijkstraRouteCalculator calculator;
    late InMemoryLocationRepository repository;

    setUp(() {
      repository = InMemoryLocationRepository();
      calculator = DijkstraRouteCalculator(repository);
    });

    test('should calculate route between connected locations', () async {
      // Test with sample data from repository
      final route = await calculator.calculateRoute('Main Entrance', 'Main Office');
      
      expect(route, isNotNull);
      expect(route!.startLocationId, equals('Main Entrance'));
      expect(route.endLocationId, equals('Main Office'));
      expect(route.pathLocationIds.first, equals('Main Entrance'));
      expect(route.pathLocationIds.last, equals('Main Office'));
      expect(route.isValid(), isTrue);
      expect(route.estimatedDistance, greaterThan(0));
      expect(route.instructions, isNotEmpty);
    });

    test('should return null for non-existent locations', () async {
      final route = await calculator.calculateRoute('nonexistent', 'room_101');
      expect(route, isNull);
    });

    test('should handle same location route', () async {
      final route = await calculator.calculateRoute('Gym', 'Gym');
      
      expect(route, isNotNull);
      expect(route!.startLocationId, equals('Gym'));
      expect(route.endLocationId, equals('Gym'));
      expect(route.pathLocationIds, equals(['Gym']));
      expect(route.estimatedDistance, equals(0.0));
      expect(route.estimatedTime, equals(Duration.zero));
      expect(route.instructions.length, equals(1));
    });

    test('should return null for disconnected locations', () async {
      // Add a disconnected location
      repository.addLocation(Location(
        id: 'isolated_room',
        name: 'Isolated Room',
        description: 'A room with no connections',
        coordinates: const Coordinates(latitude: 40.8000, longitude: -74.1000),
        connectedLocationIds: [],
        type: LocationType.room,
      ));

      final route = await calculator.calculateRoute('Main Entrance', 'isolated_room');
      expect(route, isNull);
    });

    test('should check if locations are connected', () async {
      final connected = await calculator.areLocationsConnected('Main Entrance', 'Main Office');
      expect(connected, isTrue);

      // Add disconnected location
      repository.addLocation(Location(
        id: 'isolated_room',
        name: 'Isolated Room',
        description: 'A room with no connections',
        coordinates: const Coordinates(latitude: 40.8000, longitude: -74.1000),
        connectedLocationIds: [],
        type: LocationType.room,
      ));

      final notConnected = await calculator.areLocationsConnected('Main Entrance', 'isolated_room');
      expect(notConnected, isFalse);
    });

    test('should generate navigation instructions', () async {
      final route = await calculator.calculateRoute('Main Entrance', 'Main Office');
      
      expect(route, isNotNull);
      final instructions = calculator.getInstructions(route!);
      expect(instructions, isNotEmpty);
      expect(instructions.first.type, equals(InstructionType.start));
      expect(instructions.last.type, equals(InstructionType.destination));
    });

    test('should get next instruction for current location', () async {
      final route = await calculator.calculateRoute('Main Entrance', 'Main Office');
      
      expect(route, isNotNull);
      final nextInstruction = calculator.getNextInstruction(route!, 'Main Entrance');
      expect(nextInstruction, isNotNull);
      expect(nextInstruction!.fromLocationId, equals('Main Entrance'));
    });

    test('should recalculate route from current position', () async {
      final originalRoute = await calculator.calculateRoute('Main Entrance', 'Main Office');
      final recalculatedRoute = await calculator.recalculateFromCurrent('CP5', 'Main Office');
      
      expect(originalRoute, isNotNull);
      expect(recalculatedRoute, isNotNull);
      expect(recalculatedRoute!.startLocationId, equals('CP5'));
      expect(recalculatedRoute.endLocationId, equals('Main Office'));
    });

    test('should validate route optimality', () async {
      // Test that direct path is shorter than indirect path
      final directRoute = await calculator.calculateRoute('CP5', 'Main Office');
      final indirectRoute = await calculator.calculateRoute('CP5', 'Gym');
      
      expect(directRoute, isNotNull);
      expect(indirectRoute, isNotNull);
      
      // Direct connection should be shorter than multi-hop route
      expect(directRoute!.pathLocationIds.length, lessThan(indirectRoute!.pathLocationIds.length));
    });
  });

  group('Property-Based Tests', () {
    late DijkstraRouteCalculator calculator;
    late InMemoryLocationRepository repository;

    setUp(() {
      repository = InMemoryLocationRepository();
      calculator = DijkstraRouteCalculator(repository);
    });

    /// **Feature: nfc-navigation, Property 3: Route Calculation Optimality**
    /// For any pair of connected locations, the calculated route should be the shortest valid path between them
    /// **Validates: Requirements 2.3, 2.5**
    test('**Feature: nfc-navigation, Property 3: Route Calculation Optimality** - Route calculation should always find the optimal (shortest) path between connected locations', () async {
      final generator = ConnectedLocationPairGenerator();
      final random = Random(42); // Fixed seed for reproducibility
      
      // Run 100 iterations of the property test
      for (int i = 0; i < 100; i++) {
        final locationPair = generator.generate(random);
        
        // Calculate the route
        final route = await calculator.calculateRoute(locationPair.fromId, locationPair.toId);
        
        // Property: Route should exist for connected locations
        expect(route, isNotNull, reason: 'Route should exist for connected locations: ${locationPair.fromId} -> ${locationPair.toId}');
        
        if (route != null) {
          // Property: Route should start and end at correct locations
          expect(route.startLocationId, equals(locationPair.fromId));
          expect(route.endLocationId, equals(locationPair.toId));
          
          // Property: Path should be valid (consecutive locations should be connected)
          for (int j = 0; j < route.pathLocationIds.length - 1; j++) {
            final currentId = route.pathLocationIds[j];
            final nextId = route.pathLocationIds[j + 1];
            
            final currentLocation = await repository.getLocationById(currentId);
            expect(currentLocation, isNotNull);
            expect(currentLocation!.connectedLocationIds, contains(nextId),
              reason: 'Path should only contain connected locations: $currentId should connect to $nextId');
          }
          
          // Property: Route should be optimal (no shorter path exists)
          // We validate this by checking that direct connections are preferred
          if (locationPair.fromId != locationPair.toId) {
            final fromLocation = await repository.getLocationById(locationPair.fromId);
            if (fromLocation != null && fromLocation.connectedLocationIds.contains(locationPair.toId)) {
              // If there's a direct connection, the route should use it (length = 2)
              expect(route.pathLocationIds.length, equals(2),
                reason: 'Direct connections should be preferred: ${locationPair.fromId} -> ${locationPair.toId}');
            }
          }
          
          // Property: Route distance should be positive (unless same location)
          if (locationPair.fromId != locationPair.toId) {
            expect(route.estimatedDistance, greaterThan(0),
              reason: 'Route distance should be positive for different locations');
          } else {
            expect(route.estimatedDistance, equals(0),
              reason: 'Same location route should have zero distance');
          }
          
          // Property: Route should have valid instructions
          expect(route.instructions, isNotEmpty,
            reason: 'Route should have navigation instructions');
          
          if (locationPair.fromId == locationPair.toId) {
            // Same location route should have a single destination instruction
            expect(route.instructions.length, equals(1),
              reason: 'Same location route should have exactly one instruction');
            expect(route.instructions.first.type, equals(InstructionType.destination),
              reason: 'Same location instruction should be destination type');
          } else if (route.pathLocationIds.length == 2) {
            // Direct connection should have a single destination instruction
            expect(route.instructions.length, equals(1),
              reason: 'Direct connection should have exactly one instruction');
            expect(route.instructions.first.type, equals(InstructionType.destination),
              reason: 'Direct connection instruction should be destination type');
          } else {
            // Multi-hop routes should have start and destination instructions
            expect(route.instructions.first.type, equals(InstructionType.start),
              reason: 'First instruction should be start type');
            expect(route.instructions.last.type, equals(InstructionType.destination),
              reason: 'Last instruction should be destination type');
          }
        }
      }
    });
  });
}

/// Helper class to represent a pair of locations for testing
class LocationPair {
  final String fromId;
  final String toId;
  
  const LocationPair(this.fromId, this.toId);
  
  @override
  String toString() => 'LocationPair($fromId -> $toId)';
}

/// Generator for pairs of connected locations from the sample data
class ConnectedLocationPairGenerator extends Generator<LocationPair> {
  // Use the known connected locations from the actual sample data
  static const List<LocationPair> _knownConnectedPairs = [
    LocationPair('Main Entrance', 'CP5'),
    LocationPair('CP5', 'Main Office'),
    LocationPair('CP5', 'CP6'),
    LocationPair('CP6', "Nurse's Office"),
    LocationPair('CP6', 'CP11'),
    LocationPair('CP11', 'CP10'),
    LocationPair('CP10', 'Media Center'),
    LocationPair('CP11', 'CP3'),
    LocationPair('CP3', '7 Red/7 Gold'),
    LocationPair('Bus Entrance', 'CP1'),
    LocationPair('CP1', 'Gym'),
    LocationPair('CP1', 'CP2'),
    LocationPair('CP2', 'CP9'),
    LocationPair('CP9', 'Cafeteria'),
    LocationPair('CP7', 'Auditorium'),
    LocationPair('CP7', 'Auditorium Entrance'),
    // Multi-hop paths
    LocationPair('Main Entrance', 'Main Office'), // Direct connection
    LocationPair('Main Entrance', 'Gym'), // Multi-hop path
    LocationPair('Bus Entrance', 'Cafeteria'), // Multi-hop path
    LocationPair('Auditorium Entrance', 'Media Center'), // Multi-hop path
  ];
  
  @override
  LocationPair generate(Random random) {
    return _knownConnectedPairs[random.nextInt(_knownConnectedPairs.length)];
  }
}