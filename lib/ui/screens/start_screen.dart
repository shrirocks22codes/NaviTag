import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/nfc_service.dart';
import '../../controllers/navigation_controller.dart';
import 'scan_mode_screen.dart';
import 'manual_mode_screen.dart';

/// Starting screen for NaviTag NFC Navigator
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCheckingNFC = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _onScanModePressed() async {
    setState(() {
      _isCheckingNFC = true;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      final availabilityStatus = await nfcService.checkNFCAvailability();

      if (mounted) {
        setState(() {
          _isCheckingNFC = false;
        });

        if (availabilityStatus == NFCAvailabilityStatus.available) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ScanModeScreen(),
            ),
          );
        } else {
          _showNFCNotAvailableDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingNFC = false;
        });
        _showNFCNotAvailableDialog();
      }
    }
  }

  void _showNFCNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NFC Not Available'),
        content: const Text(
          'Your device is not NFC applicable. Try Manual mode instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _onManualModePressed();
            },
            child: const Text('Manual Mode'),
          ),
        ],
      ),
    );
  }

  void _onManualModePressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ManualModeScreen(),
      ),
    );
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
              colorScheme.primary.withOpacity(0.1),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.nfc,
                        size: 60,
                        color: colorScheme.onPrimary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App Title
                    Text(
                      'NaviTag',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'NFC Navigator',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // NFC Warning
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Make sure NFC is enabled on your device for the best experience',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.amber[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Mode Selection Buttons
                    Column(
                      children: [
                        // Scan Mode Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isCheckingNFC ? null : _onScanModePressed,
                            icon: _isCheckingNFC
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.nfc, size: 24),
                            label: Text(
                              _isCheckingNFC ? 'Checking NFC...' : 'Scan Mode',
                              style: const TextStyle(
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
                              elevation: 4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Manual Mode Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _onManualModePressed,
                            icon: const Icon(Icons.map, size: 24),
                            label: const Text(
                              'Manual Mode',
                              style: TextStyle(
                                fontSize: 18,
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

                    const SizedBox(height: 32),

                    // Mode Descriptions
                    Column(
                      children: [
                        _buildModeDescription(
                          icon: Icons.nfc,
                          title: 'Scan Mode',
                          description: 'Scan NFC tags to navigate step-by-step',
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        _buildModeDescription(
                          icon: Icons.map,
                          title: 'Manual Mode',
                          description: 'Choose start and end points manually',
                          color: colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeDescription({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}