import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/models/location.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/services/route_calculator.dart';

void main() {
  group('Debug Checkpoint Highlighting', () {
    late InMemoryLocationRepository repository;
    late DijkstraRouteCalculator routeCalculator;

    setUp(() {
      repository = InMemoryLocationRepository();
      routeCalculator = DijkstraRouteCalculator(repository);
    });

    test('check if CPA, CP9 and CP10 exist in location repository', () async {
      final allLocations = await repository.getAllLocations();
      
      Location? cpa;
      Location? cp9;
      Location? cp10;
      
      try {
        cpa = allLocations.firstWhere((loc) => loc.id == 'CPA');
      } catch (e) {
        // Not found
      }
      
      try {
        cp9 = allLocations.firstWhere((loc) => loc.id == 'CP9');
      } catch (e) {
        // Not found
      }
      
      try {
        cp10 = allLocations.firstWhere((loc) => loc.id == 'CP10');
      } catch (e) {
        // Not found
      }
      
      print('Total locations in repository: ${allLocations.length}');
      print('CPA exists: ${cpa != null}');
      print('CP9 exists: ${cp9 != null}');
      print('CP10 exists: ${cp10 != null}');
      
      if (cpa != null) {
        print('CPA details: ${cpa.id}, ${cpa.name}, type: ${cpa.type}');
      }
      if (cp9 != null) {
        print('CP9 details: ${cp9.id}, ${cp9.name}, type: ${cp9.type}');
      }
      if (cp10 != null) {
        print('CP10 details: ${cp10.id}, ${cp10.name}, type: ${cp10.type}');
      }
    });

    test('check if CPA, CP9 and CP10 are included in routes', () async {
      // Test a route that should include CPA
      final routeWithCPA = await routeCalculator.calculateRoute('CP2', 'CP3');
      print('Route CP2->CP3 path: ${routeWithCPA?.pathLocationIds}');
      print('Contains CPA: ${routeWithCPA?.containsLocation('CPA')}');
      
      // Test a route that should include CP9 (cafeteria area)
      final routeToCafeteria = await routeCalculator.calculateRoute('Main Entrance', 'Cafeteria');
      print('Route to Cafeteria path: ${routeToCafeteria?.pathLocationIds}');
      print('Contains CP9: ${routeToCafeteria?.containsLocation('CP9')}');
      
      // Test a route that should include CP10 (media center area)
      final routeToMediaCenter = await routeCalculator.calculateRoute('Main Entrance', 'Media Center');
      print('Route to Media Center path: ${routeToMediaCenter?.pathLocationIds}');
      print('Contains CP10: ${routeToMediaCenter?.containsLocation('CP10')}');
    });
  });
}