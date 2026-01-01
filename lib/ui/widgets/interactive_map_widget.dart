import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../models/location.dart';
import '../../models/route.dart' as nav_route;

/// Interactive map widget that displays locations, routes, and navigation information
/// Uses a local image (assets/1.jpg) as the map background with pixel-based coordinates
class InteractiveMapWidget extends ConsumerStatefulWidget {
  /// List of all locations to display on the map
  final List<Location> locations;
  
  /// Current active route, if any
  final nav_route.Route? activeRoute;
  
  /// Current user location ID
  final String? currentLocationId;
  
  /// Destination location ID
  final String? destinationLocationId;
  
  /// Callback when a location is tapped on the map
  final void Function(Location location)? onLocationTapped;
  
  /// Whether to show all location labels
  final bool showLocationLabels;
  
  /// Whether this is scan mode (affects route coloring)
  final bool isScanMode;
  
  /// Whether this is a completed journey view (draws entire path in green)
  final bool isCompletedJourney;
  
  /// This is preserved across reroutes to show the full path taken


  const InteractiveMapWidget({
    super.key,
    required this.locations,
    this.activeRoute,
    this.currentLocationId,
    this.destinationLocationId,
    this.onLocationTapped,
    this.showLocationLabels = true,
    this.isScanMode = false,
    this.isCompletedJourney = false,
  });

  @override
  ConsumerState<InteractiveMapWidget> createState() => InteractiveMapWidgetState();
}

class InteractiveMapWidgetState extends ConsumerState<InteractiveMapWidget>
    with TickerProviderStateMixin {
  
  // Map image dimensions (from assets/1.jpg)
  static const double mapImageWidth = 1615.0;
  static const double mapImageHeight = 1255.0;
  
  // Transform controller for pan and zoom
  late TransformationController _transformationController;
  
  // Animation controllers for smooth transitions
  late AnimationController _positionAnimationController;
  late AnimationController _routeAnimationController;
  late AnimationController _pulsingAnimationController;
  
  // Real-time update flags
  bool _isAnimatingToLocation = false;
  bool _isAnimatingRoute = false;
  
  // Flag to ensure we only set the initial view once
  bool _hasSetInitialView = false;

  // Location coordinates matching the map image (pixel coordinates)
  final Map<String, Offset> _locationCoordinates = {
    // Main Rooms (selectable)
    'Gym': const Offset(378, 296),
    'Cafeteria': const Offset(562, 576),
    'Auditorium': const Offset(532, 1041),
    'Main Office': const Offset(1014, 1107),
    "Nurse's Office": const Offset(1031, 901),
    'Media Center': const Offset(1031, 638),
    '7 Red/7 Gold': const Offset(1264, 462),
    // Building Entrances
    'Main Entrance': const Offset(968, 1162),
    'Auditorium Entrance': const Offset(659, 1164),
    'Bus Entrance': const Offset(364, 510),
    // Corridor Checkpoints
    'CP1': const Offset(372, 458),
    'CP2': const Offset(658, 461),
    'CP3': const Offset(969, 464),
    'CPA': const Offset(816, 465),
    'CP9': const Offset(658, 576),
    'CP10': const Offset(970, 651),
    'CPB': const Offset(813, 849),
    'CP4': const Offset(658, 850),
    'CP6': const Offset(967, 909),
    'CP7': const Offset(658, 1012),
    'CP5': const Offset(968, 1115),
    'CP11': const Offset(967, 847),
  };

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    
    // Initialize animation controllers for smooth transitions
    _positionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulsingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Start the pulsing animation for current location marker
    _startPulsingAnimation();
  }

  /// Start the pulsing animation loop for current location marker
  void _startPulsingAnimation() {
    _pulsingAnimationController.repeat();
  }

  @override
  void didUpdateWidget(InteractiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle real-time current location updates
    if (widget.currentLocationId != oldWidget.currentLocationId) {
      _handleCurrentLocationChange(oldWidget.currentLocationId, widget.currentLocationId);
    }
    
    // Handle real-time route updates
    if (widget.activeRoute != oldWidget.activeRoute) {
      _handleActiveRouteChange(oldWidget.activeRoute, widget.activeRoute);
    }
    
  }

  /// Handle real-time current location changes with smooth animations
  void _handleCurrentLocationChange(String? oldLocationId, String? newLocationId) {
    if (newLocationId == null) return;
    
    // Prevent multiple simultaneous animations
    if (_isAnimatingToLocation) return;
    
    _isAnimatingToLocation = true;
    
    // Animate to new current location with smooth transition
    _animateToCurrentLocation().then((_) {
      _isAnimatingToLocation = false;
    });
  }

  /// Handle real-time active route changes
  void _handleActiveRouteChange(nav_route.Route? oldRoute, nav_route.Route? newRoute) {
    if (newRoute == null) {
      // Route was cleared - maintain current view
      return;
    }
    
    // Prevent multiple simultaneous route animations
    if (_isAnimatingRoute) return;
    
    _isAnimatingRoute = true;
    
    // Animate route display with smooth transition
    _animateRouteDisplay(oldRoute, newRoute).then((_) {
      _isAnimatingRoute = false;
    });
  }

  /// Animate smoothly to current location
  Future<void> _animateToCurrentLocation() async {
    if (widget.currentLocationId == null) return;
    
    final locationCoord = _locationCoordinates[widget.currentLocationId];
    if (locationCoord == null) return;
    
    // Calculate the transformation to center on the location
    await _animateToPosition(locationCoord, 2.0); // 2.0x zoom
  }

  /// Animate route display changes
  Future<void> _animateRouteDisplay(nav_route.Route? oldRoute, nav_route.Route? newRoute) async {
    if (newRoute == null) return;
    
    // If this is a completely new route, fit it in view
    final isNewRoute = oldRoute == null || 
                      oldRoute.startLocationId != newRoute.startLocationId ||
                      oldRoute.endLocationId != newRoute.endLocationId;
    
    if (isNewRoute) {
      await _animateFitRouteInView(newRoute);
    } else {
      // Just update the display for route progress
      if (mounted) {
        setState(() {
          // Trigger rebuild to show updated route state
        });
      }
    }
  }

  /// Animate fitting route in view
  Future<void> _animateFitRouteInView(nav_route.Route route) async {
    final routePoints = _getRoutePoints(route);
    if (routePoints.isEmpty) return;
    
    // Calculate bounds for all route points
    double minX = routePoints.first.dx;
    double maxX = routePoints.first.dx;
    double minY = routePoints.first.dy;
    double maxY = routePoints.first.dy;
    
    for (final point in routePoints) {
      minX = min(minX, point.dx);
      maxX = max(maxX, point.dx);
      minY = min(minY, point.dy);
      maxY = max(maxY, point.dy);
    }
    
    // Add padding to bounds
    const padding = 100.0;
    final boundsWidth = maxX - minX + 2 * padding;
    final boundsHeight = maxY - minY + 2 * padding;
    final boundsCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    
    // Calculate appropriate zoom level to fit the route
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final scaleX = screenSize.width / boundsWidth;
    final scaleY = screenSize.height / boundsHeight;
    final scale = min(scaleX, scaleY) * 0.8; // 0.8 for some margin
    
    await _animateToPosition(boundsCenter, scale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the scale required to fit the entire map on screen
        final double scaleX = constraints.maxWidth / mapImageWidth;
        final double scaleY = constraints.maxHeight / mapImageHeight;
        final double fitScale = min(scaleX, scaleY);

        // Initialize the view to fit the map if not already done
        if (!_hasSetInitialView) {
          _hasSetInitialView = true;
          
          // Calculate centering offsets
          final double offsetX = (constraints.maxWidth - mapImageWidth * fitScale) / 2;
          final double offsetY = (constraints.maxHeight - mapImageHeight * fitScale) / 2;

          _transformationController.value = Matrix4.identity()
            ..setTranslationRaw(offsetX, offsetY, 0.0)
            // ignore: deprecated_member_use
            ..scale(fitScale, fitScale, 1.0);
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: InteractiveViewer(
            transformationController: _transformationController,
            // Allow zooming out enough to see the whole map (fitScale)
            // We use a slightly lower value (0.1) to be safe on very small screens
            minScale: 0.1,
            maxScale: 4.0,
            // Allow panning beyond the map edges for better usability
            boundaryMargin: const EdgeInsets.all(double.infinity),
            constrained: false,
            child: SizedBox(
              width: mapImageWidth,
              height: mapImageHeight,
              child: Stack(
                children: [
                  // Base map image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/1.jpg',
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text(
                              'Map image not found',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Route path layer (if active route exists)
                  if (widget.activeRoute != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RoutePathPainter(
                          route: widget.activeRoute!,
                          locationCoordinates: _locationCoordinates,
                          allLocations: widget.locations,
                          currentLocationId: widget.currentLocationId,
                          primaryColor: Theme.of(context).colorScheme.primary,
                          isScanMode: widget.isScanMode,
                          isCompletedJourney: widget.isCompletedJourney,
                        ),
                      ),
                    ),
                  
                  // Location markers
                  ...widget.locations.map((location) => _buildLocationMarker(location)),
                  
                  // Location labels (if enabled)
                  if (widget.showLocationLabels)
                    ...widget.locations.map((location) => _buildLocationLabel(location)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build a marker for a specific location
  Widget _buildLocationMarker(Location location) {
    // First try to get coordinates from the hardcoded map for pixel-perfect positioning
    Offset? coordinate = _locationCoordinates[location.id];
    
    // If not found in hardcoded map, convert from location coordinates
    coordinate ??= _convertLocationCoordinatesToPixels(location.coordinates);
    
    final isCurrentLocation = location.id == widget.currentLocationId;
    final isDestination = location.id == widget.destinationLocationId;
    final isOnRoute = widget.activeRoute?.containsLocation(location.id) ?? false;
    
    Widget markerChild = _buildMarkerIcon(location, isCurrentLocation, isDestination, isOnRoute);
    
    if (isCurrentLocation) {
      markerChild = _buildPulsingCurrentLocationMarker(markerChild);
    }
    
    // Increase touch target size for better mobile usability
    // The map is often scaled down significantly on mobile screens
    const double touchTargetSize = 80.0;
    const double visibleSize = 40.0;

    return Positioned(
      left: coordinate.dx - (touchTargetSize / 2),
      top: coordinate.dy - (touchTargetSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onLocationTapped?.call(location),
        child: SizedBox(
          width: touchTargetSize,
          height: touchTargetSize,
          child: Center(
            child: SizedBox(
              width: visibleSize,
              height: visibleSize,
              child: markerChild,
            ),
          ),
        ),
      ),
    );
  }

  /// Build pulsing animation for current location marker
  Widget _buildPulsingCurrentLocationMarker(Widget child) {
    return AnimatedBuilder(
      animation: _pulsingAnimationController,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring effect
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.3 * (1 - _pulsingAnimationController.value)),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.5 * (1 - _pulsingAnimationController.value)),
                  width: 2,
                ),
              ),
            ),
            // Main marker
            child,
          ],
        );
      },
    );
  }

  /// Convert location coordinates to pixel coordinates
  Offset _convertLocationCoordinatesToPixels(Coordinates coordinates) {
    // Convert lat/lng coordinates back to pixel coordinates
    // This reverses the conversion done in the location repository
    const double baseLatitude = 40.7128;
    const double baseLongitude = -74.0060;
    const double latScale = 0.0001;
    const double lngScale = 0.0001;
    
    final double y = ((coordinates.latitude - baseLatitude) / latScale) * 1255.0;
    final double x = ((coordinates.longitude - baseLongitude) / lngScale) * 1615.0;
    
    return Offset(x, y);
  }

  /// Build a label for a specific location
  Widget _buildLocationLabel(Location location) {
    // First try to get coordinates from the hardcoded map for pixel-perfect positioning
    Offset? coordinate = _locationCoordinates[location.id];
    
    // If not found in hardcoded map, convert from location coordinates
    coordinate ??= _convertLocationCoordinatesToPixels(location.coordinates);
    
    // Check if this is a checkpoint
    final isCheckpoint = location.id.startsWith('CP');
    
    // For checkpoints, show a label with the full checkpoint name
    if (isCheckpoint) {
      return Positioned(
        left: coordinate.dx - 50, // Center the wider label
        top: coordinate.dy + 20, // Position below the marker
        child: SizedBox(
          width: 100,
          height: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade700),
              ),
              child: Text(
                location.name, // Shows "Checkpoint 1", "Checkpoint 2", etc.
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }
    
    // For regular locations, show the full name label
    return Positioned(
      left: coordinate.dx - 60, // Center the 120px label
      top: coordinate.dy + 25, // Position below the marker
      child: SizedBox(
        width: 120,
        height: 30,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              location.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  /// Build the appropriate icon for a location marker
  Widget _buildMarkerIcon(Location location, bool isCurrentLocation, bool isDestination, bool isOnRoute) {
    Color markerColor;
    IconData markerIcon;
    
    if (isCurrentLocation) {
      markerColor = Colors.blue;
      markerIcon = Icons.my_location;
    } else if (isDestination) {
      markerColor = Colors.red;
      markerIcon = Icons.place;
    } else if (isOnRoute) {
      markerColor = Theme.of(context).colorScheme.primary;
      markerIcon = _getLocationTypeIcon(location.type);
    } else {
      markerColor = Colors.grey;
      markerIcon = _getLocationTypeIcon(location.type);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        markerIcon,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  /// Get the appropriate icon for a location type
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
      case LocationType.checkpoint:
        return Icons.flag_circle;
    }
  }

  /// Get route points as Offset coordinates
  List<Offset> _getRoutePoints(nav_route.Route route) {
    final points = <Offset>[];
    
    for (final locationId in route.pathLocationIds) {
      // First try hardcoded coordinates
      Offset? coordinate = _locationCoordinates[locationId];
      
      // If not found, try to find the location and convert its coordinates
      if (coordinate == null) {
        try {
          final location = widget.locations.firstWhere(
            (loc) => loc.id == locationId,
          );
          coordinate = _convertLocationCoordinatesToPixels(location.coordinates);
        } catch (e) {
          // Location not found, coordinate remains null
        }
      }
      
      if (coordinate != null) {
        points.add(coordinate);
      }
    }
    
    return points;
  }

  /// Animate to a specific position and zoom level
  Future<void> _animateToPosition(Offset targetPosition, double targetScale) async {
    if (_isAnimatingToLocation) return;
    
    _isAnimatingToLocation = true;
    
    try {
      _positionAnimationController.reset();
      
      final currentTransform = _transformationController.value;
      final currentScale = currentTransform.getMaxScaleOnAxis();
      final currentTranslation = currentTransform.getTranslation();
      
      // Calculate target translation to center the position
      final context = this.context;
      final screenSize = MediaQuery.of(context).size;
      final targetTranslationX = screenSize.width / 2 - targetPosition.dx * targetScale;
      final targetTranslationY = screenSize.height / 2 - targetPosition.dy * targetScale;
      
      final scaleAnimation = Tween<double>(
        begin: currentScale,
        end: targetScale,
      ).animate(CurvedAnimation(
        parent: _positionAnimationController,
        curve: Curves.easeInOut,
      ));
      
      final translationXAnimation = Tween<double>(
        begin: currentTranslation.x,
        end: targetTranslationX,
      ).animate(CurvedAnimation(
        parent: _positionAnimationController,
        curve: Curves.easeInOut,
      ));
      
      final translationYAnimation = Tween<double>(
        begin: currentTranslation.y,
        end: targetTranslationY,
      ).animate(CurvedAnimation(
        parent: _positionAnimationController,
        curve: Curves.easeInOut,
      ));
      
      void animationListener() {
        if (mounted) {
          final scale = scaleAnimation.value;
          final translationX = translationXAnimation.value;
          final translationY = translationYAnimation.value;
          
          _transformationController.value = Matrix4.identity()
            ..setTranslationRaw(translationX, translationY, 0.0)
            // ignore: deprecated_member_use
            ..scale(scale, scale, 1.0);
        }
      }
      
      _positionAnimationController.addListener(animationListener);
      await _positionAnimationController.forward();
      _positionAnimationController.removeListener(animationListener);
    } finally {
      _isAnimatingToLocation = false;
    }
  }

  /// Public method to center map on a specific location with animation
  void centerOnLocation(String locationId) {
    // First try hardcoded coordinates
    Offset? coordinate = _locationCoordinates[locationId];
    
    // If not found, try to find the location and convert its coordinates
    if (coordinate == null) {
      try {
        final location = widget.locations.firstWhere(
          (loc) => loc.id == locationId,
        );
        coordinate = _convertLocationCoordinatesToPixels(location.coordinates);
      } catch (e) {
        // Location not found, coordinate remains null
      }
    }
    
    if (coordinate != null) {
      _animateToPosition(coordinate, 2.0);
    }
  }

  /// Public method to fit all locations in view with animation
  void fitAllLocations() {
    if (widget.locations.isEmpty) return;
    
    final coordinates = <Offset>[];
    
    for (final location in widget.locations) {
      // First try hardcoded coordinates
      Offset? coordinate = _locationCoordinates[location.id];
      
      // If not found, convert from location coordinates
      coordinate ??= _convertLocationCoordinatesToPixels(location.coordinates);
      
      coordinates.add(coordinate);
    }
    
    if (coordinates.isEmpty) return;
    
    double minX = coordinates.first.dx;
    double maxX = coordinates.first.dx;
    double minY = coordinates.first.dy;
    double maxY = coordinates.first.dy;
    
    for (final coord in coordinates) {
      minX = min(minX, coord.dx);
      maxX = max(maxX, coord.dx);
      minY = min(minY, coord.dy);
      maxY = max(maxY, coord.dy);
    }
    
    const padding = 100.0;
    final boundsWidth = maxX - minX + 2 * padding;
    final boundsHeight = maxY - minY + 2 * padding;
    final boundsCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final scaleX = screenSize.width / boundsWidth;
    final scaleY = screenSize.height / boundsHeight;
    final scale = min(scaleX, scaleY) * 0.8;
    
    _animateToPosition(boundsCenter, scale);
  }

  /// Force refresh the map display
  void refreshMap() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to reflect any external state changes
      });
    }
  }

  @override
  void dispose() {
    _pulsingAnimationController.dispose();
    _positionAnimationController.dispose();
    _routeAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }
}

/// Custom painter for drawing route paths on the map
class RoutePathPainter extends CustomPainter {
  final nav_route.Route route;
  final Map<String, Offset> locationCoordinates;
  final List<Location> allLocations;
  final String? currentLocationId;
  final Color primaryColor;
  final bool isScanMode;
  final bool isCompletedJourney;
  /// List of location IDs that have been traversed (preserved across reroutes)

  const RoutePathPainter({
    required this.route,
    required this.locationCoordinates,
    required this.allLocations,
    this.currentLocationId,
    required this.primaryColor,
    this.isScanMode = false,
    this.isCompletedJourney = false,
  });

  /// Convert location coordinates to pixel coordinates
  Offset _convertLocationCoordinatesToPixels(Coordinates coordinates) {
    // Convert lat/lng coordinates back to pixel coordinates
    // This reverses the conversion done in the location repository
    const double baseLatitude = 40.7128;
    const double baseLongitude = -74.0060;
    const double latScale = 0.0001;
    const double lngScale = 0.0001;
    
    final double y = ((coordinates.latitude - baseLatitude) / latScale) * 1255.0;
    final double x = ((coordinates.longitude - baseLongitude) / lngScale) * 1615.0;
    
    return Offset(x, y);
  }

  /// Find the index of the next checkpoint after the given index in the route
  int _findNextCheckpointIndex(int startIndex) {
    for (int i = startIndex + 1; i < route.pathLocationIds.length; i++) {
      final locId = route.pathLocationIds[i];
      // A checkpoint is any location with ID starting with "CP" or the final destination
      if (locId.startsWith('CP') || i == route.pathLocationIds.length - 1) {
        return i;
      }
    }
    return route.pathLocationIds.length - 1; // Return last index if no checkpoint found
  }

  /// Get coordinate for a location ID
  Offset? _getCoordinateForLocation(String locationId) {
    // First try hardcoded coordinates
    Offset? coordinate = locationCoordinates[locationId];
    
    // If not found, try to find the location and convert its coordinates
    if (coordinate == null) {
      try {
        final location = allLocations.firstWhere(
          (loc) => loc.id == locationId,
        );
        coordinate = _convertLocationCoordinatesToPixels(location.coordinates);
      } catch (e) {
        // Location not found
      }
    }
    
    return coordinate;
  }

  /// Check if a segment (from -> to) is part of the traversed path

  @override
  void paint(Canvas canvas, Size size) {
    // Paint definitions
    final grayPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    final activePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    final completedPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // FIRST: Draw the traversed path in green (if any)
    // This is drawn first so the active route is drawn on top

    // SECOND: Draw the active route
    final routePoints = <Offset>[];
    
    for (final locationId in route.pathLocationIds) {
      final coordinate = _getCoordinateForLocation(locationId);
      if (coordinate != null) {
        routePoints.add(coordinate);
      }
    }
    
    if (routePoints.length < 2) return;
    
    // Get current location index
    final currentIndex = currentLocationId != null 
        ? route.getLocationIndex(currentLocationId!) 
        : 0;
    
    // For completed journeys, draw entire path in green
    if (isCompletedJourney) {
      for (int i = 0; i < routePoints.length - 1; i++) {
        canvas.drawLine(routePoints[i], routePoints[i + 1], completedPaint);
      }
    }
    
    // Only use progressive highlighting in scan mode
    // In manual mode, draw the entire path in the primary color with green for completed
    else if (isScanMode) {
      // Find the next checkpoint index after current location
      final nextCheckpointIndex = currentIndex >= 0 
          ? _findNextCheckpointIndex(currentIndex) 
          : _findNextCheckpointIndex(-1);
      
      // Draw each segment with appropriate color:
      // - Green: Completed segments (before current position)
      // - Primary (colored): Current segment (current to next checkpoint)
      // - Gray: Future segments (after next checkpoint)
      for (int i = 0; i < routePoints.length - 1; i++) {
        Paint paintToUse;
        
        if (currentIndex >= 0 && i < currentIndex) {
          // Completed segment (before current position) - draw in green
          paintToUse = completedPaint;
        } else if (i >= currentIndex && i < nextCheckpointIndex) {
          // Active segment (current position to next checkpoint)
          paintToUse = activePaint;
        } else {
          // Future segment (after next checkpoint) - draw in gray
          paintToUse = grayPaint;
        }
        
        canvas.drawLine(routePoints[i], routePoints[i + 1], paintToUse);
      }
    } else {
      // Manual mode: Draw entire path in primary color, completed in green
      for (int i = 0; i < routePoints.length - 1; i++) {
        Paint paintToUse;
        
        if (currentIndex >= 0 && i < currentIndex) {
          // Completed segment (before current position)
          paintToUse = completedPaint;
        } else {
          // Remaining path in primary color
          paintToUse = activePaint;
        }
        
        canvas.drawLine(routePoints[i], routePoints[i + 1], paintToUse);
      }
    }
    
    // Draw waypoint markers for non-checkpoint locations
    final waypointPaint = Paint()
      ..color = Colors.amber[300]!
      ..style = PaintingStyle.fill;
    
    for (final locationId in route.pathLocationIds) {
      if (!locationId.startsWith('CP')) {
        // First try hardcoded coordinates
        Offset? coord = locationCoordinates[locationId];
        
        // If not found, try to find the location and convert its coordinates
        if (coord == null) {
          try {
            final location = allLocations.firstWhere(
              (loc) => loc.id == locationId,
            );
            coord = _convertLocationCoordinatesToPixels(location.coordinates);
            canvas.drawCircle(coord, 9.0, waypointPaint);
          } catch (e) {
            // Location not found, skip this waypoint
          }
        } else {
          canvas.drawCircle(coord, 9.0, waypointPaint);
        }
      }
    }
    
    // Draw start and end markers
    if (routePoints.isNotEmpty && routePoints.first.dx >= 20 && routePoints.first.dy >= 20 &&
        routePoints.last.dx >= 20 && routePoints.last.dy >= 20) {
      final startPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      
      final endPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      
      canvas.drawCircle(routePoints.first, 12.0, startPaint);
      canvas.drawCircle(routePoints.last, 12.0, endPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoutePathPainter oldDelegate) {
    return route.id != oldDelegate.route.id ||
           route.pathLocationIds.length != oldDelegate.route.pathLocationIds.length ||
           currentLocationId != oldDelegate.currentLocationId ||
           primaryColor != oldDelegate.primaryColor ||
           isScanMode != oldDelegate.isScanMode ||
           isCompletedJourney != oldDelegate.isCompletedJourney;
}
}
