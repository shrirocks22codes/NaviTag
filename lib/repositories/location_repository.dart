import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';

/// Abstract interface for location data operations
abstract class LocationRepository {
  /// Get a location by its ID
  Future<Location?> getLocationById(String id);
  
  /// Get all available locations
  Future<List<Location>> getAllLocations();
  
  /// Get locations connected to a specific location
  Future<List<Location>> getConnectedLocations(String locationId);
  
  /// Check if a location exists
  Future<bool> locationExists(String id);
  
  /// Validate that a location ID corresponds to a known location
  Future<bool> isValidLocation(String locationId);
  
  /// Find location by NFC tag serial number
  Future<Location?> getLocationByNfcSerial(String nfcSerial);
}

/// In-memory implementation of LocationRepository for testing and development
class InMemoryLocationRepository implements LocationRepository {
  final Map<String, Location> _locations = {};
  
  /// Initialize with sample locations
  InMemoryLocationRepository() {
    _initializeSampleData();
  }
  
  /// Initialize with custom locations
  InMemoryLocationRepository.withLocations(List<Location> locations) {
    for (final location in locations) {
      _locations[location.id] = location;
    }
  }
  
  @override
  Future<Location?> getLocationById(String id) async {
    return _locations[id];
  }
  
  @override
  Future<List<Location>> getAllLocations() async {
    return _locations.values.toList();
  }
  
  @override
  Future<List<Location>> getConnectedLocations(String locationId) async {
    final location = _locations[locationId];
    if (location == null) return [];
    
    final connectedLocations = <Location>[];
    for (final connectedId in location.connectedLocationIds) {
      final connectedLocation = _locations[connectedId];
      if (connectedLocation != null) {
        connectedLocations.add(connectedLocation);
      }
    }
    
    return connectedLocations;
  }
  
  @override
  Future<bool> locationExists(String id) async {
    return _locations.containsKey(id);
  }
  
  @override
  Future<bool> isValidLocation(String locationId) async {
    return _locations.containsKey(locationId);
  }

  /// Find location by NFC tag serial number
  @override
  Future<Location?> getLocationByNfcSerial(String nfcSerial) async {
    for (final location in _locations.values) {
      if (location.nfcTagSerial == nfcSerial) {
        return location;
      }
    }
    return null;
  }
  
  /// Add a location to the repository
  void addLocation(Location location) {
    _locations[location.id] = location;
  }
  
  /// Remove a location from the repository
  void removeLocation(String id) {
    _locations.remove(id);
  }
  
  /// Clear all locations
  void clear() {
    _locations.clear();
  }
  
  /// Initialize with sample location data matching the map image
  void _initializeSampleData() {
    // Convert pixel coordinates to approximate lat/lng coordinates
    // Using a simple linear mapping for the indoor map
    const double baseLatitude = 40.7128;
    const double baseLongitude = -74.0060;
    const double latScale = 0.0001; // Scale factor for latitude
    const double lngScale = 0.0001; // Scale factor for longitude
    
    Coordinates pixelToCoordinates(double x, double y) {
      return Coordinates(
        latitude: baseLatitude + (y / 1255.0) * latScale,
        longitude: baseLongitude + (x / 1615.0) * lngScale,
      );
    }
    
    final sampleLocations = [
      // Main Rooms (selectable destinations)
      Location(
        id: 'Gym',
        name: 'Gym',
        description: 'School gymnasium and sports facility',
        coordinates: pixelToCoordinates(378, 296),
        connectedLocationIds: ['CP1'],
        type: LocationType.room,
        nfcTagSerial: '04:A1:0A:01:92:44:03',
      ),
      Location(
        id: 'Cafeteria',
        name: 'Cafeteria',
        description: 'Student dining area',
        coordinates: pixelToCoordinates(562, 576),
        connectedLocationIds: ['CP9'],
        type: LocationType.room,
        nfcTagSerial: '04:A1:B7:01:D0:44:03',
      ),
      Location(
        id: 'Auditorium',
        name: 'Auditorium',
        description: 'Main auditorium for assemblies and events',
        coordinates: pixelToCoordinates(532, 1041),
        connectedLocationIds: ['CP7'],
        type: LocationType.room,
        nfcTagSerial: '04:A1:23:01:03:44:03',
      ),
      Location(
        id: 'Main Office',
        name: 'Main Office',
        description: 'School administrative office',
        coordinates: pixelToCoordinates(1014, 1107),
        connectedLocationIds: ['CP5'],
        type: LocationType.office,
        nfcTagSerial: '04:A1:3B:01:2C:44:03',
      ),
      Location(
        id: "Nurse's Office",
        name: "Nurse's Office",
        description: 'School health office',
        coordinates: pixelToCoordinates(1031, 901),
        connectedLocationIds: ['CP6'],
        type: LocationType.office,
        nfcTagSerial: '04:A1:66:01:AC:44:03',
      ),
      Location(
        id: 'Media Center',
        name: 'Media Center',
        description: 'Library and media resources',
        coordinates: pixelToCoordinates(1031, 638),
        connectedLocationIds: ['CP10'],
        type: LocationType.room,
        nfcTagSerial: '04:A1:28:01:FD:44:03',
      ),
      Location(
        id: '7 Red/7 Gold',
        name: '7 Red/7 Gold',
        description: 'Seventh grade classrooms',
        coordinates: pixelToCoordinates(1264, 462),
        connectedLocationIds: ['CP3'],
        type: LocationType.room,
        nfcTagSerial: '04:A1:70:01:E9:44:03',
      ),
      
      // Building Entrances
      Location(
        id: 'Main Entrance',
        name: 'Main Entrance',
        description: 'Primary school entrance',
        coordinates: pixelToCoordinates(968, 1162),
        connectedLocationIds: ['CP5'],
        type: LocationType.entrance,
        nfcTagSerial: '04:A1:7E:01:E6:44:03',
      ),
      Location(
        id: 'Auditorium Entrance',
        name: 'Auditorium Entrance',
        description: 'Entrance to auditorium area',
        coordinates: pixelToCoordinates(659, 1164),
        connectedLocationIds: ['CP7'],
        type: LocationType.entrance,
        nfcTagSerial: '04:A1:A2:A2:01:C4:44:03',
      ),
      Location(
        id: 'Bus Entrance',
        name: 'Bus Entrance',
        description: 'Entrance near bus loading area',
        coordinates: pixelToCoordinates(364, 510),
        connectedLocationIds: ['CP1'],
        type: LocationType.entrance,
        nfcTagSerial: '04:A1:64:01:F2:44:03',
      ),
      
      // Corridor Checkpoints (navigation waypoints)
      Location(
        id: 'CP1',
        name: 'Checkpoint 1',
        description: 'Navigation checkpoint near gym area',
        coordinates: pixelToCoordinates(372, 458),
        connectedLocationIds: ['Gym', 'CP2', 'Bus Entrance'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:1C:01:00:44:03',
      ),
      Location(
        id: 'CP2',
        name: 'Checkpoint 2',
        description: 'Central corridor junction',
        coordinates: pixelToCoordinates(658, 461),
        connectedLocationIds: ['CP1', 'CP9', 'CP3', 'CP4'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:06:01:3A:44:03',
      ),
      Location(
        id: 'CP3',
        name: 'Checkpoint 3',
        description: 'East corridor checkpoint',
        coordinates: pixelToCoordinates(969, 464),
        connectedLocationIds: ['CP2', 'CPA', 'CP11', '7 Red/7 Gold'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:BA:01:E8:44:03',
      ),
      Location(
        id: 'CPA',
        name: 'Checkpoint A',
        description: 'Auxiliary checkpoint',
        coordinates: pixelToCoordinates(816, 465),
        connectedLocationIds: ['CP3', 'CP2', 'CP11'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:67:01:3B:44:03',
      ),
      Location(
        id: 'CP9',
        name: 'Checkpoint 9',
        description: 'Cafeteria area checkpoint',
        coordinates: pixelToCoordinates(658, 576),
        connectedLocationIds: ['CP2', 'Cafeteria', 'CP4'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:A6:01:DD:44:03',
      ),
      Location(
        id: 'CP10',
        name: 'Checkpoint 10',
        description: 'Media center area checkpoint',
        coordinates: pixelToCoordinates(970, 651),
        connectedLocationIds: ['CP3', 'CP11', 'Media Center'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:5A:01:DA:44:03',
      ),
      Location(
        id: 'CPB',
        name: 'Checkpoint B',
        description: 'Secondary auxiliary checkpoint',
        coordinates: pixelToCoordinates(813, 849),
        connectedLocationIds: ['CP4', 'CP11'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:34:01:5E:44:03',
      ),
      Location(
        id: 'CP4',
        name: 'Checkpoint 4',
        description: 'South corridor checkpoint',
        coordinates: pixelToCoordinates(658, 850),
        connectedLocationIds: ['CP2', 'CP9', 'CPB', 'CP7'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:6E:01:CB:44:03',
      ),
      Location(
        id: 'CP6',
        name: 'Checkpoint 6',
        description: 'Administrative area checkpoint',
        coordinates: pixelToCoordinates(967, 909),
        connectedLocationIds: ['CP11', "Nurse's Office", 'CP5'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:98:01:DF:44:03',
      ),
      Location(
        id: 'CP7',
        name: 'Checkpoint 7',
        description: 'Auditorium area checkpoint',
        coordinates: pixelToCoordinates(658, 1012),
        connectedLocationIds: ['CP4', 'Auditorium', 'Auditorium Entrance'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:50:01:D0:44:03',
      ),
      Location(
        id: 'CP5',
        name: 'Checkpoint 5',
        description: 'Main entrance area checkpoint',
        coordinates: pixelToCoordinates(968, 1115),
        connectedLocationIds: ['CP6', 'Main Office', 'Main Entrance'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:36:01:B4:44:03',
      ),
      Location(
        id: 'CP11',
        name: 'Checkpoint 11',
        description: 'East administrative checkpoint',
        coordinates: pixelToCoordinates(967, 847),
        connectedLocationIds: ['CP3', 'CP10', 'CP6', 'CPB'],
        type: LocationType.hallway,
        nfcTagSerial: '04:A1:15:01:D8:44:03',
      ),
    ];
    
    for (final location in sampleLocations) {
      _locations[location.id] = location;
    }
  }
}

/// Provider for the location repository
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return InMemoryLocationRepository();
});