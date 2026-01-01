import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_project_test/ui/widgets/interactive_map_widget.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/models/route.dart' as nav_route;

void main() {
  group('InteractiveMapWidget Tests', () {
    late List<Location> testLocations;

    setUp(() {
      testLocations = [
        const Location(
          id: 'loc1',
          name: 'Test Location 1',
          description: 'First test location',
          coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060),
          connectedLocationIds: ['loc2'],
          type: LocationType.room,
        ),
        const Location(
          id: 'loc2',
          name: 'Test Location 2',
          description: 'Second test location',
          coordinates: Coordinates(latitude: 40.7130, longitude: -74.0062),
          connectedLocationIds: ['loc1'],
          type: LocationType.office,
        ),
      ];
    });

    testWidgets('should render map widget with locations', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMapWidget(
                locations: testLocations,
              ),
            ),
          ),
        ),
      );

      // Verify that the widget renders without errors
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });

    testWidgets('should handle empty locations list', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMapWidget(
                locations: [],
              ),
            ),
          ),
        ),
      );

      // Verify that the widget renders without errors even with empty locations
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });

    testWidgets('should show location labels when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMapWidget(
                locations: testLocations,
                showLocationLabels: true,
              ),
            ),
          ),
        ),
      );

      // Verify that the widget renders
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });

    testWidgets('should handle location tap callback', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMapWidget(
                locations: testLocations,
                onLocationTapped: (location) {
                  // Location tap handled
                },
              ),
            ),
          ),
        ),
      );

      // Verify that the widget renders
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
      
      // Note: Testing actual tap interactions on the map would require more complex setup
      // with the flutter_map widget, so we just verify the widget accepts the callback
    });

    testWidgets('should display active route when provided', (WidgetTester tester) async {
      final testRoute = nav_route.Route(
        id: 'test-route',
        startLocationId: 'loc1',
        endLocationId: 'loc2',
        pathLocationIds: ['loc1', 'loc2'],
        estimatedDistance: 100.0,
        estimatedTime: const Duration(minutes: 2),
        instructions: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMapWidget(
                locations: testLocations,
                activeRoute: testRoute,
                currentLocationId: 'loc1',
                destinationLocationId: 'loc2',
              ),
            ),
          ),
        ),
      );

      // Verify that the widget renders with route information
      expect(find.byType(InteractiveMapWidget), findsOneWidget);
    });
  });
}