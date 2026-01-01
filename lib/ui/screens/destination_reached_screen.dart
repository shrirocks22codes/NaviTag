import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/route.dart' as app_route;
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/interactive_map_widget.dart';
import 'start_screen.dart';

/// Screen shown when the user reaches their destination
class DestinationReachedScreen extends ConsumerStatefulWidget {
  final app_route.Route completedRoute;
  final List<String> pathTaken;
  final Duration? actualTimeTaken;

  const DestinationReachedScreen({
    super.key,
    required this.completedRoute,
    required this.pathTaken,
    this.actualTimeTaken,
  });

  @override
  ConsumerState<DestinationReachedScreen> createState() => _DestinationReachedScreenState();
}

class _DestinationReachedScreenState extends ConsumerState<DestinationReachedScreen>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showingMap = false;

  @override
  void initState() {
    super.initState();
    
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Start celebration animation
    _celebrationController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const StartScreen()),
      (route) => false,
    );
  }

  void _toggleMapView() {
    setState(() {
      _showingMap = !_showingMap;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else if (duration.inSeconds > 0) {
      return '${duration.inSeconds}s';
    } else {
      // For very short durations, show a minimum time
      return '30s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.withValues(alpha: 0.1),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _showingMap ? _buildMapView() : _buildCelebrationView(),
        ),
      ),
    );
  }

  Widget _buildCelebrationView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    
    // Get current language and localizations
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations(currentLanguage);
    
    // Responsive sizing
    final celebrationIconSize = isSmallScreen ? 100.0 : 150.0;
    final flagIconSize = isSmallScreen ? 50.0 : 80.0;
    final verticalSpacing = isSmallScreen ? 16.0 : 32.0;
    final largeVerticalSpacing = isSmallScreen ? 24.0 : 48.0;
    final buttonHeight = isSmallScreen ? 48.0 : 56.0;
    final containerPadding = isSmallScreen ? 16.0 : 24.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: verticalSpacing),
                
                // Celebration icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: celebrationIconSize,
                    height: celebrationIconSize,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.flag,
                      size: flagIconSize,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: verticalSpacing),

                // Success message
                Text(
                  l10n.get('destination_reached'),
                  style: (isSmallScreen 
                      ? theme.textTheme.headlineMedium 
                      : theme.textTheme.displaySmall)?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  l10n.get('success_message'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: largeVerticalSpacing),

                // Journey statistics
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(containerPadding),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.get('journey_summary'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 20),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            icon: Icons.access_time,
                            value: _formatDuration(widget.actualTimeTaken ?? widget.completedRoute.estimatedTime),
                            label: widget.actualTimeTaken != null ? l10n.get('actual_time') : l10n.get('est_time'),
                            color: Colors.orange,
                          ),
                          _buildStatCard(
                            icon: Icons.location_on,
                            value: '${widget.pathTaken.length}',
                            label: l10n.get('checkpoints'),
                            color: Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: largeVerticalSpacing),

                // Action buttons
                Column(
                  children: [
                    // View Map button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _toggleMapView,
                        icon: Icon(Icons.map, size: isSmallScreen ? 20 : 24),
                        label: Text(
                          l10n.get('view_journey_map'),
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
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Go Home button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: OutlinedButton.icon(
                        onPressed: _goHome,
                        icon: Icon(Icons.home, size: isSmallScreen ? 20 : 24),
                        label: Text(
                          l10n.get('go_home'),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleMapView,
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surface,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journey Completed',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Your path from start to destination',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
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
                locations: [],
                activeRoute: widget.completedRoute,
                currentLocationId: widget.completedRoute.startLocationId,
                destinationLocationId: widget.completedRoute.endLocationId,
                showLocationLabels: true,
                isCompletedJourney: true,
              ),
            ),
          ),
        ),

        // Bottom actions
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home, size: 24),
              label: const Text(
                'Go Home',
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
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
