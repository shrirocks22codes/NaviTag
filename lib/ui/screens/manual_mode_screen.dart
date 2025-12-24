import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../repositories/location_repository.dart';
import '../widgets/interactive_map_widget.dart';
import 'destination_selector_screen.dart';
import 'destination_reached_screen.dart';

/// Manual mode screen for map-based navigation
class ManualModeScreen extends ConsumerStatefulWidget {
  const ManualModeScreen({super.key});

  @override
  ConsumerState<ManualModeScreen> createState() => _ManualModeScreenState();
}

class _ManualModeScreenState extends ConsumerState<ManualModeScreen> {
  bool _isSelectingStart = true;
  String? _startLocationId;
  String? _destinationLocationId;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
  }

  void _onLocationTapped(Location location) {
    if (_isSelectingStart) {
      setState(() {
        _startLocationId = location.id;
        _isSelectingStart = false;
      });
      
      // Set current location in navigation controller
      ref.read(navigationControllerProvider.notifier).setCurrentLocation(location.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Start location set to ${location.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (!_isNavigating) {
      setState(() {
        _destinationLocationId = location.id;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Destination set to ${location.name}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _startNavigation() async {
    if (_startLocationId != null && _destinationLocationId != null) {
      final navigationController = ref.read(navigationControllerProvider.notifier);
      
      await navigationController.setDestination(_destinationLocationId!);
      await navigationController.startNavigation();
      
      setState(() {
        _isNavigating = true;
      });
    }
  }

  void _resetSelection() {
    setState(() {
      _startLocationId = null;
      _destinationLocationId = null;
      _isSelectingStart = true;
      _isNavigating = false;
    });
    
    ref.read(navigationControllerProvider.notifier).clearRoute();
  }

  void _showStartLocationSelector() {
    DestinationSelectorScreen.showAsFullScreen(
      context,
      onDestinationSelected: (location) {
        setState(() {
          _startLocationId = location.id;
          _isSelectingStart = false;
        });
        ref.read(navigationControllerProvider.notifier).setCurrentLocation(location.id);
      },
      showCurrentLocation: false,
      title: 'Select Start Location',
    );
  }

  void _showDestinationSelector() {
    DestinationSelectorScreen.showAsFullScreen(
      context,
      onDestinationSelected: (location) {
        setState(() {
          _destinationLocationId = location.id;
        });
      },
      showCurrentLocation: false,
      title: 'Select Destination',
    );
  }

  void _simulateArrival() {
    final session = ref.read(navigationControllerProvider);
    if (session.activeRoute != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DestinationReachedScreen(
            completedRoute: session.activeRoute!,
            pathTaken: session.activeRoute!.pathLocationIds,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = ref.watch(navigationControllerProvider);
    final locationRepository = ref.watch(locationRepositoryProvider);

    return FutureBuilder<List<Location>>(
      future: locationRepository.getAllLocations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading locations: ${snapshot.error}'),
            ),
          );
        }
        
        final locations = snapshot.data ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Mode'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          if (_startLocationId != null || _destinationLocationId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetSelection,
              tooltip: 'Reset Selection',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status and controls area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Selection status
                Row(
                  children: [
                    Expanded(
                      child: _buildLocationCard(
                        title: 'Start',
                        locationId: _startLocationId,
                        isSelected: _startLocationId != null,
                        isActive: _isSelectingStart,
                        icon: Icons.play_arrow,
                        color: Colors.green,
                        onTap: _showStartLocationSelector,
                        locations: locations,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.arrow_forward,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLocationCard(
                        title: 'Destination',
                        locationId: _destinationLocationId,
                        isSelected: _destinationLocationId != null,
                        isActive: !_isSelectingStart && !_isNavigating,
                        icon: Icons.flag,
                        color: Colors.red,
                        onTap: _showDestinationSelector,
                        locations: locations,
                      ),
                    ),
                  ],
                ),

                if (_isSelectingStart) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tap on the map or use the button to select your starting location',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!_isNavigating && _destinationLocationId == null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Now tap on the map or use the button to select your destination',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_isNavigating) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.navigation,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Navigation active - Follow the route shown on the map',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Map area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveMapWidget(
                  locations: locations,
                  activeRoute: session.activeRoute,
                  currentLocationId: _startLocationId,
                  destinationLocationId: _destinationLocationId,
                  onLocationTapped: _onLocationTapped,
                  showLocationLabels: true,
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_startLocationId != null && _destinationLocationId != null && !_isNavigating)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text(
                        'Start Navigation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                
                if (_isNavigating) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _simulateArrival,
                      icon: const Icon(Icons.flag),
                      label: const Text(
                        'Simulate Arrival',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(navigationControllerProvider.notifier).stopNavigation();
                        setState(() {
                          _isNavigating = false;
                        });
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Navigation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String? locationId,
    required bool isSelected,
    required bool isActive,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required List<Location> locations,
  }) {
    final theme = Theme.of(context);
    
    String locationName = 'Not selected';
    if (locationId != null) {
      final location = locations.firstWhere(
        (loc) => loc.id == locationId,
        orElse: () => Location(
          id: locationId,
          name: locationId,
          description: '',
          coordinates: const Coordinates(latitude: 0, longitude: 0),
          connectedLocationIds: [],
          type: LocationType.room,
        ),
      );
      locationName = location.name;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : isActive
                    ? color.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              locationName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}