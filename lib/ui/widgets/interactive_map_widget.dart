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

  const InteractiveMapWidget({
    super.key,
    required this.locations,
    this.activeRoute,
    this.currentLocationId,
    this.destinationLocationId,
    this.onLocationTapped,
    this.showLocationLabels = true,
    this.isScanMode = false,
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
  
  // Track previous state for smooth transitions
  String? _previousCurrentLocationId;
  nav_route.Route? _previousActiveRoute;
  
  // Real-time update flags
  bool _isAnimatingToLocation = false;
  bool _isAnimatingRoute = false;
  
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
    
    // Store initial state
    _previousCurrentLocationId = widget.currentLocationId;
    _previousActiveRoute = widget.activeRoute;
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
    
    // Update previous state tracking
    _previousCurrentLocationId = widget.currentLocationId;
    _previousActiveRoute = widget.activeRoute;
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
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
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
                          currentLocationId: widget.currentLocationId,
                          primaryColor: Theme.of(context).colorScheme.primary,
                          isScanMode: widget.isScanMode,
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
    final coordinate = _locationCoordinates[location.id];
    if (coordinate == null) return const SizedBox.shrink();
    
    final isCurrentLocation = location.id == widget.currentLocationId;
    final isDestination = location.id == widget.destinationLocationId;
    final isOnRoute = widget.activeRoute?.containsLocation(location.id) ?? false;
    
    Widget markerChild = _buildMarkerIcon(location, isCurrentLocation, isDestination, isOnRoute);
    
    if (isCurrentLocation) {
      markerChild = _buildPulsingCurrentLocationMarker(markerChild);
    }
    
    return Positioned(
      left: coordinate.dx - 20, // Center the 40px marker
      top: coordinate.dy - 20,
      child: GestureDetector(
        onTap: () => widget.onLocationTapped?.call(location),
        child: SizedBox(
          width: 40,
          height: 40,
          child: markerChild,
        ),
      ),
    );
  }

  /// Build pulsing animation for current location marker
  Widget _buildPulsingCurrentLocationMarker(Widget child) {
    return AnimatedBuilder(
      animation: _positionAnimationController,
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
                color: Colors.blue.withOpacity(0.3 * (1 - _positionAnimationController.value)),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.5 * (1 - _positionAnimationController.value)),
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

  /// Build a label for a specific location
  Widget _buildLocationLabel(Location location) {
    final coordinate = _locationCoordinates[location.id];
    if (coordinate == null) return const SizedBox.shrink();
    
    // Don't show labels for checkpoints
    if (location.id.startsWith('CP')) return const SizedBox.shrink();
    
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
              color: Colors.white.withOpacity(0.9),
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
            color: Colors.black.withOpacity(0.3),
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
    }
  }

  /// Get route points as Offset coordinates
  List<Offset> _getRoutePoints(nav_route.Route route) {
    final points = <Offset>[];
    
    for (final locationId in route.pathLocationIds) {
      final coordinate = _locationCoordinates[locationId];
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
            ..translate(translationX, translationY)
            ..scale(scale);
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
    final coordinate = _locationCoordinates[locationId];
    if (coordinate != null) {
      _animateToPosition(coordinate, 2.0);
    }
  }

  /// Public method to fit all locations in view with animation
  void fitAllLocations() {
    if (widget.locations.isEmpty) return;
    
    final coordinates = widget.locations
        .map((loc) => _locationCoordinates[loc.id])
        .where((coord) => coord != null)
        .cast<Offset>()
        .toList();
    
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
  final String? currentLocationId;
  final Color primaryColor;
  final bool isScanMode;

  const RoutePathPainter({
    required this.route,
    required this.locationCoordinates,
    this.currentLocationId,
    required this.primaryColor,
    this.isScanMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final routePoints = <Offset>[];
    
    for (final locationId in route.pathLocationIds) {
      final coordinate = locationCoordinates[locationId];
      if (coordinate != null) {
        routePoints.add(coordinate);
      }
    }
    
    if (routePoints.length < 2) return;
    
    // Draw checkpoints subtly
    final checkpointPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    for (final locationId in route.pathLocationIds) {
      if (locationId.startsWith('CP')) {
        final coord = locationCoordinates[locationId];
        if (coord != null) {
          canvas.drawCircle(coord, 4.0, checkpointPaint);
        }
      }
    }
    
    // Draw main route line
    final pathPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < routePoints.length - 1; i++) {
      canvas.drawLine(routePoints[i], routePoints[i + 1], pathPaint);
    }
    
    // Draw progress indicator if we have current location
    if (currentLocationId != null) {
      final currentIndex = route.getLocationIndex(currentLocationId!);
      if (currentIndex >= 0 && currentIndex < routePoints.length - 1) {
        // Show completed portion in green
        final completedPaint = Paint()
          ..color = Colors.green
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        
        for (int i = 0; i < currentIndex; i++) {
          if (i + 1 < routePoints.length) {
            canvas.drawLine(routePoints[i], routePoints[i + 1], completedPaint);
          }
        }
      }
    }
    
    // Draw waypoint markers for non-checkpoint locations
    final waypointPaint = Paint()
      ..color = Colors.amber[300]!
      ..style = PaintingStyle.fill;
    
    for (final locationId in route.pathLocationIds) {
      if (!locationId.startsWith('CP')) {
        final coord = locationCoordinates[locationId];
        if (coord != null) {
          canvas.drawCircle(coord, 9.0, waypointPaint);
        }
      }
    }
    
    // Draw start and end markers
    if (routePoints.isNotEmpty) {
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}