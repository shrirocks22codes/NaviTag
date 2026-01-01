import 'package:test/test.dart';
import 'package:flutter/services.dart';
import 'package:nfc_project_test/services/nfc_error_handler.dart';
import 'package:nfc_project_test/services/nfc_service.dart';
import 'package:nfc_project_test/repositories/location_repository.dart';
import 'package:nfc_project_test/models/location.dart';

void main() {
  group('NFC Error Handler Tests', () {
    late LocationRepository repository;
    late NFCErrorHandler errorHandler;
    late ManualLocationSelector manualSelector;
    
    setUp(() {
      repository = InMemoryLocationRepository();
      errorHandler = NFCErrorHandler(repository);
      manualSelector = ManualLocationSelector(repository);
    });
    
    group('NFCErrorHandler', () {
      test('handles NFC not supported platform exception', () {
        final exception = PlatformException(
          code: 'nfc_not_supported',
          message: 'NFC is not supported on this device',
        );
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.hardwareUnavailable));
        expect(error.userMessage, contains('does not support NFC'));
        expect(error.recoverySuggestions, isNotEmpty);
        expect(errorHandler.shouldOfferManualSelection(error), isTrue);
        expect(errorHandler.shouldOfferRetry(error), isFalse);
      });
      
      test('handles NFC disabled platform exception', () {
        final exception = PlatformException(
          code: 'nfc_disabled',
          message: 'NFC is disabled',
        );
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.nfcDisabled));
        expect(error.userMessage, contains('turned off'));
        expect(error.recoverySuggestions.any((s) => s.contains('Settings')), isTrue);
        expect(errorHandler.shouldOfferManualSelection(error), isTrue);
      });
      
      test('handles permission denied platform exception', () {
        final exception = PlatformException(
          code: 'permission_denied',
          message: 'Permission denied',
        );
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.permissionDenied));
        expect(error.userMessage, contains('Permission'));
        expect(error.recoverySuggestions.any((s) => s.contains('Grant NFC permission')), isTrue);
        expect(errorHandler.shouldOfferManualSelection(error), isTrue);
      });
      
      test('handles NFC service tag read errors', () {
        final exception = NFCServiceException('Tag does not contain NDEF data');
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.tagReadError));
        expect(error.userMessage, contains('not compatible'));
        expect(errorHandler.shouldOfferRetry(error), isTrue);
        expect(errorHandler.shouldOfferManualSelection(error), isFalse);
      });
      
      test('handles corrupted tag data errors', () {
        final exception = NFCServiceException('Tag data integrity check failed');
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.tagReadError));
        expect(error.userMessage, contains('corrupted'));
        expect(error.recoverySuggestions, contains('Try scanning the tag again'));
      });
      
      test('handles unknown exceptions', () {
        final exception = Exception('Some unknown error');
        
        final error = errorHandler.handleException(exception);
        
        expect(error.type, equals(NFCErrorType.unknown));
        expect(error.userMessage, contains('unexpected error'));
        expect(error.recoverySuggestions, contains('Try restarting the app'));
      });
      
      test('generates user-friendly error messages', () {
        final error = NFCError(
          type: NFCErrorType.nfcDisabled,
          message: 'NFC disabled',
          userMessage: 'NFC is turned off',
          recoverySuggestions: ['Enable NFC', 'Use manual selection'],
        );
        
        final message = errorHandler.getErrorMessage(error);
        
        expect(message, contains('NFC is turned off'));
        expect(message, contains('What you can try:'));
        expect(message, contains('1. Enable NFC'));
        expect(message, contains('2. Use manual selection'));
      });
    });
    
    group('ManualLocationSelector', () {
      test('gets all available locations', () async {
        final locations = await manualSelector.getAvailableLocations();
        
        expect(locations, isNotEmpty);
        expect(locations.length, greaterThan(5)); // Should have sample data
      });
      
      test('filters locations by type', () async {
        final rooms = await manualSelector.getLocationsByType(LocationType.room);
        final hallways = await manualSelector.getLocationsByType(LocationType.hallway);
        
        expect(rooms, isNotEmpty);
        expect(hallways, isNotEmpty);
        
        // Verify all returned locations have the correct type
        for (final room in rooms) {
          expect(room.type, equals(LocationType.room));
        }
        
        for (final hallway in hallways) {
          expect(hallway.type, equals(LocationType.hallway));
        }
      });
      
      test('searches locations by name', () async {
        final results = await manualSelector.searchLocations('room');
        
        expect(results, isNotEmpty);
        
        // All results should contain 'room' in name, description, or ID
        for (final location in results) {
          final containsRoom = location.name.toLowerCase().contains('room') ||
                              location.description.toLowerCase().contains('room') ||
                              location.id.toLowerCase().contains('room');
          expect(containsRoom, isTrue);
        }
      });
      
      test('returns all locations for empty search query', () async {
        final allLocations = await manualSelector.getAvailableLocations();
        final searchResults = await manualSelector.searchLocations('');
        
        expect(searchResults.length, equals(allLocations.length));
      });
      
      test('groups locations by type', () async {
        final grouped = await manualSelector.getLocationsByTypeGrouped();
        
        expect(grouped, isNotEmpty);
        expect(grouped.keys, contains(LocationType.room));
        expect(grouped.keys, contains(LocationType.hallway));
        
        // Verify grouping is correct
        final rooms = grouped[LocationType.room] ?? [];
        for (final room in rooms) {
          expect(room.type, equals(LocationType.room));
        }
      });
      
      test('validates location selection', () async {
        // Test with valid location
        final isValid = await manualSelector.validateLocationSelection('Main Office');
        expect(isValid, isTrue);
        
        // Test with invalid location
        final isInvalid = await manualSelector.validateLocationSelection('nonexistent');
        expect(isInvalid, isFalse);
      });
    });
    
    group('NFCFallbackService', () {
      late NFCFallbackService fallbackService;
      late MockNFCService mockNFCService;
      
      setUp(() {
        mockNFCService = NFCServiceFactory.createMock(repository) as MockNFCService;
        fallbackService = NFCFallbackService(
          nfcService: mockNFCService,
          locationRepository: repository,
        );
      });
      
      tearDown(() {
        fallbackService.dispose();
      });
      
      test('initializes successfully when NFC is available', () async {
        // Mock NFC service returns available status
        final success = await fallbackService.initializeNFC();
        
        expect(success, isTrue);
        expect(fallbackService.isFallbackMode, isFalse);
      });
      
      test('enables fallback mode when NFC is not supported', () async {
        // This test would require mocking the NFC availability check
        // For now, we'll test the manual fallback mode activation
        
        fallbackService.enableFallbackMode();
        
        expect(fallbackService.isFallbackMode, isTrue);
      });
      
      test('provides manual location selector in fallback mode', () {
        fallbackService.enableFallbackMode();
        
        final selector = fallbackService.manualSelector;
        expect(selector, isNotNull);
        expect(selector, isA<ManualLocationSelector>());
      });
      
      test('can start and stop scanning when not in fallback mode', () async {
        // Ensure not in fallback mode
        expect(fallbackService.isFallbackMode, isFalse);
        
        final startSuccess = await fallbackService.startScanning();
        expect(startSuccess, isTrue);
        expect(mockNFCService.isScanning, isTrue);
        
        await fallbackService.stopScanning();
        expect(mockNFCService.isScanning, isFalse);
      });
      
      test('cannot start scanning in fallback mode', () async {
        fallbackService.enableFallbackMode();
        
        final startSuccess = await fallbackService.startScanning();
        expect(startSuccess, isFalse);
      });
      
      test('emits error events', () async {
        // Start scanning first to set up the error handling
        await fallbackService.startScanning();
        
        final errorStream = fallbackService.errorStream;
        final errorFuture = errorStream.first;
        
        // Simulate an NFC error
        mockNFCService.simulateError(
          const NFCServiceException('Test error')
        );
        
        final error = await errorFuture;
        expect(error, isA<NFCError>());
        expect(error.type, equals(NFCErrorType.tagReadError));
      });
      
      test('emits fallback mode changes', () async {
        final fallbackStream = fallbackService.fallbackModeStream;
        final fallbackFuture = fallbackStream.first;
        
        fallbackService.enableFallbackMode();
        
        final isFallbackMode = await fallbackFuture;
        expect(isFallbackMode, isTrue);
      });
    });
  });
}