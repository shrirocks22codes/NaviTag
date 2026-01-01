import 'dart:math';
import 'package:test/test.dart';
import 'package:nfc_project_test/models/location.dart';
import '../property_test_framework.dart';

/// Generator for Coordinates
class CoordinatesGenerator extends Generator<Coordinates> {
  @override
  Coordinates generate(Random random) {
    return Coordinates(
      latitude: -90.0 + random.nextDouble() * 180.0, // -90 to 90
      longitude: -180.0 + random.nextDouble() * 360.0, // -180 to 180
      altitude: random.nextBool() ? random.nextDouble() * 1000.0 : null,
    );
  }
}

/// Generator for LocationType
class LocationTypeGenerator extends Generator<LocationType> {
  @override
  LocationType generate(Random random) {
    return LocationType.values[random.nextInt(LocationType.values.length)];
  }
}

/// Generator for Location
class LocationGenerator extends Generator<Location> {
  final StringGenerator _stringGen = StringGenerator(minLength: 1, maxLength: 50);
  final CoordinatesGenerator _coordGen = CoordinatesGenerator();
  final LocationTypeGenerator _typeGen = LocationTypeGenerator();
  final ListGenerator<String> _connectionGen = ListGenerator(
    StringGenerator(minLength: 1, maxLength: 20),
    minLength: 0,
    maxLength: 5,
  );

  @override
  Location generate(Random random) {
    return Location(
      id: _stringGen.generate(random),
      name: _stringGen.generate(random),
      description: _stringGen.generate(random),
      coordinates: _coordGen.generate(random),
      connectedLocationIds: _connectionGen.generate(random),
      type: _typeGen.generate(random),
      metadata: _generateMetadata(random),
    );
  }

  Map<String, dynamic> _generateMetadata(Random random) {
    final size = random.nextInt(4); // 0-3 metadata entries
    final metadata = <String, dynamic>{};
    
    for (int i = 0; i < size; i++) {
      final key = _stringGen.generate(random);
      final value = random.nextBool() 
        ? _stringGen.generate(random)
        : random.nextInt(1000);
      metadata[key] = value;
    }
    
    return metadata;
  }
}

void main() {
  group('Location Model Tests', () {
    // Property 10: Current Position Updates
    // This property tests that location data can be properly serialized and deserialized,
    // which is essential for updating current position in the system
    createPropertyTest<Location>(
      description: 'Location serialization round-trip preserves all data',
      generator: LocationGenerator(),
      property: (location) {
        // Serialize to JSON and back
        final json = location.toJson();
        final deserialized = Location.fromJson(json);
        
        // The deserialized location should be identical to the original
        return location == deserialized;
      },
      iterations: 100,
      featureName: 'nfc-navigation',
      propertyNumber: 10,
      propertyText: 'Current Position Updates',
    );

    // Additional property test for coordinates serialization
    createPropertyTest<Coordinates>(
      description: 'Coordinates serialization round-trip preserves precision',
      generator: CoordinatesGenerator(),
      property: (coordinates) {
        final json = coordinates.toJson();
        final deserialized = Coordinates.fromJson(json);
        return coordinates == deserialized;
      },
      iterations: 100,
    );

    // Property test for LocationType enum serialization
    createPropertyTest<LocationType>(
      description: 'LocationType serialization round-trip is consistent',
      generator: LocationTypeGenerator(),
      property: (locationType) {
        final json = locationType.toJson();
        final deserialized = LocationType.fromJson(json);
        return locationType == deserialized;
      },
      iterations: 100,
    );

    // Unit tests for specific edge cases
    group('Unit Tests', () {
      test('Location equality works correctly', () {
        final location1 = Location(
          id: 'test1',
          name: 'Test Location',
          description: 'A test location',
          coordinates: const Coordinates(latitude: 40.7128, longitude: -74.0060),
          connectedLocationIds: const ['loc2', 'loc3'],
          type: LocationType.room,
          metadata: const {'floor': 2},
        );

        final location2 = Location(
          id: 'test1',
          name: 'Test Location',
          description: 'A test location',
          coordinates: const Coordinates(latitude: 40.7128, longitude: -74.0060),
          connectedLocationIds: const ['loc2', 'loc3'],
          type: LocationType.room,
          metadata: const {'floor': 2},
        );

        expect(location1, equals(location2));
      });

      test('Location copyWith creates proper copy', () {
        final original = Location(
          id: 'test1',
          name: 'Original',
          description: 'Original description',
          coordinates: const Coordinates(latitude: 40.7128, longitude: -74.0060),
          connectedLocationIds: const ['loc2'],
          type: LocationType.room,
          metadata: const {'floor': 1},
        );

        final copy = original.copyWith(name: 'Updated');

        expect(copy.id, equals(original.id));
        expect(copy.name, equals('Updated'));
        expect(copy.description, equals(original.description));
        expect(copy != original, isTrue);
      });

      test('LocationType fromJson handles invalid values gracefully', () {
        final result = LocationType.fromJson('invalid_type');
        expect(result, equals(LocationType.room)); // Should default to room
      });

      test('Coordinates handles null altitude correctly', () {
        final coords1 = const Coordinates(latitude: 1.0, longitude: 2.0);
        final coords2 = const Coordinates(latitude: 1.0, longitude: 2.0, altitude: null);
        
        expect(coords1, equals(coords2));
        expect(coords1.altitude, isNull);
      });
    });
  });
}