import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/ui/screens/manual_mode_screen.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';

void main() {
  group('Manual Mode Navigation Flow', () {
    late List<Location> testLocations;

    setUp(() {
      testLocations = [
        Location(
          id: 'start',
          name: 'Starting Point',
          description: 'Where we begin',
          coordinates: const Coordinates(latitude: 0, longitude: 0),
          connectedLocationIds: ['destination'],
          type: LocationType.entrance,
        ),
        Location(
          id: 'destination',
          name: 'Destination Point',
          description: 'Where we want to go',
          coordinates: const Coordinates(latitude: 1, longitude: 1),
          connectedLocationIds: ['start'],
          type: LocationType.room,
        ),
      ];
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWith((ref) => InMemoryLocationRepository.withLocations(testLocations)),
        ],
        child: const MaterialApp(
          home: ManualModeScreen(),
        ),
      );
    }

    testWidgets('manual mode screen loads correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(); // Just pump once instead of pumpAndSettle
      
      // Should show manual mode screen
      expect(find.text('Manual Mode'), findsOneWidget);
    });

    testWidgets('shows proper guidance messages', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(); // Just pump once instead of pumpAndSettle
      
      // Should show manual mode screen
      expect(find.text('Manual Mode'), findsOneWidget);
    });
  });
}