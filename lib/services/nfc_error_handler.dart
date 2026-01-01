import 'dart:async';
import 'package:flutter/services.dart';
import '../models/location.dart';
import '../repositories/location_repository.dart';
import 'nfc_service.dart';

/// Enumeration of NFC error types
enum NFCErrorType {
  hardwareUnavailable,
  permissionDenied,
  nfcDisabled,
  scanTimeout,
  tagReadError,
  unknown,
}

/// Represents an NFC error with context and recovery suggestions
class NFCError {
  final NFCErrorType type;
  final String message;
  final String userMessage;
  final List<String> recoverySuggestions;
  final Exception? originalException;

  const NFCError({
    required this.type,
    required this.message,
    required this.userMessage,
    required this.recoverySuggestions,
    this.originalException,
  });

  @override
  String toString() => 'NFCError($type): $message';
}

/// Service for handling NFC errors and providing fallback options
class NFCErrorHandler {
  // ignore: avoid_unused_constructor_parameters
  NFCErrorHandler(LocationRepository locationRepository);

  /// Convert various exceptions to structured NFC errors
  NFCError handleException(Exception exception) {
    if (exception is PlatformException) {
      return _handlePlatformException(exception);
    } else if (exception is NFCServiceException) {
      return _handleNFCServiceException(exception);
    } else {
      return NFCError(
        type: NFCErrorType.unknown,
        message: 'Unknown error: ${exception.toString()}',
        userMessage: 'An unexpected error occurred while using NFC',
        recoverySuggestions: [
          'Try restarting the app',
          'Check if your device supports NFC',
          'Use manual location selection instead',
        ],
        originalException: exception,
      );
    }
  }

  /// Handle platform-specific exceptions
  NFCError _handlePlatformException(PlatformException exception) {
    switch (exception.code) {
      case 'nfc_not_supported':
        return NFCError(
          type: NFCErrorType.hardwareUnavailable,
          message: 'NFC is not supported on this device',
          userMessage: 'Your device does not support NFC functionality',
          recoverySuggestions: [
            'Use manual location selection',
            'Check device specifications for NFC support',
          ],
          originalException: exception,
        );
      
      case 'nfc_disabled':
        return NFCError(
          type: NFCErrorType.nfcDisabled,
          message: 'NFC is disabled on this device',
          userMessage: 'NFC is turned off on your device',
          recoverySuggestions: [
            'Go to Settings > Connected devices > NFC and turn it on',
            'Enable NFC in your device settings',
            'Use manual location selection as an alternative',
          ],
          originalException: exception,
        );
      
      case 'permission_denied':
        return NFCError(
          type: NFCErrorType.permissionDenied,
          message: 'NFC permission was denied',
          userMessage: 'Permission to use NFC was denied',
          recoverySuggestions: [
            'Grant NFC permission in app settings',
            'Restart the app and allow NFC access',
            'Use manual location selection instead',
          ],
          originalException: exception,
        );
      
      default:
        return NFCError(
          type: NFCErrorType.unknown,
          message: 'Platform error: ${exception.message}',
          userMessage: 'A system error occurred while accessing NFC',
          recoverySuggestions: [
            'Try again in a moment',
            'Restart the app',
            'Use manual location selection',
          ],
          originalException: exception,
        );
    }
  }

  /// Handle NFC service specific exceptions
  NFCError _handleNFCServiceException(NFCServiceException exception) {
    if (exception.message.contains('Tag does not contain')) {
      return NFCError(
        type: NFCErrorType.tagReadError,
        message: 'Invalid NFC tag format',
        userMessage: 'This NFC tag is not compatible with the navigation system',
        recoverySuggestions: [
          'Try scanning a different NFC tag',
          'Ensure you are scanning a location tag',
          'Contact support if this tag should work',
        ],
        originalException: exception,
      );
    } else if (exception.message.contains('integrity check failed')) {
      return NFCError(
        type: NFCErrorType.tagReadError,
        message: 'Corrupted tag data',
        userMessage: 'The NFC tag data appears to be corrupted',
        recoverySuggestions: [
          'Try scanning the tag again',
          'Clean the NFC tag surface',
          'Report this tag for replacement',
        ],
        originalException: exception,
      );
    } else {
      return NFCError(
        type: NFCErrorType.tagReadError,
        message: exception.message,
        userMessage: 'Failed to read the NFC tag',
        recoverySuggestions: [
          'Hold your device closer to the tag',
          'Try scanning again',
          'Use manual location selection',
        ],
        originalException: exception,
      );
    }
  }

  /// Get user-friendly error message with recovery options
  String getErrorMessage(NFCError error) {
    final buffer = StringBuffer();
    buffer.writeln(error.userMessage);
    
    if (error.recoverySuggestions.isNotEmpty) {
      buffer.writeln('\nWhat you can try:');
      for (int i = 0; i < error.recoverySuggestions.length; i++) {
        buffer.writeln('${i + 1}. ${error.recoverySuggestions[i]}');
      }
    }
    
    return buffer.toString();
  }

  /// Check if manual location selection should be offered
  bool shouldOfferManualSelection(NFCError error) {
    return error.type == NFCErrorType.hardwareUnavailable ||
           error.type == NFCErrorType.permissionDenied ||
           error.type == NFCErrorType.nfcDisabled;
  }

  /// Check if retry is recommended for this error type
  bool shouldOfferRetry(NFCError error) {
    return error.type == NFCErrorType.tagReadError ||
           error.type == NFCErrorType.scanTimeout;
  }
}

/// Service providing fallback location selection when NFC is unavailable
class ManualLocationSelector {
  final LocationRepository _locationRepository;
  
  ManualLocationSelector(this._locationRepository);

  /// Get all available locations for manual selection
  Future<List<Location>> getAvailableLocations() async {
    return await _locationRepository.getAllLocations();
  }

  /// Get locations filtered by type
  Future<List<Location>> getLocationsByType(LocationType type) async {
    final allLocations = await getAvailableLocations();
    return allLocations.where((location) => location.type == type).toList();
  }

  /// Search locations by name or description
  Future<List<Location>> searchLocations(String query) async {
    if (query.isEmpty) {
      return await getAvailableLocations();
    }
    
    final allLocations = await getAvailableLocations();
    final lowerQuery = query.toLowerCase();
    
    return allLocations.where((location) {
      return location.name.toLowerCase().contains(lowerQuery) ||
             location.description.toLowerCase().contains(lowerQuery) ||
             location.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get locations grouped by type for organized display
  Future<Map<LocationType, List<Location>>> getLocationsByTypeGrouped() async {
    final allLocations = await getAvailableLocations();
    final grouped = <LocationType, List<Location>>{};
    
    for (final location in allLocations) {
      grouped.putIfAbsent(location.type, () => []).add(location);
    }
    
    return grouped;
  }

  /// Validate that a manually selected location exists
  Future<bool> validateLocationSelection(String locationId) async {
    return await _locationRepository.locationExists(locationId);
  }
}

/// Comprehensive NFC fallback service that coordinates error handling and alternatives
class NFCFallbackService {
  final NFCService _nfcService;
  final NFCErrorHandler _errorHandler;
  final ManualLocationSelector _manualSelector;
  
  final StreamController<NFCError> _errorController = StreamController<NFCError>.broadcast();
  final StreamController<bool> _fallbackModeController = StreamController<bool>.broadcast();
  
  bool _isFallbackMode = false;
  
  NFCFallbackService({
    required NFCService nfcService,
    required LocationRepository locationRepository,
  }) : _nfcService = nfcService,
       _errorHandler = NFCErrorHandler(locationRepository),
       _manualSelector = ManualLocationSelector(locationRepository) {
    
    // Listen to NFC service errors and handle them
    _nfcService.tagStream.listen(
      (tagData) {
        // Tag data received successfully - no error handling needed
      },
      onError: _handleNFCError,
    );
  }

  /// Stream of NFC errors with recovery suggestions
  Stream<NFCError> get errorStream => _errorController.stream;
  
  /// Stream indicating whether the service is in fallback mode
  Stream<bool> get fallbackModeStream => _fallbackModeController.stream;
  
  /// Whether the service is currently in fallback mode
  bool get isFallbackMode => _isFallbackMode;
  
  /// Get the manual location selector for fallback operations
  ManualLocationSelector get manualSelector => _manualSelector;

  /// Attempt to initialize NFC with graceful fallback
  Future<bool> initializeNFC() async {
    try {
      final availability = await _nfcService.checkNFCAvailability();
      
      switch (availability) {
        case NFCAvailabilityStatus.available:
          final permissions = await _nfcService.requestPermissions();
          if (permissions == NFCPermissionStatus.granted) {
            _setFallbackMode(false);
            return true;
          } else {
            _handlePermissionError(permissions);
            return false;
          }
        
        case NFCAvailabilityStatus.disabled:
          _handleNFCDisabled();
          return false;
        
        case NFCAvailabilityStatus.notSupported:
          _handleNFCNotSupported();
          return false;
        
        case NFCAvailabilityStatus.unknown:
          _handleUnknownNFCStatus();
          return false;
      }
    } catch (e) {
      _handleNFCError(e);
      return false;
    }
  }

  /// Start NFC scanning with error handling
  Future<bool> startScanning() async {
    if (_isFallbackMode) {
      return false; // Cannot scan in fallback mode
    }
    
    try {
      await _nfcService.startScanning();
      return true;
    } catch (e) {
      _handleNFCError(e);
      return false;
    }
  }

  /// Stop NFC scanning
  Future<void> stopScanning() async {
    if (!_isFallbackMode) {
      try {
        await _nfcService.stopScanning();
      } catch (e) {
        _handleNFCError(e);
      }
    }
  }

  /// Enable fallback mode for manual location selection
  void enableFallbackMode() {
    _setFallbackMode(true);
  }

  /// Attempt to exit fallback mode and return to NFC
  Future<bool> exitFallbackMode() async {
    return await initializeNFC();
  }

  /// Handle various NFC errors
  void _handleNFCError(dynamic error) {
    final nfcError = _errorHandler.handleException(
      error is Exception ? error : Exception(error.toString())
    );
    
    _errorController.add(nfcError);
    
    // Automatically enable fallback mode for certain error types
    if (_errorHandler.shouldOfferManualSelection(nfcError)) {
      _setFallbackMode(true);
    }
  }

  /// Handle permission-related errors
  void _handlePermissionError(NFCPermissionStatus status) {
    NFCError error;
    
    switch (status) {
      case NFCPermissionStatus.denied:
        error = NFCError(
          type: NFCErrorType.permissionDenied,
          message: 'NFC permission denied',
          userMessage: 'Permission to use NFC was denied',
          recoverySuggestions: [
            'Grant NFC permission in app settings',
            'Restart the app and allow NFC access',
            'Use manual location selection instead',
          ],
        );
        break;
      
      case NFCPermissionStatus.permanentlyDenied:
        error = NFCError(
          type: NFCErrorType.permissionDenied,
          message: 'NFC permission permanently denied',
          userMessage: 'NFC permission has been permanently denied',
          recoverySuggestions: [
            'Go to app settings and enable NFC permission',
            'Uninstall and reinstall the app',
            'Use manual location selection instead',
          ],
        );
        break;
      
      default:
        error = NFCError(
          type: NFCErrorType.permissionDenied,
          message: 'NFC permission issue',
          userMessage: 'There was an issue with NFC permissions',
          recoverySuggestions: [
            'Check app permissions in device settings',
            'Use manual location selection instead',
          ],
        );
    }
    
    _errorController.add(error);
    _setFallbackMode(true);
  }

  /// Handle NFC disabled error
  void _handleNFCDisabled() {
    final error = NFCError(
      type: NFCErrorType.nfcDisabled,
      message: 'NFC is disabled',
      userMessage: 'NFC is turned off on your device',
      recoverySuggestions: [
        'Go to Settings > Connected devices > NFC and turn it on',
        'Enable NFC in your device settings',
        'Use manual location selection as an alternative',
      ],
    );
    
    _errorController.add(error);
    _setFallbackMode(true);
  }

  /// Handle NFC not supported error
  void _handleNFCNotSupported() {
    final error = NFCError(
      type: NFCErrorType.hardwareUnavailable,
      message: 'NFC not supported',
      userMessage: 'Your device does not support NFC functionality',
      recoverySuggestions: [
        'Use manual location selection',
        'Check device specifications for NFC support',
      ],
    );
    
    _errorController.add(error);
    _setFallbackMode(true);
  }

  /// Handle unknown NFC status
  void _handleUnknownNFCStatus() {
    final error = NFCError(
      type: NFCErrorType.unknown,
      message: 'Unknown NFC status',
      userMessage: 'Unable to determine NFC availability',
      recoverySuggestions: [
        'Try restarting the app',
        'Check if NFC is enabled in device settings',
        'Use manual location selection if issues persist',
      ],
    );
    
    _errorController.add(error);
  }

  /// Set fallback mode state and notify listeners
  void _setFallbackMode(bool enabled) {
    if (_isFallbackMode != enabled) {
      _isFallbackMode = enabled;
      _fallbackModeController.add(enabled);
    }
  }

  /// Dispose of resources
  void dispose() {
    _errorController.close();
    _fallbackModeController.close();
    _nfcService.dispose();
  }
}
