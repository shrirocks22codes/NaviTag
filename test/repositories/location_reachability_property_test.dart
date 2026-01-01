import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';

/// Simple reachability checker using breadth-first search
class ReachabilityChecker {
  static Future<bool> isReachable(LocationRepository repository, String fromId, String toId) async {
    if (fromId == toId) return true;
    
    final visited = <String>{};
    final queue = <String>[fromId];
    
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      
      if (visited.contains(currentId)) continue;
      visited.add(currentId);
      
      if (currentId == toId) return true;
      
      final connectedLocations = await repository.getConnectedLocations(currentId);
      for (final location in connectedLocations) {
        if (!visited.contains(location.id)) {
          queue.add(location.id);
        }
      }
    }
    
    return false;
  }
}

void main() {
  group('Location Reachability Property Tests', () {
    
    test('**Feature: nfc-navigation, Property 4: Route Reachability Detection** - **Validates: Requirements 2.2, 2.4**', () async {
      // Test with the default sample data which forms a connected graph
      final repository = InMemoryLocationRepository();
      
      // Test self-reachability
      final allLocations = await repository.getAllLocations();
      for (final location in allLocations) {
        final selfReachable = await ReachabilityChecker.isReachable(
          repository, location.id, location.id
        );
        expect(selfReachable, isTrue, 
          reason: 'Location ${location.id} should be reachable from itself');
      }
      
      // Test reachability to directly connected locations
      for (final location in allLocations) {
        final connectedLocations = await repository.getConnectedLocations(location.id);
        for (final connected in connectedLocations) {
          final isReachable = await ReachabilityChecker.isReachable(
            repository, location.id, connected.id
          );
          expect(isReachable, isTrue,
            reason: 'Connected location ${connected.id} should be reachable from ${location.id}');
        }
      }
      
      // Test that in the sample data, all locations should be reachable from each other
      // (since it's designed as a connected graph)
      for (final from in allLocations) {
        for (final to in allLocations) {
          final isReachable = await ReachabilityChecker.isReachable(
            repository, from.id, to.id
          );
          expect(isReachable, isTrue,
            reason: 'In connected graph, ${to.id} should be reachable from ${from.id}');
        }
      }
    });
  });
}