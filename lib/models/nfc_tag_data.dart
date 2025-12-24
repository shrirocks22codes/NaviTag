import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Represents the data structure stored in NFC tags for location identification
class NFCTagData {
  final String locationId;
  final String checksum;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;

  const NFCTagData({
    required this.locationId,
    required this.checksum,
    required this.timestamp,
    this.additionalData = const {},
  });

  /// Create NFCTagData from JSON
  factory NFCTagData.fromJson(Map<String, dynamic> json) {
    return NFCTagData(
      locationId: json['locationId'] as String,
      checksum: json['checksum'] as String,
      // Ensure consistent precision by only using milliseconds
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      additionalData: Map<String, dynamic>.from(json['additionalData'] as Map? ?? {}),
    );
  }

  /// Convert NFCTagData to JSON
  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'checksum': checksum,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'additionalData': additionalData,
    };
  }

  /// Create NFCTagData with automatic checksum generation
  factory NFCTagData.create({
    required String locationId,
    DateTime? timestamp,
    Map<String, dynamic> additionalData = const {},
  }) {
    // Normalize timestamp to millisecond precision to ensure consistency
    final actualTimestamp = timestamp ?? DateTime.now();
    final normalizedTimestamp = DateTime.fromMillisecondsSinceEpoch(
      actualTimestamp.millisecondsSinceEpoch
    );
    final checksum = _generateChecksum(locationId, normalizedTimestamp, additionalData);
    
    return NFCTagData(
      locationId: locationId,
      checksum: checksum,
      timestamp: normalizedTimestamp,
      additionalData: additionalData,
    );
  }

  /// Validate the integrity of the NFC tag data
  bool isValid() {
    final expectedChecksum = _generateChecksum(locationId, timestamp, additionalData);
    return checksum == expectedChecksum;
  }

  /// Encode the NFC tag data to bytes for writing to NFC tag
  Uint8List encode() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Decode NFC tag data from bytes
  static NFCTagData decode(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NFCTagData.fromJson(json);
    } catch (e) {
      throw NFCTagDataException('Failed to decode NFC tag data: $e');
    }
  }

  /// Validate that the NFC tag data format is correct
  static bool isValidFormat(Uint8List bytes) {
    try {
      decode(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate a checksum for data integrity validation
  static String _generateChecksum(
    String locationId,
    DateTime timestamp,
    Map<String, dynamic> additionalData,
  ) {
    final dataToHash = '$locationId${timestamp.millisecondsSinceEpoch}${jsonEncode(additionalData)}';
    final bytes = utf8.encode(dataToHash);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 characters for brevity
  }

  /// Create a copy of this NFCTagData with updated fields
  NFCTagData copyWith({
    String? locationId,
    String? checksum,
    DateTime? timestamp,
    Map<String, dynamic>? additionalData,
  }) {
    return NFCTagData(
      locationId: locationId ?? this.locationId,
      checksum: checksum ?? this.checksum,
      timestamp: timestamp ?? this.timestamp,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Refresh the checksum based on current data
  NFCTagData refreshChecksum() {
    final newChecksum = _generateChecksum(locationId, timestamp, additionalData);
    return copyWith(checksum: newChecksum);
  }

  /// Check if this tag data is expired based on a given duration
  bool isExpired(Duration maxAge) {
    final now = DateTime.now();
    return now.difference(timestamp) > maxAge;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NFCTagData &&
        other.locationId == locationId &&
        other.checksum == checksum &&
        other.timestamp == timestamp &&
        _mapEquals(other.additionalData, additionalData);
  }

  @override
  int get hashCode {
    return Object.hash(
      locationId,
      checksum,
      timestamp,
      Object.hashAll(additionalData.entries.map((e) => Object.hash(e.key, e.value))),
    );
  }

  @override
  String toString() => 'NFCTagData(locationId: $locationId, timestamp: $timestamp, valid: ${isValid()})';

  /// Helper method to compare maps
  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Exception thrown when NFC tag data operations fail
class NFCTagDataException implements Exception {
  final String message;
  
  const NFCTagDataException(this.message);
  
  @override
  String toString() => 'NFCTagDataException: $message';
}

/// Utility class for NFC tag operations
class NFCTagUtils {
  /// Maximum size for NFC tag data in bytes (typical NDEF limit)
  static const int maxTagSize = 8192;
  
  /// Minimum required fields for valid NFC tag data
  static const List<String> requiredFields = ['locationId', 'checksum', 'timestamp'];
  
  /// Validate that encoded data fits within NFC tag size limits
  static bool fitsInTag(Uint8List data) {
    return data.length <= maxTagSize;
  }
  
  /// Check if JSON contains all required fields
  static bool hasRequiredFields(Map<String, dynamic> json) {
    return requiredFields.every((field) => json.containsKey(field));
  }
  
  /// Estimate the size of NFC tag data before encoding
  static int estimateSize(NFCTagData tagData) {
    final jsonString = jsonEncode(tagData.toJson());
    return utf8.encode(jsonString).length;
  }
  
  /// Create a minimal NFC tag data for testing
  static NFCTagData createMinimal(String locationId) {
    return NFCTagData.create(locationId: locationId);
  }
  
  /// Create NFC tag data with maximum additional data that fits in tag
  static NFCTagData createMaximal(String locationId, Map<String, dynamic> additionalData) {
    var tagData = NFCTagData.create(
      locationId: locationId,
      additionalData: additionalData,
    );
    
    // Check if it fits, if not, reduce additional data
    while (!fitsInTag(tagData.encode()) && additionalData.isNotEmpty) {
      final keys = additionalData.keys.toList();
      additionalData.remove(keys.last);
      tagData = NFCTagData.create(
        locationId: locationId,
        additionalData: Map.from(additionalData),
      );
    }
    
    return tagData;
  }
}