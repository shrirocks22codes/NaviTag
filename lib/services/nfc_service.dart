import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:ndef_record/ndef_record.dart';
import '../models/nfc_tag_data.dart';
import '../repositories/location_repository.dart';

/// Enumeration of NFC permission states
enum NFCPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  notRequired,
}

/// Enumeration of NFC availability states
enum NFCAvailabilityStatus {
  available,
  disabled,
  notSupported,
  unknown,
}

/// Abstract interface for NFC operations
abstract class NFCService {
  /// Stream of detected NFC tag data
  Stream<NFCTagData> get tagStream;
  
  /// Stream of NFC scanning status updates
  Stream<bool> get scanningStatusStream;
  
  /// Check if NFC is available on the device
  Future<NFCAvailabilityStatus> checkNFCAvailability();
  
  /// Request NFC permissions from the user
  Future<NFCPermissionStatus> requestPermissions();
  
  /// Start scanning for NFC tags
  Future<void> startScanning();
  
  /// Stop scanning for NFC tags
  Future<void> stopScanning();
  
  /// Check if currently scanning
  bool get isScanning;
  
  /// Write NFC tag data to a tag (for administrative purposes)
  Future<bool> writeTag(NFCTagData tagData);
  
  /// Dispose of resources
  void dispose();
}

/// Implementation of NFC service using nfc_manager plugin
class NFCServiceImpl implements NFCService {
  final StreamController<NFCTagData> _tagController = StreamController<NFCTagData>.broadcast();
  final StreamController<bool> _scanningStatusController = StreamController<bool>.broadcast();
  final LocationRepository _locationRepository;
  
  bool _isScanning = false;
  bool _isDisposed = false;
  
  NFCServiceImpl(this._locationRepository);
  
  @override
  Stream<NFCTagData> get tagStream => _tagController.stream;
  
  @override
  Stream<bool> get scanningStatusStream => _scanningStatusController.stream;
  
  @override
  bool get isScanning => _isScanning;
  
  @override
  Future<NFCAvailabilityStatus> checkNFCAvailability() async {
    try {
      // On iOS, NFC availability check may not work correctly
      // iOS requires an active NFC session to detect tags, and the
      // isAvailable() method may return false even on NFC-capable devices
      // (iPhone 7 and later support NFC)
      if (Platform.isIOS) {
        // For iOS, we assume NFC is available on modern iPhones (iPhone 7+)
        // and let the actual scanning attempt determine if it works.
        // This is because iOS NFC requires Core NFC which may not
        // report availability correctly through the nfc_manager plugin.
        // The isAvailable() method often returns false on iOS even when
        // NFC is fully functional, so we bypass the check entirely.
        return NFCAvailabilityStatus.available;
      }
      
      // For Android and other platforms, use the standard check
      // ignore: deprecated_member_use
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return NFCAvailabilityStatus.notSupported;
      }
      
      // Additional check for enabled state (platform-specific)
      return NFCAvailabilityStatus.available;
    } catch (e) {
      if (e is PlatformException) {
        switch (e.code) {
          case 'nfc_not_supported':
          case 'NFCNotSupported':
            return NFCAvailabilityStatus.notSupported;
          case 'nfc_disabled':
          case 'NFCDisabled':
            return NFCAvailabilityStatus.disabled;
          default:
            return NFCAvailabilityStatus.unknown;
        }
      }
      return NFCAvailabilityStatus.unknown;
    }
  }
  
  @override
  Future<NFCPermissionStatus> requestPermissions() async {
    try {
      // NFC Manager handles permissions internally
      // ignore: deprecated_member_use
      final isAvailable = await NfcManager.instance.isAvailable();
      return isAvailable ? NFCPermissionStatus.granted : NFCPermissionStatus.denied;
    } catch (e) {
      if (e is PlatformException) {
        switch (e.code) {
          case 'permission_denied':
            return NFCPermissionStatus.denied;
          case 'permission_permanently_denied':
            return NFCPermissionStatus.permanentlyDenied;
          default:
            return NFCPermissionStatus.denied;
        }
      }
      return NFCPermissionStatus.denied;
    }
  }
  
  @override
  Future<void> startScanning() async {
    if (_isDisposed) {
      throw StateError('NFCService has been disposed');
    }
    
    if (_isScanning) {
      return; // Already scanning
    }
    
    try {
      await NfcManager.instance.startSession(
        onDiscovered: _handleTagDiscovered,
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
      );
      
      _isScanning = true;
      _scanningStatusController.add(true);
    } catch (e) {
      _isScanning = false;
      _scanningStatusController.add(false);
      rethrow;
    }
  }
  
  @override
  Future<void> stopScanning() async {
    if (!_isScanning) {
      return; // Not scanning
    }
    
    try {
      await NfcManager.instance.stopSession();
      _isScanning = false;
      _scanningStatusController.add(false);
    } catch (e) {
      // Even if stopping fails, update our internal state
      _isScanning = false;
      _scanningStatusController.add(false);
      rethrow;
    }
  }
  
  @override
  Future<bool> writeTag(NFCTagData tagData) async {
    if (_isDisposed) {
      throw StateError('NFCService has been disposed');
    }
    
    try {
      final encodedData = tagData.encode();
      
      // Check if data fits in typical NFC tag
      if (!NFCTagUtils.fitsInTag(encodedData)) {
        throw NFCServiceException('Tag data too large for NFC tag');
      }
      
      // For now, return true as a placeholder
      // Real implementation would write to actual NFC tag
      return true;
    } catch (e) {
      if (e is NFCServiceException) {
        rethrow;
      }
      throw NFCServiceException('Failed to write NFC tag: $e');
    }
  }
  
  /// Handle discovered NFC tags
  Future<void> _handleTagDiscovered(NfcTag tag) async {
    try {
      // Extract the location ID from the NDEF Text Record on the tag
      String? locationId;
      
      // Use proper nfc_manager APIs - platform specific classes
      // Android uses NdefAndroid, NfcAAndroid, etc.
      // iOS uses NdefIos
      
      // Try to read NDEF data from the tag
      NdefMessage? cachedMessage;
      
      if (Platform.isAndroid) {
        final ndefAndroid = NdefAndroid.from(tag);
        if (ndefAndroid != null) {
          cachedMessage = ndefAndroid.cachedNdefMessage;
        }
      } else if (Platform.isIOS) {
        final ndefIos = NdefIos.from(tag);
        if (ndefIos != null) {
          cachedMessage = ndefIos.cachedNdefMessage;
        }
      }
      
      if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
        // Process NDEF records to find the location ID
        for (final record in cachedMessage.records) {
          final typeNameFormat = record.typeNameFormat;
          final type = record.type;
          final payload = record.payload;
          
          // Check if this is a Well-Known type (TNF = 1)
          if (typeNameFormat == TypeNameFormat.wellKnown && type.isNotEmpty && payload.isNotEmpty) {
            final typeStr = String.fromCharCodes(type);
            
            if (typeStr == 'T') {
              // This is an NDEF Text Record
              // Text record payload format:
              // Byte 0: Status byte (bit 7 = UTF encoding, bits 5-0 = language code length)
              // Bytes 1-n: Language code (e.g., "en")
              // Remaining bytes: The actual text content
              
              final statusByte = payload[0];
              final languageCodeLength = statusByte & 0x3F;
              
              // Skip status byte and language code to get the text
              if (payload.length > languageCodeLength + 1) {
                locationId = String.fromCharCodes(
                  payload.sublist(languageCodeLength + 1)
                ).trim();
              }
            } else if (typeStr == 'U') {
              // This is an NDEF URI Record
              locationId = String.fromCharCodes(payload.sublist(1)).trim();
            }
          } else if (typeNameFormat == TypeNameFormat.media && payload.isNotEmpty) {
            // Media type - treat as plain text
            locationId = String.fromCharCodes(payload).trim();
          }
          
          // If we found a location ID, stop processing
          if (locationId != null && locationId.isNotEmpty) {
            break;
          }
        }
      }
      
      // If NDEF reading failed, try to get tag identifier as fallback
      if (locationId == null || locationId.isEmpty) {
        // Try to get the tag identifier (UID) from the tag
        String? tagUid;
        
        if (Platform.isAndroid) {
          // On Android, get the tag ID from NfcTagAndroid
          final nfcTag = NfcTagAndroid.from(tag);
          if (nfcTag != null) {
            final identifier = nfcTag.id;
            tagUid = identifier.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
          }
        } else if (Platform.isIOS) {
          // On iOS, try to get identifier from ISO7816 or MiFare tags
          final iso7816 = Iso7816Ios.from(tag);
          if (iso7816 != null) {
            final identifier = iso7816.identifier;
            tagUid = identifier.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
          }
          
          if (tagUid == null) {
            final mifare = MiFareIos.from(tag);
            if (mifare != null) {
              final identifier = mifare.identifier;
              tagUid = identifier.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
            }
          }
        }
        
        if (tagUid != null) {
          // Look up location by NFC serial number as fallback
          final location = await _locationRepository.getLocationByNfcSerial(tagUid);
          if (location != null) {
            locationId = location.id;
          }
        }
      }
      
      if (locationId == null || locationId.isEmpty) {
        _tagController.addError(
          NFCServiceException('Could not read location data from NFC tag')
        );
        return;
      }
      
      // Verify the location exists in our repository
      final isValid = await _locationRepository.isValidLocation(locationId);
      if (!isValid) {
        _tagController.addError(
          NFCServiceException('Unknown location: $locationId')
        );
        return;
      }
      
      // Create tag data from the discovered location
      final nfcTagData = NFCTagData.create(locationId: locationId);
      
      // Validate the tag data
      if (!nfcTagData.isValid()) {
        _tagController.addError(
          NFCServiceException('Tag data integrity check failed')
        );
        return;
      }
      
      // Emit the valid tag data
      _tagController.add(nfcTagData);
      
    } catch (e) {
      if (e is NFCTagDataException) {
        _tagController.addError(
          NFCServiceException('Invalid tag data format: ${e.message}')
        );
      } else {
        _tagController.addError(
          NFCServiceException('Failed to read NFC tag: $e')
        );
      }
    }
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Stop scanning if active
    if (_isScanning) {
      stopScanning().catchError((_) {
        // Ignore errors during disposal
      });
    }
    
    // Close streams
    _tagController.close();
    _scanningStatusController.close();
  }
}

/// Exception thrown by NFC service operations
class NFCServiceException implements Exception {
  final String message;
  
  const NFCServiceException(this.message);
  
  @override
  String toString() => 'NFCServiceException: $message';
}

/// Factory for creating NFC service instances
class NFCServiceFactory {
  /// Create a new NFC service instance
  static NFCService create(LocationRepository locationRepository) {
    return NFCServiceImpl(locationRepository);
  }
  
  /// Create a mock NFC service for testing
  static NFCService createMock(LocationRepository locationRepository) {
    return MockNFCService(locationRepository);
  }
}

/// Mock implementation for testing purposes
class MockNFCService implements NFCService {
  final StreamController<NFCTagData> _tagController = StreamController<NFCTagData>.broadcast();
  final StreamController<bool> _scanningStatusController = StreamController<bool>.broadcast();
  
  bool _isScanning = false;
  bool _isDisposed = false;
  
  // ignore: avoid_unused_constructor_parameters
  MockNFCService(LocationRepository locationRepository);
  
  @override
  Stream<NFCTagData> get tagStream => _tagController.stream;
  
  @override
  Stream<bool> get scanningStatusStream => _scanningStatusController.stream;
  
  @override
  bool get isScanning => _isScanning;
  
  @override
  Future<NFCAvailabilityStatus> checkNFCAvailability() async {
    return NFCAvailabilityStatus.available;
  }
  
  @override
  Future<NFCPermissionStatus> requestPermissions() async {
    return NFCPermissionStatus.granted;
  }
  
  @override
  Future<void> startScanning() async {
    if (_isDisposed) {
      throw StateError('NFCService has been disposed');
    }
    
    _isScanning = true;
    _scanningStatusController.add(true);
  }
  
  @override
  Future<void> stopScanning() async {
    _isScanning = false;
    _scanningStatusController.add(false);
  }
  
  @override
  Future<bool> writeTag(NFCTagData tagData) async {
    if (_isDisposed) {
      throw StateError('NFCService has been disposed');
    }
    
    return true; // Mock always succeeds
  }
  
  /// Simulate discovering a tag (for testing)
  void simulateTagDiscovered(NFCTagData tagData) {
    if (!_isDisposed && _isScanning) {
      _tagController.add(tagData);
    }
  }
  
  /// Simulate a scanning error (for testing)
  void simulateError(NFCServiceException error) {
    if (!_isDisposed && _isScanning) {
      _tagController.addError(error);
    }
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _isScanning = false;
    
    _tagController.close();
    _scanningStatusController.close();
  }
}
