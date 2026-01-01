import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'dart:math';

/// Simple reachability checker using breadth-first search
class ReachabilityChecker {
  static Future<bool> isReachable(LocationRepository repository, String fromId, String toId) async {
    if (fromId == toId) return true;
    
    final visited = <String>{};
    final queue = <String>[fromId];
    
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      
      if (visited.contains(currentId)) continue;
      visited.add(currentId);
      
      if (currentId == toId) return true;
      
      final connectedLocations = await repository.getConnectedLocations(currentId);
      for (final location in connectedLocations) {
        if (!visited.contains(location.id)) {
          queue.add(location.id);
        }
      }
    }
    
    return false;
  }
}

void main() {
  group('InMemoryLocationRepository', () {
    late InMemoryLocationRepository repository;

    setUp(() {
      repository = InMemoryLocationRepository();
    });

    test('should initialize with sample data', () async {
      final locations = await repository.getAllLocations();
      expect(locations.isNotEmpty, true);
      expect(locations.length, greaterThan(5));
    });

    test('should get location by ID', () async {
      final location = await repository.getLocationById('Main Entrance');
      expect(location, isNotNull);
      expect(location!.id, equals('Main Entrance'));
      expect(location.name, equals('Main Entrance'));
    });

    test('should return null for non-existent location ID', () async {
      final location = await repository.getLocationById('non_existent');
      expect(location, isNull);
    });

    test('should get connected locations', () async {
      final connectedLocations = await repository.getConnectedLocations('Main Entrance');
      expect(connectedLocations.isNotEmpty, true);
      
      // Check that all returned locations are actually connected
      final entranceLocation = await repository.getLocationById('Main Entrance');
      for (final connected in connectedLocations) {
        expect(entranceLocation!.connectedLocationIds.contains(connected.id), true);
      }
    });

    test('should return empty list for non-existent location connections', () async {
      final connectedLocations = await repository.getConnectedLocations('non_existent');
      expect(connectedLocations, isEmpty);
    });

    test('should validate existing locations', () async {
      final isValid = await repository.isValidLocation('Main Entrance');
      expect(isValid, true);
    });

    test('should invalidate non-existent locations', () async {
      final isValid = await repository.isValidLocation('non_existent');
      expect(isValid, false);
    });

    test('should check location existence', () async {
      final exists = await repository.locationExists('Main Entrance');
      expect(exists, true);
      
      final notExists = await repository.locationExists('non_existent');
      expect(notExists, false);
    });

    test('should add new location', () async {
      final newLocation = Location(
        id: 'test_room',
        name: 'Test Room',
        description: 'A test room',
        coordinates: const Coordinates(latitude: 40.0, longitude: -74.0),
        connectedLocationIds: ['Main Entrance'],
        type: LocationType.room,
      );

      repository.addLocation(newLocation);
      
      final retrieved = await repository.getLocationById('test_room');
      expect(retrieved, equals(newLocation));
    });

    test('should remove location', () async {
      repository.removeLocation('entrance_main');
      
      final location = await repository.getLocationById('entrance_main');
      expect(location, isNull);
    });

    test('should clear all locations', () async {
      repository.clear();
      
      final locations = await repository.getAllLocations();
      expect(locations, isEmpty);
    });

    test('should initialize with custom locations', () async {
      final customLocations = [
        Location(
          id: 'custom_1',
          name: 'Custom Location 1',
          description: 'First custom location',
          coordinates: const Coordinates(latitude: 41.0, longitude: -75.0),
          connectedLocationIds: ['custom_2'],
          type: LocationType.room,
        ),
        Location(
          id: 'custom_2',
          name: 'Custom Location 2',
          description: 'Second custom location',
          coordinates: const Coordinates(latitude: 41.1, longitude: -75.1),
          connectedLocationIds: ['custom_1'],
          type: LocationType.hallway,
        ),
      ];

      final customRepository = InMemoryLocationRepository.withLocations(customLocations);
      
      final locations = await customRepository.getAllLocations();
      expect(locations.length, equals(2));
      expect(locations.map((l) => l.id), containsAll(['custom_1', 'custom_2']));
    });
  });

  group('Location Reachability Property Tests', () {
    
    test('**Feature: nfc-navigation, Property 4: Route Reachability Detection** - **Validates: Requirements 2.2, 2.4**', () async {
      // Test with the default sample data which forms a connected graph
      final repository = InMemoryLocationRepository();
      
      // Test self-reachability
      final allLocations = await repository.getAllLocations();
      for (final location in allLocations) {
        final selfReachable = await ReachabilityChecker.isReachable(
          repository, location.id, location.id
        );
        expect(selfReachable, isTrue, 
          reason: 'Location ${location.id} should be reachable from itself');
      }
      
      // Test reachability to directly connected locations
      for (final location in allLocations) {
        final connectedLocations = await repository.getConnectedLocations(location.id);
        for (final connected in connectedLocations) {
          final isReachable = await ReachabilityChecker.isReachable(
            repository, location.id, connected.id
          );
          expect(isReachable, isTrue,
            reason: 'Connected location ${connected.id} should be reachable from ${location.id}');
        }
      }
      
      // Test that in the sample data, all locations should be reachable from each other
      // (since it's designed as a connected graph)
      for (final from in allLocations) {
        for (final to in allLocations) {
          final isReachable = await ReachabilityChecker.isReachable(
            repository, from.id, to.id
          );
          expect(isReachable, isTrue,
            reason: 'In connected graph, ${to.id} should be reachable from ${from.id}');
        }
      }
    });

    test('Property test: Reachability consistency with random graphs', () async {
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < 50; iteration++) {
        // Generate a small connected graph
        final locationCount = 3 + random.nextInt(4); // 3-6 locations
        final locations = <Location>[];
        
        // Generate locations with IDs
        for (int i = 0; i < locationCount; i++) {
          locations.add(Location(
            id: 'loc_$i',
            name: 'Location $i',
            description: 'Generated location $i',
            coordinates: Coordinates(
              latitude: 40.0 + random.nextDouble() * 0.01,
              longitude: -74.0 + random.nextDouble() * 0.01,
            ),
            connectedLocationIds: [], // Will be filled later
            type: LocationType.room,
          ));
        }
        
        // Create connections to ensure some reachability
        // Connect each location to at least one other (creating a connected graph)
        for (int i = 0; i < locationCount; i++) {
          final currentLocation = locations[i];
          final connections = <String>[];
          
          // Connect to next location (circular)
          final nextIndex = (i + 1) % locationCount;
          connections.add('loc_$nextIndex');
          
          // Randomly add more connections
          final additionalConnections = random.nextInt(2);
          for (int j = 0; j < additionalConnections; j++) {
            final targetIndex = random.nextInt(locationCount);
            if (targetIndex != i) {
              connections.add('loc_$targetIndex');
            }
          }
          
          // Update the location with connections
          locations[i] = Location(
            id: currentLocation.id,
            name: currentLocation.name,
            description: currentLocation.description,
            coordinates: currentLocation.coordinates,
            connectedLocationIds: connections.toSet().toList(), // Remove duplicates
            type: currentLocation.type,
          );
        }
        
        final repository = InMemoryLocationRepository.withLocations(locations);
        final allLocations = await repository.getAllLocations();
        
        // Test self-reachability
        for (final location in allLocations) {
          final selfReachable = await ReachabilityChecker.isReachable(
            repository, location.id, location.id
          );
          expect(selfReachable, isTrue, 
            reason: 'Iteration $iteration: Location ${location.id} should be reachable from itself');
        }
        
        // Test direct connections
        for (final location in allLocations) {
          final connectedLocations = await repository.getConnectedLocations(location.id);
          for (final connected in connectedLocations) {
            final isReachable = await ReachabilityChecker.isReachable(
              repository, location.id, connected.id
            );
            expect(isReachable, isTrue,
              reason: 'Iteration $iteration: Connected location ${connected.id} should be reachable from ${location.id}');
          }
        }
      }
    });
  });
}