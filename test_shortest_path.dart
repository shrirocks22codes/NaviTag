// ignore_for_file: avoid_print
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/services/route_calculator.dart';

void main() async {
  // Create repository and calculator
  final repository = InMemoryLocationRepository();
  final calculator = DijkstraRouteCalculator(repository);
  
  // Test a few routes to verify shortest path
  print('Testing shortest path calculations...\n');
  
  // Test 1: Gym to Cafeteria
  final route1 = await calculator.calculateRoute('Gym', 'Cafeteria');
  if (route1 != null) {
    print('Gym to Cafeteria:');
    print('Path: ${route1.pathLocationIds.join(' -> ')}');
    print('Distance: ${route1.estimatedDistance.toStringAsFixed(1)}m');
    print('Time: ${route1.estimatedTime.inMinutes}min\n');
  }
  
  // Test 2: Main Office to Media Center
  final route2 = await calculator.calculateRoute('Main Office', 'Media Center');
  if (route2 != null) {
    print('Main Office to Media Center:');
    print('Path: ${route2.pathLocationIds.join(' -> ')}');
    print('Distance: ${route2.estimatedDistance.toStringAsFixed(1)}m');
    print('Time: ${route2.estimatedTime.inMinutes}min\n');
  }
  
  // Test 3: Auditorium to 7 Red/7 Gold
  final route3 = await calculator.calculateRoute('Auditorium', '7 Red/7 Gold');
  if (route3 != null) {
    print('Auditorium to 7 Red/7 Gold:');
    print('Path: ${route3.pathLocationIds.join(' -> ')}');
    print('Distance: ${route3.estimatedDistance.toStringAsFixed(1)}m');
    print('Time: ${route3.estimatedTime.inMinutes}min\n');
  }
  
  print('Shortest path testing complete!');
}
