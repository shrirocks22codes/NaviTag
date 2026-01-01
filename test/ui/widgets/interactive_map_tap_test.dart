import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/ui/widgets/interactive_map_widget.dart';

void main() {
  testWidgets('InteractiveMapWidget: Verify location taps on mobile screen', (WidgetTester tester) async {
    // 1. Simulate a mobile screen (iPhone 14 Pro dimensions)
    // This ensures we are testing the "zoomed out" state where targets are small
    tester.view.physicalSize = const Size(1179, 2556); // 393 x 852 logical points
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 2. Setup test data
    Location? lastTappedLocation;
    
    final testLocation = const Location(
      id: 'Gym', // Must match an ID in the widget's coordinate map
      name: 'Gymnasium',
      description: 'Main Gym',
      coordinates: Coordinates(latitude: 0, longitude: 0),
      connectedLocationIds: [],
      type: LocationType.room,
    );

    // 3. Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveMapWidget(
            locations: [testLocation],
            currentLocationId: 'Gym', // Highlights it with Icons.my_location
            onLocationTapped: (location) {
              lastTappedLocation = location;
            },
          ),
        ),
      ),
    );

    // Allow the LayoutBuilder to build and advance past initial frame
    // Note: We use pump() instead of pumpAndSettle() because the widget
    // has a continuous pulsing animation that never settles
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify the marker is present
    final markerFinder = find.byIcon(Icons.my_location);
    expect(markerFinder, findsOneWidget);

    // 5. Attempt to tap the marker
    // Note: If the touch target is too small, this might pass in code (exact coords)
    // but fail for users. The fix in the widget ensures the target is large enough.
    await tester.tap(markerFinder);
    await tester.pump();

    // 6. Verify the callback was triggered
    expect(lastTappedLocation, isNotNull);
    expect(lastTappedLocation!.id, equals('Gym'));
  });
}
