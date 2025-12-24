import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/location.dart';
import '../widgets/destination_selector_widget.dart';

/// A full-screen destination selector with mobile-optimized interface
class DestinationSelectorScreen extends ConsumerWidget {
  /// Optional callback when a destination is selected
  final void Function(Location destination)? onDestinationSelected;
  
  /// Whether to show the current location in the list
  final bool showCurrentLocation;
  
  /// Optional filter to limit which locations are shown
  final bool Function(Location location)? locationFilter;
  
  /// Custom title for the screen
  final String title;

  const DestinationSelectorScreen({
    super.key,
    this.onDestinationSelected,
    this.showCurrentLocation = false,
    this.locationFilter,
    this.title = 'Select Destination',
  });

  /// Static method to show the destination selector as a full screen
  static Future<Location?> showAsFullScreen(
    BuildContext context, {
    required void Function(Location destination) onDestinationSelected,
    bool showCurrentLocation = false,
    bool Function(Location location)? locationFilter,
    String title = 'Select Destination',
  }) {
    return Navigator.of(context).push<Location>(
      MaterialPageRoute(
        builder: (context) => DestinationSelectorScreen(
          onDestinationSelected: onDestinationSelected,
          showCurrentLocation: showCurrentLocation,
          locationFilter: locationFilter,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: DestinationSelectorWidget(
          onDestinationSelected: (location) {
            onDestinationSelected?.call(location);
            Navigator.of(context).pop(location);
          },
          showCurrentLocation: showCurrentLocation,
          locationFilter: locationFilter,
        ),
      ),
    );
  }

  /// Show the destination selector as a modal bottom sheet
  static Future<Location?> showAsBottomSheet(
    BuildContext context, {
    void Function(Location destination)? onDestinationSelected,
    bool showCurrentLocation = false,
    bool Function(Location location)? locationFilter,
  }) {
    return showModalBottomSheet<Location>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DestinationSelectorWidget(
            onDestinationSelected: (location) {
              onDestinationSelected?.call(location);
              Navigator.of(context).pop(location);
            },
            showCurrentLocation: showCurrentLocation,
            locationFilter: locationFilter,
          ),
        ),
      ),
    );
  }

}