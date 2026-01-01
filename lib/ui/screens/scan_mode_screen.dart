import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../models/route.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
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
  String? _nextCheckpoint;

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
      // During navigation in scan mode, just update current location
      // The navigation controller will automatically handle path merging
      await navigationController.setCurrentLocation(locationId);
      
      // Check if we've arrived at the destination and update UI
      _checkNavigationProgress();
      _updateNavigationInstruction();
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
        _nextCheckpoint = _findNextCheckpoint(session);
      });
    }
  }

  /// Find the next checkpoint to scan in the route
  String? _findNextCheckpoint(NavigationSession session) {
    if (session.activeRoute == null || session.currentLocationId == null) {
      return null;
    }
    
    final route = session.activeRoute!;
    final currentIndex = route.getLocationIndex(session.currentLocationId!);
    
    if (currentIndex < 0) return null;
    
    // Find the next checkpoint (location starting with "CP") or the destination
    for (int i = currentIndex + 1; i < route.pathLocationIds.length; i++) {
      final locId = route.pathLocationIds[i];
      if (locId.startsWith('CP') || i == route.pathLocationIds.length - 1) {
        return locId;
      }
    }
    
    // If no checkpoint found, return the destination
    return route.endLocationId;
  }

  /// Convert CP ID to readable checkpoint name
  String _getReadableCheckpointName(String? checkpointId) {
    if (checkpointId == null) return '';
    
    // Convert "CP1" to "Checkpoint 1", "CPA" to "Checkpoint A", etc.
    if (checkpointId.startsWith('CP')) {
      final suffix = checkpointId.substring(2);
      return 'Checkpoint $suffix';
    }
    
    // Return as-is for non-checkpoint locations (e.g., "Gym", "Cafeteria")
    return checkpointId;
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
    
    // Check if arrived either by state OR by reaching the destination location
    final hasArrived = session.state == NavigationState.arrived ||
        (session.activeRoute != null && 
         session.currentLocationId == session.activeRoute!.endLocationId);
    
    if (hasArrived && session.activeRoute != null) {
      // Navigation completed - pass the actual traversed path
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DestinationReachedScreen(
            completedRoute: session.activeRoute!,
            pathTaken: session.traversedPath.isNotEmpty ? session.traversedPath : session.activeRoute!.pathLocationIds,
            actualTimeTaken: session.actualTimeTaken,
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    
    // Get current language and localizations
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations(currentLanguage);
    
    // Responsive sizing
    final nfcIconContainerSize = isSmallScreen ? 70.0 : 100.0;
    final nfcIconSize = isSmallScreen ? 35.0 : 50.0;
    final checkIconSize = isSmallScreen ? 45.0 : 60.0;
    final navIconContainerSize = isSmallScreen ? 40.0 : 50.0;
    final navIconSize = isSmallScreen ? 20.0 : 24.0;
    final containerPadding = isSmallScreen ? 12.0 : 20.0;
    final buttonHeight = isSmallScreen ? 48.0 : 56.0;

    return FutureBuilder<List<Location>>(
      future: locationRepository.getAllLocations(),
      builder: (context, snapshot) {
        final locations = snapshot.data ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('scan_mode_title')),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          const LanguageSelector(),
          if (_isNavigating)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                ref.read(navigationControllerProvider.notifier).stopNavigation();
                Navigator.of(context).pop();
              },
              tooltip: l10n.get('stop_navigation'),
            ),
        ],
      ),
      body: _isNavigating && session.activeRoute != null
          ? Column(
              children: [
                // Status and instruction area (scrollable header when navigating)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(containerPadding),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Navigation in progress
                      Row(
                        children: [
                          Container(
                            width: navIconContainerSize,
                            height: navIconContainerSize,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.navigation,
                              color: colorScheme.onPrimary,
                              size: navIconSize,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.get('navigation_active'),
                                  style: (isSmallScreen 
                                      ? theme.textTheme.titleMedium 
                                      : theme.textTheme.titleLarge)?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                if (_currentInstruction != null)
                                  Text(
                                    _currentInstruction!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_isScanning) ...[
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        // Next checkpoint info
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.nfc,
                                    color: Colors.teal[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _nextCheckpoint != null
                                          ? 'Next: ${_getReadableCheckpointName(_nextCheckpoint)}'
                                          : l10n.get('scan_next_checkpoint'),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.teal[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_nextCheckpoint != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Look for the orange ${_nextCheckpoint!.startsWith('CP') ? _nextCheckpoint : ''} marker on the map',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.teal[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Reassuring message about rerouting
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 14,
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Don't worry if you scan a different tag - we'll find a new route for you!",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green[700],
                                    fontStyle: FontStyle.italic,
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

                // Map area (only show when navigating)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
                        currentLocationId: session.currentLocationId,
                        destinationLocationId: session.destinationLocationId,
                        showLocationLabels: true,
                        isScanMode: true,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenSize.height - 
                      MediaQuery.of(context).padding.top - 
                      MediaQuery.of(context).padding.bottom - 
                      kToolbarHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status and instruction area
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                                width: nfcIconContainerSize,
                                height: nfcIconContainerSize,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.nfc,
                                  size: nfcIconSize,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 20),
                            Text(
                              l10n.get('scan_nearest_tag'),
                              style: (isSmallScreen 
                                  ? theme.textTheme.titleLarge 
                                  : theme.textTheme.headlineSmall)?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.get('set_as_starting'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else if (!_isNavigating) ...[
                            // Waiting for destination selection
                            Icon(
                              Icons.check_circle,
                              size: checkIconSize,
                              color: Colors.green,
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            Text(
                              l10n.get('start_location_set'),
                              style: (isSmallScreen 
                                  ? theme.textTheme.titleLarge 
                                  : theme.textTheme.headlineSmall)?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.get('choose_destination_begin'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action buttons
                    if (_hasStartLocation && !_isNavigating)
                      Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: _showDestinationSelector,
                            icon: Icon(Icons.place, size: isSmallScreen ? 20 : 24),
                            label: Text(
                              l10n.get('choose_destination'),
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
                      ),
                  ],
                ),
              ),
            ),
    );
      },
    );
  }
}
