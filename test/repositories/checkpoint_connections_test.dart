import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';

void main() {
  group('Checkpoint Connections', () {
    late InMemoryLocationRepository repository;

    setUp(() {
      repository = InMemoryLocationRepository();
    });

    test('Checkpoint A connects to Checkpoint 3 but not Checkpoint 11', () async {
      final cpa = await repository.getLocationById('CPA');
      final cp3 = await repository.getLocationById('CP3');
      final cp11 = await repository.getLocationById('CP11');

      expect(cpa, isNotNull);
      expect(cp3, isNotNull);
      expect(cp11, isNotNull);

      // CPA should connect to CP3
      expect(cpa!.connectedLocationIds, contains('CP3'));
      
      // CPA should NOT connect to CP11
      expect(cpa.connectedLocationIds, isNot(contains('CP11')));
      
      // CP3 should connect to CPA (bidirectional)
      expect(cp3!.connectedLocationIds, contains('CPA'));
      
      // CP11 should NOT connect to CPA
      expect(cp11!.connectedLocationIds, isNot(contains('CPA')));
    });

    test('CPA connections are correct', () async {
      final cpa = await repository.getLocationById('CPA');
      
      expect(cpa, isNotNull);
      expect(cpa!.connectedLocationIds, equals(['CP3', 'CP2']));
    });

    test('can get connected locations from CPA', () async {
      final connectedLocations = await repository.getConnectedLocations('CPA');
      
      expect(connectedLocations.length, equals(2));
      expect(connectedLocations.any((loc) => loc.id == 'CP3'), isTrue);
      expect(connectedLocations.any((loc) => loc.id == 'CP2'), isTrue);
      expect(connectedLocations.any((loc) => loc.id == 'CP11'), isFalse);
    });
  });
}