import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../repositories/location_repository.dart';
import '../widgets/interactive_map_widget.dart';
import '../widgets/navigation_instruction_display.dart';
import 'destination_selector_screen.dart';

/// Main map screen that displays the interactive map with navigation features
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  List<Location> _locations = [];
  bool _isLoading = true;
  final GlobalKey<InteractiveMapWidgetState> _mapKey = GlobalKey<InteractiveMapWidgetState>();

  @override
  void initState() {
    super.initState();
    // Defer loading locations until after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocations();
    });
  }

  Future<void> _loadLocations() async {
    try {
      final locationRepository = ref.read(locationRepositoryProvider);
      final locations = await locationRepository.getAllLocations();
      
      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Only show error if the widget is still mounted and has a scaffold
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showError('Failed to load locations: $e');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationSession = ref.watch(navigationControllerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Navigation'),
        actions: [
          // Destination selector
          IconButton(
            icon: const Icon(Icons.place),
            onPressed: _showDestinationSelector,
            tooltip: 'Select Destination',
          ),
          // Location overview toggle
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _showLocationOverview,
            tooltip: 'Location Overview',
          ),
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              // Zoom in functionality would be handled by the map widget
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              // Zoom out functionality would be handled by the map widget
            },
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on Current Location',
          ),
        ],
      ),
      body: _buildBody(navigationSession),
      floatingActionButton: _buildFloatingActionButton(navigationSession),
    );
  }

  Widget _buildBody(NavigationSession session) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No locations available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadLocations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main map widget
        InteractiveMapWidget(
          key: _mapKey,
          locations: _locations,
          activeRoute: session.activeRoute,
          currentLocationId: session.currentLocationId,
          destinationLocationId: session.destinationLocationId,
          onLocationTapped: _handleLocationTapped,
          showLocationLabels: true,
        ),
        
        // Turn-by-turn navigation instruction display
        if (session.state == NavigationState.navigating && session.currentInstruction != null)
          NavigationInstructionDisplay(
            isOverlay: true,
            showProgress: true,
            onTap: () {
              // Optional: Show detailed navigation info on tap
              _showNavigationDetails(session);
            },
          ),
        
        // Navigation status overlay (for non-navigating states)
        if (session.state != NavigationState.idle && session.state != NavigationState.navigating)
          _buildNavigationStatusOverlay(session),
        
        // Error message overlay
        if (session.errorMessage != null)
          _buildErrorOverlay(session.errorMessage!),
      ],
    );
  }

  Widget _buildNavigationStatusOverlay(NavigationSession session) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildStateIcon(session.state),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStateTitle(session.state),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (session.currentInstruction != null)
                          Text(
                            session.currentInstruction!.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (session.activeRoute != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRouteInfo(
                      Icons.straighten,
                      '${session.activeRoute!.estimatedDistance.toStringAsFixed(0)}m',
                      'Distance',
                    ),
                    _buildRouteInfo(
                      Icons.access_time,
                      '${session.activeRoute!.estimatedTime.inMinutes}min',
                      'Time',
                    ),
                    _buildRouteInfo(
                      Icons.location_on,
                      '${session.currentStepIndex + 1}/${session.activeRoute!.pathLocationIds.length}',
                      'Progress',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateIcon(NavigationState state) {
    IconData icon;
    Color color;
    
    switch (state) {
      case NavigationState.idle:
        icon = Icons.location_searching;
        color = Colors.grey;
        break;
      case NavigationState.selectingDestination:
        icon = Icons.place;
        color = Colors.orange;
        break;
      case NavigationState.calculating:
        icon = Icons.route;
        color = Colors.blue;
        break;
      case NavigationState.navigating:
        icon = Icons.navigation;
        color = Colors.green;
        break;
      case NavigationState.arrived:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NavigationState.error:
        icon = Icons.error;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, color: color, size: 32);
  }

  String _getStateTitle(NavigationState state) {
    switch (state) {
      case NavigationState.idle:
        return 'Ready';
      case NavigationState.selectingDestination:
        return 'Select Destination';
      case NavigationState.calculating:
        return 'Calculating Route...';
      case NavigationState.navigating:
        return 'Navigating';
      case NavigationState.arrived:
        return 'Arrived!';
      case NavigationState.error:
        return 'Error';
    }
  }

  Widget _buildRouteInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay(String errorMessage) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  ref.read(navigationControllerProvider.notifier).clearError();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(NavigationSession session) {
    if (session.state == NavigationState.navigating) {
      return FloatingActionButton.extended(
        onPressed: _stopNavigation,
        icon: const Icon(Icons.stop),
        label: const Text('Stop'),
        backgroundColor: Colors.red,
      );
    }
    
    if (session.activeRoute != null && session.state == NavigationState.idle) {
      return FloatingActionButton.extended(
        onPressed: _startNavigation,
        icon: const Icon(Icons.navigation),
        label: const Text('Start'),
        backgroundColor: Colors.green,
      );
    }
    
    // Show destination selector button when no active navigation
    return FloatingActionButton.extended(
      onPressed: _showDestinationSelector,
      icon: const Icon(Icons.place),
      label: const Text('Select Destination'),
      backgroundColor: Theme.of(context).colorScheme.primary,
    );
  }

  void _handleLocationTapped(Location location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildLocationDetailsSheet(location),
    );
  }

  Widget _buildLocationDetailsSheet(Location location) {
    final navigationSession = ref.watch(navigationControllerProvider);
    final isCurrentLocation = location.id == navigationSession.currentLocationId;
    final isDestination = location.id == navigationSession.destinationLocationId;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getLocationTypeIcon(location.type),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      location.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isCurrentLocation)
            _buildInfoChip('Current Location', Colors.blue)
          else if (isDestination)
            _buildInfoChip('Destination', Colors.red)
          else ...[
            if (!isCurrentLocation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _setDestination(location.id);
                  },
                  icon: const Icon(Icons.place),
                  label: const Text('Set as Destination'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _setCurrentLocation(location.id);
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Set as Current Location'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getLocationTypeIcon(LocationType type) {
    switch (type) {
      case LocationType.room:
        return Icons.room;
      case LocationType.hallway:
        return Icons.linear_scale;
      case LocationType.entrance:
        return Icons.door_front_door;
      case LocationType.elevator:
        return Icons.elevator;
      case LocationType.stairs:
        return Icons.stairs;
      case LocationType.restroom:
        return Icons.wc;
      case LocationType.office:
        return Icons.business;
    }
  }

  void _centerOnCurrentLocation() {
    final session = ref.read(navigationControllerProvider);
    if (session.currentLocationId == null) {
      _showError('No current location set');
      return;
    }
    // The map widget will auto-center when current location changes
  }

  void _setDestination(String locationId) async {
    await ref.read(navigationControllerProvider.notifier).setDestination(locationId);
  }

  void _setCurrentLocation(String locationId) async {
    await ref.read(navigationControllerProvider.notifier).setCurrentLocation(locationId);
  }

  void _startNavigation() async {
    await ref.read(navigationControllerProvider.notifier).startNavigation();
  }

  void _stopNavigation() async {
    await ref.read(navigationControllerProvider.notifier).stopNavigation();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show location overview with all available locations
  void _showLocationOverview() {
    if (_locations.isEmpty) {
      _showError('No locations available');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLocationOverviewSheet(),
    );
  }

  /// Build the location overview bottom sheet
  Widget _buildLocationOverviewSheet() {
    final navigationSession = ref.watch(navigationControllerProvider);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.map, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Location Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _fitAllLocationsInView();
                      },
                      icon: const Icon(Icons.fit_screen),
                      label: const Text('Fit All'),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Location list
              Expanded(
                child: _buildLocationList(navigationSession, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build the scrollable location list
  Widget _buildLocationList(NavigationSession session, ScrollController scrollController) {
    // Group locations by type for better organization
    final locationsByType = <LocationType, List<Location>>{};
    for (final location in _locations) {
      locationsByType.putIfAbsent(location.type, () => []).add(location);
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Search/filter section
        _buildLocationSearch(),
        const SizedBox(height: 16),
        
        // Locations grouped by type
        ...locationsByType.entries.map((entry) => 
          _buildLocationTypeSection(entry.key, entry.value, session)
        ),
      ],
    );
  }

  /// Build search/filter section for locations
  Widget _buildLocationSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap any location to set as destination',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a section for a specific location type
  Widget _buildLocationTypeSection(LocationType type, List<Location> locations, NavigationSession session) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _getLocationTypeIcon(type),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _getLocationTypeName(type),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${locations.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Location items
        ...locations.map((location) => _buildLocationOverviewItem(location, session)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  /// Build individual location item in overview
  Widget _buildLocationOverviewItem(Location location, NavigationSession session) {
    final isCurrentLocation = location.id == session.currentLocationId;
    final isDestination = location.id == session.destinationLocationId;
    final isOnRoute = session.activeRoute?.containsLocation(location.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleLocationOverviewTap(location),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getLocationItemBackgroundColor(isCurrentLocation, isDestination, isOnRoute),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getLocationItemBorderColor(isCurrentLocation, isDestination, isOnRoute),
                width: isCurrentLocation || isDestination ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Location icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getLocationItemIconColor(isCurrentLocation, isDestination, isOnRoute).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getLocationTypeIcon(location.type),
                    size: 20,
                    color: _getLocationItemIconColor(isCurrentLocation, isDestination, isOnRoute),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Location details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCurrentLocation)
                            _buildLocationBadge('Current', Colors.blue)
                          else if (isDestination)
                            _buildLocationBadge('Destination', Colors.red)
                          else if (isOnRoute)
                            _buildLocationBadge('On Route', Colors.green),
                        ],
                      ),
                      if (location.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          location.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action button
                if (!isCurrentLocation)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle tap on location in overview
  void _handleLocationOverviewTap(Location location) {
    Navigator.pop(context); // Close the overview sheet
    
    final session = ref.read(navigationControllerProvider);
    
    if (location.id == session.currentLocationId) {
      // Already current location, just center on it
      _centerOnLocation(location.id);
      return;
    }
    
    // Show location details with option to set as destination or current location
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildLocationDetailsSheet(location),
    );
  }

  /// Build location badge for status indicators
  Widget _buildLocationBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// Get background color for location item based on status
  Color _getLocationItemBackgroundColor(bool isCurrentLocation, bool isDestination, bool isOnRoute) {
    if (isCurrentLocation) return Colors.blue.withOpacity(0.05);
    if (isDestination) return Colors.red.withOpacity(0.05);
    if (isOnRoute) return Colors.green.withOpacity(0.05);
    return Colors.grey.withOpacity(0.02);
  }

  /// Get border color for location item based on status
  Color _getLocationItemBorderColor(bool isCurrentLocation, bool isDestination, bool isOnRoute) {
    if (isCurrentLocation) return Colors.blue.withOpacity(0.3);
    if (isDestination) return Colors.red.withOpacity(0.3);
    if (isOnRoute) return Colors.green.withOpacity(0.3);
    return Colors.grey.withOpacity(0.2);
  }

  /// Get icon color for location item based on status
  Color _getLocationItemIconColor(bool isCurrentLocation, bool isDestination, bool isOnRoute) {
    if (isCurrentLocation) return Colors.blue;
    if (isDestination) return Colors.red;
    if (isOnRoute) return Colors.green;
    return Colors.grey.shade600;
  }

  /// Get human-readable name for location type
  String _getLocationTypeName(LocationType type) {
    switch (type) {
      case LocationType.room:
        return 'Rooms';
      case LocationType.hallway:
        return 'Hallways';
      case LocationType.entrance:
        return 'Entrances';
      case LocationType.elevator:
        return 'Elevators';
      case LocationType.stairs:
        return 'Stairs';
      case LocationType.restroom:
        return 'Restrooms';
      case LocationType.office:
        return 'Offices';
    }
  }

  /// Fit all locations in the map view
  void _fitAllLocationsInView() {
    _mapKey.currentState?.fitAllLocations();
  }

  /// Center map on a specific location
  void _centerOnLocation(String locationId) {
    _mapKey.currentState?.centerOnLocation(locationId);
  }

  /// Show the destination selector
  void _showDestinationSelector() {
    DestinationSelectorScreen.showAsBottomSheet(
      context,
      onDestinationSelected: (location) {
        // The destination is automatically set by the widget
        // Show a confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Destination set to ${location.name}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      showCurrentLocation: false,
    );
  }
  
  void _showNavigationDetails(NavigationSession session) {}
}
