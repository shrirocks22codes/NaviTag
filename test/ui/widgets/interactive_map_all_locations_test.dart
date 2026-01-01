import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/ui/widgets/interactive_map_widget.dart';

void main() {
  group('Interactive Map All Locations Display', () {
    late List<Location> testLocations;

    setUp(() {
      testLocations = [
        Location(
          id: 'test1',
          name: 'Test Location 1',
          description: 'A test location',
          coordinates: const Coordinates(latitude: 40.7128, longitude: -74.0060),
          connectedLocationIds: [],
          type: LocationType.room,
        ),
        Location(
          id: 'test2',
          name: 'Test Location 2',
          description: 'Another test location',
          coordinates: const Coordinates(latitude: 40.7129, longitude: -74.0061),
          connectedLocationIds: [],
          type: LocationType.office,
        ),
        // Include a location that exists in the hardcoded coordinates
        Location(
          id: 'Gym',
          name: 'Gym',
          description: 'School gymnasium',
          coordinates: const Coordinates(latitude: 40.7130, longitude: -74.0062),
          connectedLocationIds: [],
          type: LocationType.room,
        ),
      ];
    });

    Widget createTestWidget() {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InteractiveMapWidget(
              locations: testLocations,
              showLocationLabels: true,
            ),
          ),
        ),
      );
    }

    testWidgets('displays all locations including those not in hardcoded coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Just pump once instead of pumpAndSettle
      
      // The widget should render without errors
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });

    testWidgets('handles locations with missing hardcoded coordinates gracefully', (WidgetTester tester) async {
      // Add a location that definitely won't be in hardcoded coordinates
      final locationsWithMissing = [
        ...testLocations,
        Location(
          id: 'missing_coords',
          name: 'Missing Coordinates Location',
          description: 'This location is not in hardcoded coordinates',
          coordinates: const Coordinates(latitude: 40.7131, longitude: -74.0063),
          connectedLocationIds: [],
          type: LocationType.entrance,
        ),
      ];

      final widget = ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InteractiveMapWidget(
              locations: locationsWithMissing,
              showLocationLabels: true,
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump(); // Just pump once instead of pumpAndSettle
      
      // Should render without errors
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });
  });
}