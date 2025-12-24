import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../models/route.dart';
import '../../repositories/location_repository.dart';
import '../widgets/interactive_map_widget.dart';
import 'destination_selector_screen.dart';
import 'destination_reached_screen.dart';

/// Scan mode screen for NFC-based navigation
class ScanModeScreen extends ConsumerStatefulWidget {
  const ScanModeScreen({super.key});

  @override
  ConsumerState<ScanModeScreen> createState() => _ScanModeScreenState();
}

class _ScanModeScreenState extends ConsumerState<ScanModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isScanning = false;
  bool _hasStartLocation = false;
  bool _isNavigating = false;
  String? _currentInstruction;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    // Start scanning immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialScan();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startInitialScan() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      await nfcService.startScanning();
      
      // Listen for NFC tag scans
      nfcService.tagStream.listen((tagData) {
        if (mounted) {
          _handleTagScanned(tagData.locationId);
        }
      });
    } catch (e) {
      if (mounted) {
        _showError('Failed to start NFC scanning: $e');
      }
    }
  }

  void _handleTagScanned(String locationId) async {
    final navigationController = ref.read(navigationControllerProvider.notifier);
    
    if (!_hasStartLocation) {
      // First scan - set as start location
      await navigationController.setCurrentLocation(locationId);
      setState(() {
        _hasStartLocation = true;
        _isScanning = false;
      });
      
      // Show destination selector
      _showDestinationSelector();
    } else if (_isNavigating) {
      // During navigation - update current location
      await navigationController.setCurrentLocation(locationId);
      _checkNavigationProgress();
    }
  }

  void _showDestinationSelector() {
    DestinationSelectorScreen.showAsFullScreen(
      context,
      onDestinationSelected: (location) {
        _startNavigation(location);
      },
      showCurrentLocation: true,
    );
  }

  void _startNavigation(Location destination) async {
    final navigationController = ref.read(navigationControllerProvider.notifier);
    await navigationController.setDestination(destination.id);
    await navigationController.startNavigation();
    
    setState(() {
      _isNavigating = true;
      _isScanning = true;
    });
    
    _updateNavigationInstruction();
  }

  void _updateNavigationInstruction() {
    final session = ref.read(navigationControllerProvider);
    if (session.currentInstruction != null) {
      setState(() {
        _currentInstruction = _getSimpleInstruction(session.currentInstruction!);
      });
    }
  }

  String _getSimpleInstruction(NavigationInstruction instruction) {
    switch (instruction.type) {
      case InstructionType.start:
        return 'Start your journey';
      case InstructionType.straight:
        return 'Move forward until you reach the checkpoint';
      case InstructionType.turn:
        return 'Take a turn and keep moving forward';
      case InstructionType.destination:
        return 'You have reached your destination!';
      default:
        return 'Continue following the path';
    }
  }

  void _checkNavigationProgress() {
    final session = ref.read(navigationControllerProvider);
    
    if (session.state == NavigationState.arrived) {
      // Navigation completed
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DestinationReachedScreen(
            completedRoute: session.activeRoute!,
            pathTaken: session.activeRoute!.pathLocationIds,
          ),
        ),
      );
    } else {
      // Update instruction for next step
      _updateNavigationInstruction();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
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
        final locations = snapshot.data ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Mode'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          if (_isNavigating)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                ref.read(navigationControllerProvider.notifier).stopNavigation();
                Navigator.of(context).pop();
              },
              tooltip: 'Stop Navigation',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status and instruction area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                if (!_hasStartLocation) ...[
                  // Initial scan prompt
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.nfc,
                        size: 50,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Scan the nearest NFC tag',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will be set as your starting position',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (!_isNavigating) ...[
                  // Waiting for destination selection
                  Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start location set!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your destination to begin navigation',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  // Navigation in progress
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Navigation Active',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            if (_currentInstruction != null)
                              Text(
                                _currentInstruction!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (_isScanning) ...[
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
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Scan the next checkpoint to continue',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Map area (only show when navigating)
          if (_isNavigating && session.activeRoute != null)
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
                    currentLocationId: session.currentLocationId,
                    destinationLocationId: session.destinationLocationId,
                    showLocationLabels: true,
                  ),
                ),
              ),
            ),

          // Action buttons
          if (_hasStartLocation && !_isNavigating)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showDestinationSelector,
                  icon: const Icon(Icons.place),
                  label: const Text(
                    'Choose Destination',
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
            ),
        ],
      ),
    );
      },
    );
  }
}