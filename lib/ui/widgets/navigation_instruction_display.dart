import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_project_test/models/route.dart' as nav_route;
import '../../controllers/navigation_controller.dart';
import '../../models/route.dart';

/// A widget that displays turn-by-turn navigation instructions with animations
/// and progress indicators optimized for mobile screens
class NavigationInstructionDisplay extends ConsumerStatefulWidget {
  /// Whether to show the instruction display as an overlay
  final bool isOverlay;
  
  /// Optional callback when the instruction is tapped
  final VoidCallback? onTap;
  
  /// Whether to show detailed progress information
  final bool showProgress;

  const NavigationInstructionDisplay({
    super.key,
    this.isOverlay = true,
    this.onTap,
    this.showProgress = true,
  });

  @override
  ConsumerState<NavigationInstructionDisplay> createState() => _NavigationInstructionDisplayState();
}

class _NavigationInstructionDisplayState extends ConsumerState<NavigationInstructionDisplay>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  
  NavigationInstruction? _previousInstruction;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Initialize animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutQuart,
    ));
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final navigationSession = ref.watch(navigationControllerProvider);
    
    // Only show during active navigation
    if (navigationSession.state != NavigationState.navigating || 
        navigationSession.currentInstruction == null) {
      return const SizedBox.shrink();
    }
    
    final instruction = navigationSession.currentInstruction!;
    final route = navigationSession.activeRoute!;
    
    // Trigger animations when instruction changes
    _handleInstructionChange(instruction);
    
    final content = _buildInstructionContent(context, instruction, route, navigationSession);
    
    if (widget.isOverlay) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: content,
      );
    }
    
    return content;
  }
  
  void _handleInstructionChange(NavigationInstruction instruction) {
    if (_previousInstruction?.id != instruction.id) {
      // New instruction - trigger animations
      _slideController.forward();
      _fadeController.forward();
      _progressController.reset();
      _progressController.forward();
      
      _previousInstruction = instruction;
    }
  }
  
  Widget _buildInstructionContent(
    BuildContext context,
    NavigationInstruction instruction,
    nav_route.Route route,
    NavigationSession session,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main instruction row
                  Row(
                    children: [
                      _buildDirectionIcon(instruction, colorScheme),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getInstructionTitle(instruction),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20, // Mobile-optimized size
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              instruction.description,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16, // Mobile-optimized size
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Distance information
                  if (instruction.distance > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDistance(instruction.distance),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Progress information
                  if (widget.showProgress) ...[
                    const SizedBox(height: 16),
                    _buildProgressSection(context, route, session),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDirectionIcon(NavigationInstruction instruction, ColorScheme colorScheme) {
    IconData icon;
    Color backgroundColor;
    Color iconColor;
    
    switch (instruction.type) {
      case InstructionType.start:
        icon = Icons.play_arrow;
        backgroundColor = Colors.green.withOpacity(0.2);
        iconColor = Colors.green;
        break;
      case InstructionType.turn:
        icon = _getTurnIcon(instruction.direction);
        backgroundColor = colorScheme.primaryContainer.withOpacity(0.3);
        iconColor = colorScheme.primary;
        break;
      case InstructionType.straight:
        icon = Icons.arrow_upward;
        backgroundColor = colorScheme.secondaryContainer.withOpacity(0.3);
        iconColor = colorScheme.secondary;
        break;
      case InstructionType.destination:
        icon = Icons.flag;
        backgroundColor = Colors.red.withOpacity(0.2);
        iconColor = Colors.red;
        break;
      case InstructionType.reroute:
        icon = Icons.alt_route;
        backgroundColor = Colors.orange.withOpacity(0.2);
        iconColor = Colors.orange;
        break;
    }
    
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Transform.scale(
            scale: 0.8 + (0.2 * _progressAnimation.value),
            child: Icon(
              icon,
              size: 28,
              color: iconColor,
            ),
          ),
        );
      },
    );
  }
  
  IconData _getTurnIcon(Direction direction) {
    switch (direction) {
      case Direction.left:
        return Icons.turn_left;
      case Direction.right:
        return Icons.turn_right;
      case Direction.back:
        return Icons.u_turn_left;
      case Direction.up:
        return Icons.keyboard_arrow_up;
      case Direction.down:
        return Icons.keyboard_arrow_down;
      case Direction.forward:
      default:
        return Icons.arrow_upward;
    }
  }
  
  String _getInstructionTitle(NavigationInstruction instruction) {
    switch (instruction.type) {
      case InstructionType.start:
        return 'Start Navigation';
      case InstructionType.turn:
        return _getTurnTitle(instruction.direction);
      case InstructionType.straight:
        return 'Continue Straight';
      case InstructionType.destination:
        return 'Destination Reached';
      case InstructionType.reroute:
        return 'Route Updated';
    }
  }
  
  String _getTurnTitle(Direction direction) {
    switch (direction) {
      case Direction.left:
        return 'Turn Left';
      case Direction.right:
        return 'Turn Right';
      case Direction.back:
        return 'Turn Around';
      case Direction.up:
        return 'Go Up';
      case Direction.down:
        return 'Go Down';
      case Direction.forward:
      default:
        return 'Continue Forward';
    }
  }
  
  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
  
  Widget _buildProgressSection(BuildContext context, nav_route.Route route, NavigationSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final totalSteps = route.pathLocationIds.length;
    final currentStep = session.currentStepIndex + 1;
    final progress = totalSteps > 0 ? currentStep / totalSteps : 0.0;
    
    return Column(
      children: [
        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress * _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Progress information row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Step counter
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Step $currentStep of $totalSteps',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            
            // Remaining distance and time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _getRemainingTime(route, session),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  String _getRemainingTime(nav_route.Route route, NavigationSession session) {
    final totalMinutes = route.estimatedTime.inMinutes;
    final progressRatio = session.currentStepIndex / route.pathLocationIds.length;
    final remainingMinutes = (totalMinutes * (1 - progressRatio)).round();
    
    if (remainingMinutes <= 0) {
      return 'Arriving';
    } else if (remainingMinutes < 60) {
      return '${remainingMinutes}min';
    } else {
      final hours = remainingMinutes ~/ 60;
      final minutes = remainingMinutes % 60;
      return '${hours}h ${minutes}min';
    }
  }
}

/// A compact version of the instruction display for smaller spaces
class CompactNavigationInstructionDisplay extends ConsumerWidget {
  const CompactNavigationInstructionDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationSession = ref.watch(navigationControllerProvider);
    
    if (navigationSession.state != NavigationState.navigating || 
        navigationSession.currentInstruction == null) {
      return const SizedBox.shrink();
    }
    
    final instruction = navigationSession.currentInstruction!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCompactIcon(instruction, colorScheme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getCompactTitle(instruction),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (instruction.distance > 0)
                  Text(
                    _formatDistance(instruction.distance),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactIcon(NavigationInstruction instruction, ColorScheme colorScheme) {
    IconData icon;
    Color iconColor;
    
    switch (instruction.type) {
      case InstructionType.start:
        icon = Icons.play_arrow;
        iconColor = Colors.green;
        break;
      case InstructionType.turn:
        icon = _getTurnIcon(instruction.direction);
        iconColor = colorScheme.primary;
        break;
      case InstructionType.straight:
        icon = Icons.arrow_upward;
        iconColor = colorScheme.secondary;
        break;
      case InstructionType.destination:
        icon = Icons.flag;
        iconColor = Colors.red;
        break;
      case InstructionType.reroute:
        icon = Icons.alt_route;
        iconColor = Colors.orange;
        break;
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: iconColor,
      ),
    );
  }
  
  IconData _getTurnIcon(Direction direction) {
    switch (direction) {
      case Direction.left:
        return Icons.turn_left;
      case Direction.right:
        return Icons.turn_right;
      case Direction.back:
        return Icons.u_turn_left;
      case Direction.up:
        return Icons.keyboard_arrow_up;
      case Direction.down:
        return Icons.keyboard_arrow_down;
      case Direction.forward:
      default:
        return Icons.arrow_upward;
    }
  }
  
  String _getCompactTitle(NavigationInstruction instruction) {
    switch (instruction.type) {
      case InstructionType.start:
        return 'Start Navigation';
      case InstructionType.turn:
        return _getTurnTitle(instruction.direction);
      case InstructionType.straight:
        return 'Continue Straight';
      case InstructionType.destination:
        return 'Destination Reached';
      case InstructionType.reroute:
        return 'Route Updated';
    }
  }
  
  String _getTurnTitle(Direction direction) {
    switch (direction) {
      case Direction.left:
        return 'Turn Left';
      case Direction.right:
        return 'Turn Right';
      case Direction.back:
        return 'Turn Around';
      case Direction.up:
        return 'Go Up';
      case Direction.down:
        return 'Go Down';
      case Direction.forward:
      default:
        return 'Continue Forward';
    }
  }
  
  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
}