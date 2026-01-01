import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/ui/widgets/starting_point_selector_widget.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';

void main() {
  group('StartingPointSelectorWidget', () {
    late List<Location> testLocations;

    setUp(() {
      testLocations = [
        Location(
          id: 'room1',
          name: 'Conference Room A',
          description: 'Main conference room',
          coordinates: const Coordinates(latitude: 0, longitude: 0),
          connectedLocationIds: ['hallway1'],
          type: LocationType.room,
        ),
        Location(
          id: 'entrance1',
          name: 'Main Entrance',
          description: 'Building main entrance',
          coordinates: const Coordinates(latitude: 1, longitude: 1),
          connectedLocationIds: ['hallway1'],
          type: LocationType.entrance,
        ),
      ];
    });

    Widget createTestWidget({
      void Function(Location)? onStartingPointSelected,
      bool showCurrentLocation = true,
    }) {
      return ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWith((ref) => InMemoryLocationRepository.withLocations(testLocations)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StartingPointSelectorWidget(
              onStartingPointSelected: onStartingPointSelected,
              showCurrentLocation: showCurrentLocation,
            ),
          ),
        ),
      );
    }

    testWidgets('displays correct header', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      expect(find.text('Select Starting Point'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('displays locations after loading', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      expect(find.text('Conference Room A'), findsOneWidget);
      expect(find.text('Main Entrance'), findsOneWidget);
    });

    testWidgets('calls callback when location is selected', (WidgetTester tester) async {
      Location? selectedLocation;
      
      await tester.pumpWidget(createTestWidget(
        onStartingPointSelected: (location) {
          selectedLocation = location;
        },
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Conference Room A'));
      await tester.pumpAndSettle();
      
      expect(selectedLocation?.id, equals('room1'));
      expect(selectedLocation?.name, equals('Conference Room A'));
    });
  });
}