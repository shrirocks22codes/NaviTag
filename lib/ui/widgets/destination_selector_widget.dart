import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/navigation_controller.dart';
import '../../models/location.dart';
import '../../repositories/location_repository.dart';

/// A mobile-optimized destination selection widget with search and filtering capabilities
class DestinationSelectorWidget extends ConsumerStatefulWidget {
  /// Callback when a destination is selected
  final void Function(Location destination)? onDestinationSelected;
  
  /// Whether to show the current location in the list
  final bool showCurrentLocation;
  
  /// Optional filter to limit which locations are shown
  final bool Function(Location location)? locationFilter;

  const DestinationSelectorWidget({
    super.key,
    this.onDestinationSelected,
    this.showCurrentLocation = false,
    this.locationFilter,
  });

  @override
  ConsumerState<DestinationSelectorWidget> createState() => _DestinationSelectorWidgetState();
}

class _DestinationSelectorWidgetState extends ConsumerState<DestinationSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Location> _allLocations = [];
  List<Location> _filteredLocations = [];
  LocationType? _selectedTypeFilter;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locationRepository = ref.read(locationRepositoryProvider);
      final locations = await locationRepository.getAllLocations();
      
      if (mounted) {
        setState(() {
          _allLocations = locations;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredLocations = _allLocations.where((location) {
        // Apply custom filter if provided
        if (widget.locationFilter != null && !widget.locationFilter!(location)) {
          return false;
        }

        // Apply current location filter
        final navigationSession = ref.read(navigationControllerProvider);
        if (!widget.showCurrentLocation && location.id == navigationSession.currentLocationId) {
          return false;
        }

        // Apply type filter
        if (_selectedTypeFilter != null && location.type != _selectedTypeFilter) {
          return false;
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          return location.name.toLowerCase().contains(_searchQuery) ||
                 location.description.toLowerCase().contains(_searchQuery);
        }

        return true;
      }).toList();

      // Sort locations alphabetically
      _filteredLocations.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Icon(
                  Icons.place,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select Destination',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSearchBar(theme, colorScheme),
          ),

          const SizedBox(height: 16),

          // Type filter chips
          _buildTypeFilterChips(theme, colorScheme),

          const SizedBox(height: 8),

          // Location list
          Expanded(
            child: _buildLocationList(theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search locations...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildTypeFilterChips(ThemeData theme, ColorScheme colorScheme) {
    final availableTypes = _allLocations
        .map((location) => location.type)
        .toSet()
        .toList()
      ..sort((a, b) => _getLocationTypeName(a).compareTo(_getLocationTypeName(b)));

    if (availableTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: availableTypes.length + 1, // +1 for "All" chip
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" filter chip
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: _selectedTypeFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _selectedTypeFilter = null;
                  });
                  _applyFilters();
                },
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: _selectedTypeFilter == null
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: _selectedTypeFilter == null
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.3),
                ),
              ),
            );
          }

          final type = availableTypes[index - 1];
          final isSelected = _selectedTypeFilter == type;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLocationTypeIcon(type),
                    size: 16,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(_getLocationTypeName(type)),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = selected ? type : null;
                });
                _applyFilters();
              },
              backgroundColor: colorScheme.surface,
              selectedColor: colorScheme.primaryContainer,
              checkmarkColor: colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationList(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.location_off,
                size: 48,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No locations found for "$_searchQuery"'
                    : 'No locations available',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty || _selectedTypeFilter != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedTypeFilter = null;
                    });
                    _applyFilters();
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _filteredLocations.length,
      itemBuilder: (context, index) {
        final location = _filteredLocations[index];
        return _buildLocationItem(location, theme, colorScheme);
      },
    );
  }

  Widget _buildLocationItem(Location location, ThemeData theme, ColorScheme colorScheme) {
    final navigationSession = ref.watch(navigationControllerProvider);
    final isCurrentLocation = location.id == navigationSession.currentLocationId;
    final isDestination = location.id == navigationSession.destinationLocationId;
    final isOnRoute = navigationSession.activeRoute?.containsLocation(location.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleLocationSelection(location),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getLocationItemBackgroundColor(
                colorScheme,
                isCurrentLocation,
                isDestination,
                isOnRoute,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getLocationItemBorderColor(
                  colorScheme,
                  isCurrentLocation,
                  isDestination,
                  isOnRoute,
                ),
                width: isCurrentLocation || isDestination ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Location icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLocationItemIconColor(
                      colorScheme,
                      isCurrentLocation,
                      isDestination,
                      isOnRoute,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getLocationTypeIcon(location.type),
                    size: 24,
                    color: _getLocationItemIconColor(
                      colorScheme,
                      isCurrentLocation,
                      isDestination,
                      isOnRoute,
                    ),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isCurrentLocation)
                            _buildLocationBadge('Current', colorScheme.primary, colorScheme)
                          else if (isDestination)
                            _buildLocationBadge('Destination', colorScheme.error, colorScheme)
                          else if (isOnRoute)
                            _buildLocationBadge('On Route', colorScheme.tertiary, colorScheme),
                        ],
                      ),
                      if (location.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          location.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getLocationTypeIcon(location.type),
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getLocationTypeName(location.type),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action indicator
                if (!isCurrentLocation) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBadge(String label, Color color, ColorScheme colorScheme) {
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _handleLocationSelection(Location location) {
    final navigationSession = ref.read(navigationControllerProvider);
    
    // Don't allow selecting current location as destination
    if (location.id == navigationSession.currentLocationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot select current location as destination'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Call the callback if provided
    widget.onDestinationSelected?.call(location);
    
    // Set as destination in navigation controller
    ref.read(navigationControllerProvider.notifier).setDestination(location.id);
    
    // Close the selector
    Navigator.of(context).pop();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Destination set to ${location.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper methods for styling
  Color _getLocationItemBackgroundColor(
    ColorScheme colorScheme,
    bool isCurrentLocation,
    bool isDestination,
    bool isOnRoute,
  ) {
    if (isCurrentLocation) return colorScheme.primary.withOpacity(0.05);
    if (isDestination) return colorScheme.error.withOpacity(0.05);
    if (isOnRoute) return colorScheme.tertiary.withOpacity(0.05);
    return colorScheme.surface;
  }

  Color _getLocationItemBorderColor(
    ColorScheme colorScheme,
    bool isCurrentLocation,
    bool isDestination,
    bool isOnRoute,
  ) {
    if (isCurrentLocation) return colorScheme.primary.withOpacity(0.3);
    if (isDestination) return colorScheme.error.withOpacity(0.3);
    if (isOnRoute) return colorScheme.tertiary.withOpacity(0.3);
    return colorScheme.outline.withOpacity(0.2);
  }

  Color _getLocationItemIconColor(
    ColorScheme colorScheme,
    bool isCurrentLocation,
    bool isDestination,
    bool isOnRoute,
  ) {
    if (isCurrentLocation) return colorScheme.primary;
    if (isDestination) return colorScheme.error;
    if (isOnRoute) return colorScheme.tertiary;
    return colorScheme.onSurfaceVariant;
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

  String _getLocationTypeName(LocationType type) {
    switch (type) {
      case LocationType.room:
        return 'Room';
      case LocationType.hallway:
        return 'Hallway';
      case LocationType.entrance:
        return 'Entrance';
      case LocationType.elevator:
        return 'Elevator';
      case LocationType.stairs:
        return 'Stairs';
      case LocationType.restroom:
        return 'Restroom';
      case LocationType.office:
        return 'Office';
    }
  }
}

