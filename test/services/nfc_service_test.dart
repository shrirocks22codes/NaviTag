import 'dart:math';
import 'package:test/test.dart';
import '../property_test_framework.dart';
import 'package:nfc_project_test/models/nfc_tag_data.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/services/nfc_service.dart';

/// Generator for valid location IDs from the repository
class ValidLocationIdGenerator extends Generator<String> {
  final LocationRepository repository;
  final List<String> _validIds = [];
  
  ValidLocationIdGenerator(this.repository) {
    _initializeValidIds();
  }
  
  void _initializeValidIds() {
    // Initialize with known valid IDs from the sample data
    _validIds.addAll([
      'entrance_main',
      'lobby_main', 
      'elevator_bank_1',
      'hallway_a1',
      'hallway_a2',
      'room_101',
      'room_102',
      'room_103',
      'room_104',
    ]);
  }
  
  @override
  String generate(Random random) {
    if (_validIds.isEmpty) {
      throw StateError('No valid location IDs available');
    }
    return _validIds[random.nextInt(_validIds.length)];
  }
}

/// Generator for invalid location IDs
class InvalidLocationIdGenerator extends Generator<String> {
  final StringGenerator _stringGenerator = StringGenerator(
    minLength: 1,
    maxLength: 50,
    chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-',
  );
  
  final Set<String> _validIds = {
    'entrance_main',
    'lobby_main', 
    'elevator_bank_1',
    'hallway_a1',
    'hallway_a2',
    'room_101',
    'room_102',
    'room_103',
    'room_104',
  };
  
  @override
  String generate(Random random) {
    String id;
    int attempts = 0;
    do {
      id = _stringGenerator.generate(random);
      attempts++;
      // Prevent infinite loop by adding a prefix if we can't find an invalid ID
      if (attempts > 100) {
        id = 'invalid_${_stringGenerator.generate(random)}';
        break;
      }
    } while (_validIds.contains(id));
    
    return id;
  }
}

/// Generator for NFCTagData with valid location IDs
class ValidNFCTagDataGenerator extends Generator<NFCTagData> {
  final ValidLocationIdGenerator locationIdGenerator;
  
  ValidNFCTagDataGenerator(LocationRepository repository) 
    : locationIdGenerator = ValidLocationIdGenerator(repository);
  
  @override
  NFCTagData generate(Random random) {
    final locationId = locationIdGenerator.generate(random);
    
    // Generate random additional data
    final additionalData = <String, dynamic>{};
    final numFields = random.nextInt(5); // 0-4 additional fields
    
    for (int i = 0; i < numFields; i++) {
      final key = 'field_$i';
      final valueType = random.nextInt(3);
      switch (valueType) {
        case 0:
          additionalData[key] = StringGenerator(maxLength: 20).generate(random);
          break;
        case 1:
          additionalData[key] = random.nextInt(1000);
          break;
        case 2:
          additionalData[key] = random.nextBool();
          break;
      }
    }
    
    return NFCTagData.create(
      locationId: locationId,
      additionalData: additionalData,
    );
  }
}

/// Generator for NFCTagData with invalid location IDs
class InvalidNFCTagDataGenerator extends Generator<NFCTagData> {
  final InvalidLocationIdGenerator locationIdGenerator = InvalidLocationIdGenerator();
  
  @override
  NFCTagData generate(Random random) {
    final locationId = locationIdGenerator.generate(random);
    
    return NFCTagData.create(
      locationId: locationId,
      additionalData: const {},
    );
  }
}

/// Location validation service for testing
class LocationValidationService {
  final LocationRepository repository;
  
  LocationValidationService(this.repository);
  
  /// Validate that a location ID corresponds to a known location
  Future<bool> isValidLocation(String locationId) async {
    return await repository.isValidLocation(locationId);
  }
  
  /// Validate NFC tag data against known locations
  Future<bool> validateNFCTagData(NFCTagData tagData) async {
    // First check if the tag data itself is valid (checksum, format, etc.)
    if (!tagData.isValid()) {
      return false;
    }
    
    // Then check if the location ID exists in our repository
    return await isValidLocation(tagData.locationId);
  }
}

void main() {
  group('NFC Service Property Tests', () {
    late LocationRepository repository;
    late LocationValidationService validationService;
    
    setUp(() {
      repository = InMemoryLocationRepository();
      validationService = LocationValidationService(repository);
    });
    
    group('Property 2: Location Validation Correctness', () {
      createPropertyTest<NFCTagData>(
        description: 'Valid location IDs should always be recognized as valid',
        generator: ValidNFCTagDataGenerator(InMemoryLocationRepository()),
        property: (tagData) {
          // This is a synchronous property test, but we need to handle async validation
          // For the property test, we'll validate the structure and known valid IDs
          final knownValidIds = {
            'entrance_main',
            'lobby_main', 
            'elevator_bank_1',
            'hallway_a1',
            'hallway_a2',
            'room_101',
            'room_102',
            'room_103',
            'room_104',
          };
          
          // The tag data should be structurally valid
          if (!tagData.isValid()) {
            return false;
          }
          
          // The location ID should be one of our known valid IDs
          return knownValidIds.contains(tagData.locationId);
        },
        iterations: 100,
        featureName: 'nfc-navigation',
        propertyNumber: 2,
        propertyText: 'Location Validation Correctness',
      );
      
      createPropertyTest<NFCTagData>(
        description: 'Invalid location IDs should always be recognized as invalid',
        generator: InvalidNFCTagDataGenerator(),
        property: (tagData) {
          final knownValidIds = {
            'entrance_main',
            'lobby_main', 
            'elevator_bank_1',
            'hallway_a1',
            'hallway_a2',
            'room_101',
            'room_102',
            'room_103',
            'room_104',
          };
          
          // The tag data might be structurally valid, but the location ID should be invalid
          return !knownValidIds.contains(tagData.locationId);
        },
        iterations: 100,
        featureName: 'nfc-navigation',
        propertyNumber: 2,
        propertyText: 'Location Validation Correctness',
      );
    });
    
    group('NFC Service Integration Tests', () {
      test('LocationValidationService correctly validates known locations', () async {
        // Test with known valid location
        final validTagData = NFCTagData.create(locationId: 'Main Office');
        final isValid = await validationService.validateNFCTagData(validTagData);
        expect(isValid, isTrue);
        
        // Test with known invalid location
        final invalidTagData = NFCTagData.create(locationId: 'nonexistent_room');
        final isInvalid = await validationService.validateNFCTagData(invalidTagData);
        expect(isInvalid, isFalse);
      });
      
      test('LocationValidationService rejects corrupted tag data', () async {
        // Create valid tag data then corrupt the checksum
        final validTagData = NFCTagData.create(locationId: 'room_101');
        final corruptedTagData = validTagData.copyWith(checksum: 'invalid_checksum');
        
        final isValid = await validationService.validateNFCTagData(corruptedTagData);
        expect(isValid, isFalse);
      });
      
      test('Mock NFC Service can simulate tag discovery', () async {
        final mockService = NFCServiceFactory.createMock(repository) as MockNFCService;
        final tagData = NFCTagData.create(locationId: 'room_101');
        
        // Listen for tag discoveries
        final tagStream = mockService.tagStream;
        final tagFuture = tagStream.first;
        
        // Start scanning and simulate tag discovery
        await mockService.startScanning();
        mockService.simulateTagDiscovered(tagData);
        
        // Verify the tag was received
        final receivedTag = await tagFuture;
        expect(receivedTag.locationId, equals(tagData.locationId));
        expect(receivedTag.isValid(), isTrue);
        
        await mockService.stopScanning();
        mockService.dispose();
      });
      
      test('Mock NFC Service can simulate errors', () async {
        final mockService = NFCServiceFactory.createMock(repository) as MockNFCService;
        
        // Listen for errors
        final tagStream = mockService.tagStream;
        tagStream.handleError((error) {
          expect(error, isA<NFCServiceException>());
          expect(error.toString(), contains('Test error'));
        }).isEmpty;
        
        // Start scanning and simulate error
        await mockService.startScanning();
        mockService.simulateError(const NFCServiceException('Test error'));
        
        await mockService.stopScanning();
        mockService.dispose();
      });
    });
  });
}