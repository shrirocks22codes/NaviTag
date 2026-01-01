import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/services/route_calculator.dart';

void main() {
  group('Route Calculator Time Estimation', () {
    late RouteCalculator routeCalculator;
    late InMemoryLocationRepository locationRepository;

    setUp(() {
      locationRepository = InMemoryLocationRepository.withLocations([
        Location(
          id: 'start',
          name: 'Start Point',
          description: 'Starting location',
          coordinates: const Coordinates(latitude: 0, longitude: 0),
          connectedLocationIds: ['middle'],
          type: LocationType.entrance,
        ),
        Location(
          id: 'middle',
          name: 'Middle Point',
          description: 'Middle checkpoint',
          coordinates: const Coordinates(latitude: 0.0001, longitude: 0.0001),
          connectedLocationIds: ['start', 'end'],
          type: LocationType.hallway,
        ),
        Location(
          id: 'end',
          name: 'End Point',
          description: 'Destination location',
          coordinates: const Coordinates(latitude: 0.0002, longitude: 0.0002),
          connectedLocationIds: ['middle'],
          type: LocationType.room,
        ),
      ]);
      
      routeCalculator = DijkstraRouteCalculator(locationRepository);
    });

    test('calculates non-zero time for multi-checkpoint route', () async {
      final route = await routeCalculator.calculateRoute('start', 'end');
      
      expect(route, isNotNull);
      expect(route!.estimatedTime.inSeconds, greaterThan(0));
      expect(route.estimatedTime.inSeconds, greaterThanOrEqualTo(30)); // At least 30 seconds
    });

    test('includes checkpoint time in calculation', () async {
      final route = await routeCalculator.calculateRoute('start', 'end');
      
      expect(route, isNotNull);
      // Route has 3 locations (start -> middle -> end), so 2 segments
      // Should include time for walking plus checkpoint delays
      expect(route!.estimatedTime.inSeconds, greaterThanOrEqualTo(60)); // At least 1 minute for 2 checkpoints
    });

    test('single location route has zero time', () async {
      final route = await routeCalculator.calculateRoute('start', 'start');
      
      expect(route, isNotNull);
      expect(route!.estimatedTime.inSeconds, equals(0)); // Same location should be 0 seconds
    });
  });
}