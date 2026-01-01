import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:nfc_project_test/models/nfc_tag_data.dart';
import '../property_test_framework.dart';

/// Generator for DateTime within reasonable bounds
class DateTimeGenerator extends Generator<DateTime> {
  @override
  DateTime generate(Random random) {
    // Generate dates within the last year to next year
    final now = DateTime.now();
    final minTime = now.subtract(const Duration(days: 365));
    final maxTime = now.add(const Duration(days: 365));
    
    final rangeDays = maxTime.difference(minTime).inDays;
    final randomDays = random.nextInt(rangeDays + 1);
    
    return minTime.add(Duration(days: randomDays));
  }
}

/// Generator for NFCTagData
class NFCTagDataGenerator extends Generator<NFCTagData> {
  final StringGenerator _stringGen = StringGenerator(minLength: 1, maxLength: 30);
  final DateTimeGenerator _dateGen = DateTimeGenerator();

  @override
  NFCTagData generate(Random random) {
    final locationId = _stringGen.generate(random);
    final timestamp = _dateGen.generate(random);
    
    // Generate additional data that won't make the tag too large
    final additionalData = <String, dynamic>{};
    final numEntries = random.nextInt(4); // 0-3 entries
    
    for (int i = 0; i < numEntries; i++) {
      final key = StringGenerator(minLength: 1, maxLength: 10).generate(random);
      final value = random.nextBool() 
        ? StringGenerator(minLength: 1, maxLength: 20).generate(random)
        : random.nextInt(1000);
      additionalData[key] = value;
    }
    
    return NFCTagData.create(
      locationId: locationId,
      timestamp: timestamp,
      additionalData: additionalData,
    );
  }
}

/// Generator for valid location IDs (alphanumeric strings)
class LocationIdGenerator extends Generator<String> {
  @override
  String generate(Random random) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final length = 3 + random.nextInt(17); // 3-19 characters
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }
}

void main() {
  group('NFCTagData Model Tests', () {
    // Property 1: NFC Tag Round-trip Consistency
    // This property tests that NFC tag encoding and decoding preserves all data
    createPropertyTest<NFCTagData>(
      description: 'NFC tag encoding/decoding round-trip preserves all data',
      generator: NFCTagDataGenerator(),
      property: (tagData) {
        // Encode to bytes and decode back
        final encoded = tagData.encode();
        final decoded = NFCTagData.decode(encoded);
        
        // The decoded tag data should be identical to the original
        return tagData == decoded;
      },
      iterations: 100,
      featureName: 'nfc-navigation',
      propertyNumber: 1,
      propertyText: 'NFC Tag Round-trip Consistency',
    );

    // Property test for checksum validation
    createPropertyTest<String>(
      description: 'Valid NFCTagData always passes checksum validation',
      generator: LocationIdGenerator(),
      property: (locationId) {
        final tagData = NFCTagData.create(locationId: locationId);
        
        // A properly created tag should always be valid
        return tagData.isValid();
      },
      iterations: 100,
    );

    // Property test for JSON serialization
    createPropertyTest<NFCTagData>(
      description: 'NFCTagData JSON serialization round-trip preserves data',
      generator: NFCTagDataGenerator(),
      property: (tagData) {
        final json = tagData.toJson();
        final deserialized = NFCTagData.fromJson(json);
        
        return tagData == deserialized;
      },
      iterations: 100,
    );

    // Property test for tag size limits
    createPropertyTest<NFCTagData>(
      description: 'Generated NFCTagData fits within NFC tag size limits',
      generator: NFCTagDataGenerator(),
      property: (tagData) {
        final encoded = tagData.encode();
        return NFCTagUtils.fitsInTag(encoded);
      },
      iterations: 100,
    );

    // Property test for format validation
    createPropertyTest<NFCTagData>(
      description: 'Valid NFCTagData always produces valid format when encoded',
      generator: NFCTagDataGenerator(),
      property: (tagData) {
        final encoded = tagData.encode();
        return NFCTagData.isValidFormat(encoded);
      },
      iterations: 100,
    );

    // Unit tests for specific edge cases
    group('Unit Tests', () {
      test('NFCTagData creation with automatic checksum works', () {
        final tagData = NFCTagData.create(
          locationId: 'test-location-123',
          additionalData: const {'floor': 2, 'building': 'A'},
        );

        expect(tagData.locationId, equals('test-location-123'));
        expect(tagData.isValid(), isTrue);
        expect(tagData.additionalData['floor'], equals(2));
        expect(tagData.additionalData['building'], equals('A'));
      });

      test('NFCTagData checksum validation detects corruption', () {
        final tagData = NFCTagData.create(locationId: 'test-location');
        
        // Create corrupted version with wrong checksum
        final corrupted = tagData.copyWith(checksum: 'invalid-checksum');
        
        expect(tagData.isValid(), isTrue);
        expect(corrupted.isValid(), isFalse);
      });

      test('NFCTagData encoding/decoding works correctly', () {
        final original = NFCTagData.create(
          locationId: 'room-101',
          additionalData: const {'type': 'classroom', 'capacity': 30},
        );

        final encoded = original.encode();
        final decoded = NFCTagData.decode(encoded);

        expect(decoded.locationId, equals(original.locationId));
        expect(decoded.additionalData, equals(original.additionalData));
        expect(decoded.checksum, equals(original.checksum));
        // Note: timestamp precision may be lost during JSON serialization
        expect(decoded.timestamp.millisecondsSinceEpoch, 
               equals(original.timestamp.millisecondsSinceEpoch));
        expect(decoded.isValid(), isTrue);
      });

      test('NFCTagData decode throws exception for invalid data', () {
        final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        
        expect(
          () => NFCTagData.decode(invalidBytes),
          throwsA(isA<NFCTagDataException>()),
        );
      });

      test('NFCTagData refreshChecksum updates checksum correctly', () {
        final original = NFCTagData.create(locationId: 'test');
        final corrupted = original.copyWith(checksum: 'wrong');
        final refreshed = corrupted.refreshChecksum();

        expect(corrupted.isValid(), isFalse);
        expect(refreshed.isValid(), isTrue);
        expect(refreshed.checksum, equals(original.checksum));
      });

      test('NFCTagData expiration check works correctly', () {
        final now = DateTime.now();
        final oldTimestamp = now.subtract(const Duration(hours: 2));
        final tagData = NFCTagData.create(
          locationId: 'test',
          timestamp: oldTimestamp,
        );

        expect(tagData.isExpired(const Duration(hours: 1)), isTrue);
        expect(tagData.isExpired(const Duration(hours: 3)), isFalse);
      });

      test('NFCTagUtils utility functions work correctly', () {
        final tagData = NFCTagData.create(locationId: 'test');
        
        expect(NFCTagUtils.estimateSize(tagData), greaterThan(0));
        expect(NFCTagUtils.fitsInTag(tagData.encode()), isTrue);
        
        final json = tagData.toJson();
        expect(NFCTagUtils.hasRequiredFields(json), isTrue);
        
        final incompleteJson = {'locationId': 'test'};
        expect(NFCTagUtils.hasRequiredFields(incompleteJson), isFalse);
      });

      test('NFCTagUtils createMinimal and createMaximal work', () {
        final minimal = NFCTagUtils.createMinimal('test-location');
        expect(minimal.locationId, equals('test-location'));
        expect(minimal.additionalData.isEmpty, isTrue);
        expect(minimal.isValid(), isTrue);

        final maximal = NFCTagUtils.createMaximal(
          'test-location',
          {'key1': 'value1', 'key2': 'value2'},
        );
        expect(maximal.locationId, equals('test-location'));
        expect(maximal.isValid(), isTrue);
        expect(NFCTagUtils.fitsInTag(maximal.encode()), isTrue);
      });
    });
  });
}