import 'package:nfc_project_test/services/route_calculator.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';

void main() async {
  final repository = InMemoryLocationRepository();
  final calculator = DijkstraRouteCalculator(repository);
  
  print('Testing checkpoint inclusion in routes...\n');
  
  // Test route to Cafeteria (should include CP9)
  final routeToCafeteria = await calculator.calculateRoute('Main Entrance', 'Cafeteria');
  print('Route Main Entrance -> Cafeteria:');
  print('Path: ${routeToCafeteria?.pathLocationIds}');
  print('Contains CP9: ${routeToCafeteria?.containsLocation('CP9')}');
  print('');
  
  // Test route to Media Center (should include CP10)
  final routeToMediaCenter = await calculator.calculateRoute('Main Entrance', 'Media Center');
  print('Route Main Entrance -> Media Center:');
  print('Path: ${routeToMediaCenter?.pathLocationIds}');
  print('Contains CP10: ${routeToMediaCenter?.containsLocation('CP10')}');
  print('');
  
  // Test route that might include CPA
  final routeWithCPA = await calculator.calculateRoute('CP2', 'CP3');
  print('Route CP2 -> CP3:');
  print('Path: ${routeWithCPA?.pathLocationIds}');
  print('Contains CPA: ${routeWithCPA?.containsLocation('CPA')}');
  print('');
  
  // Test another route that might include CPA
  final routeWithCPA2 = await calculator.calculateRoute('Gym', '7 Red/7 Gold');
  print('Route Gym -> 7 Red/7 Gold:');
  print('Path: ${routeWithCPA2?.pathLocationIds}');
  print('Contains CPA: ${routeWithCPA2?.containsLocation('CPA')}');
  print('');
  
  // Check all locations to see connectivity
  final allLocations = await repository.getAllLocations();
  print('All locations:');
  for (final location in allLocations) {
    if (location.id.startsWith('CP')) {
      print('${location.id}: connects to ${location.connectedLocationIds}');
    }
  }
}