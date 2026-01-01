import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/location_repository.dart';
import '../widgets/interactive_map_widget.dart';
import 'destination_selector_screen.dart';
import 'starting_point_selector_screen.dart';
import 'map_screen.dart';
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
    // Clear any existing navigation session when entering manual mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationControllerProvider.notifier).clearSession();
    });
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
    StartingPointSelectorScreen.showAsFullScreen(
      context,
      onStartingPointSelected: (location) {
        setState(() {
          _startLocationId = location.id;
          _isSelectingStart = false;
        });
        ref.read(navigationControllerProvider.notifier).setCurrentLocation(location.id);
        
        // If both start and destination are selected, navigate to map screen
        if (_destinationLocationId != null) {
          _navigateToMapScreen();
        }
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
        ref.read(navigationControllerProvider.notifier).setDestination(location.id);
        
        // If both start and destination are selected, navigate to map screen
        if (_startLocationId != null) {
          _navigateToMapScreen();
        }
      },
      showCurrentLocation: false,
      title: 'Select Destination',
    );
  }

  void _navigateToMapScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
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
            actualTimeTaken: session.actualTimeTaken,
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

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    
    // Get current language and localizations
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations(currentLanguage);
    
    // Responsive sizing
    final containerPadding = isSmallScreen ? 12.0 : 20.0;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final buttonHeight = isSmallScreen ? 48.0 : 56.0;
    final smallButtonHeight = isSmallScreen ? 40.0 : 48.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final arrowIconSize = isSmallScreen ? 20.0 : 24.0;
    final mapMargin = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('manual_mode_title')),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          const LanguageSelector(),
          if (_startLocationId != null || _destinationLocationId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetSelection,
              tooltip: l10n.get('reset_selection'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status and controls area - scrollable on small screens
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selection status
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationCard(
                            title: l10n.get('start'),
                            locationId: _startLocationId,
                            isSelected: _startLocationId != null,
                            isActive: _isSelectingStart,
                            icon: Icons.play_arrow,
                            color: Colors.green,
                            onTap: _showStartLocationSelector,
                            locations: locations,
                            padding: cardPadding,
                            notSelectedText: l10n.get('not_selected'),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 16),
                        Icon(
                          Icons.arrow_forward,
                          color: colorScheme.onSurfaceVariant,
                          size: arrowIconSize,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 16),
                        Expanded(
                          child: _buildLocationCard(
                            title: l10n.get('destination'),
                            locationId: _destinationLocationId,
                            isSelected: _destinationLocationId != null,
                            isActive: !_isSelectingStart && !_isNavigating,
                            icon: Icons.flag,
                            color: Colors.red,
                            onTap: _showDestinationSelector,
                            locations: locations,
                            padding: cardPadding,
                            notSelectedText: l10n.get('not_selected'),
                          ),
                        ),
                      ],
                    ),

                    if (_isSelectingStart) ...[
                      SizedBox(height: isSmallScreen ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.green[700],
                              size: iconSize,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                isSmallScreen 
                                    ? 'Select your starting location' 
                                    : 'First, select your starting location using the button above or by tapping on the map',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!_isNavigating && _destinationLocationId == null) ...[
                      SizedBox(height: isSmallScreen ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.blue[700],
                              size: iconSize,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                isSmallScreen 
                                    ? 'Now select your destination' 
                                    : 'Now select your destination using the button above or by tapping on the map',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_startLocationId != null && _destinationLocationId != null && !_isNavigating) ...[
                      SizedBox(height: isSmallScreen ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.navigation,
                              color: colorScheme.primary,
                              size: iconSize,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                isSmallScreen 
                                    ? 'Both locations selected!' 
                                    : 'Great! Both locations selected. You\'ll be taken to the map screen automatically.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_isNavigating) ...[
                      SizedBox(height: isSmallScreen ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.navigation,
                              color: colorScheme.primary,
                              size: iconSize,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                'Navigation active - Follow the route',
                                style: theme.textTheme.bodySmall?.copyWith(
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
            ),
          ),

          // Map area
          Expanded(
            child: Container(
              margin: EdgeInsets.all(mapMargin),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
            padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
            child: Column(
              children: [
                if (_startLocationId != null && _destinationLocationId != null && !_isNavigating)
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: Icon(Icons.navigation, size: isSmallScreen ? 20 : 24),
                      label: Text(
                        'Start Navigation',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
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
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _simulateArrival,
                      icon: Icon(Icons.flag, size: isSmallScreen ? 20 : 24),
                      label: Text(
                        'Arrived at Destination',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
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
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  SizedBox(
                    width: double.infinity,
                    height: smallButtonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(navigationControllerProvider.notifier).stopNavigation();
                        setState(() {
                          _isNavigating = false;
                        });
                      },
                      icon: Icon(Icons.stop, size: isSmallScreen ? 18 : 20),
                      label: Text(
                        'Stop Navigation',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
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
    double padding = 16.0,
    String notSelectedText = 'Not selected',
  }) {
    final theme = Theme.of(context);
    
    String locationName = notSelectedText;
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
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : isActive
                    ? color.withValues(alpha: 0.5)
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
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
