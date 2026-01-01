import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/nfc_service.dart';
import '../../controllers/navigation_controller.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import 'scan_mode_screen.dart';
import 'manual_mode_screen.dart';


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

  void _showNFCNotAvailableDialog() async {
    final nfcService = ref.read(nfcServiceProvider);
    final availabilityStatus = await nfcService.checkNFCAvailability();
    
    if (!mounted) return; // Check if widget is still mounted
    
    String title = 'NFC Not Available';
    String message = 'Your device is not NFC applicable. Try Manual mode instead.';
    
    switch (availabilityStatus) {
      case NFCAvailabilityStatus.disabled:
        title = 'NFC Disabled';
        message = 'NFC is disabled on your device. Please enable NFC in Settings and try again, or use Manual mode instead.';
        break;
      case NFCAvailabilityStatus.notSupported:
        title = 'NFC Not Supported';
        message = 'Your device does not support NFC. Please use Manual mode instead.';
        break;
      case NFCAvailabilityStatus.unknown:
        title = 'NFC Status Unknown';
        message = 'Unable to determine NFC status. This may be due to device restrictions. Try Manual mode instead.';
        break;
      case NFCAvailabilityStatus.available:
        title = 'NFC Issue';
        message = 'NFC appears to be available but there was an issue starting scan mode. Try again or use Manual mode.';
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (availabilityStatus == NFCAvailabilityStatus.disabled)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try again after user potentially enables NFC
                _onScanModePressed();
              },
              child: const Text('Try Again'),
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    
    // Get current language and localizations
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations(currentLanguage);
    
    // Responsive sizing
    final logoSize = isSmallScreen ? 80.0 : 120.0;
    final iconSize = isSmallScreen ? 40.0 : 60.0;
    final titleStyle = isSmallScreen 
        ? theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          )
        : theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          );
    final verticalSpacing = isSmallScreen ? 16.0 : 32.0;
    final largeVerticalSpacing = isSmallScreen ? 24.0 : 48.0;
    final buttonHeight = isSmallScreen ? 48.0 : 56.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageSelector(),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.1),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
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
                        
                        // App Logo/Icon
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.nfc,
                            size: iconSize,
                            color: colorScheme.onPrimary,
                          ),
                        ),

                        SizedBox(height: verticalSpacing),

                        // App Title
                        Text(
                          l10n.get('app_name'),
                          style: titleStyle,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          l10n.get('app_subtitle'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                        ),

                        SizedBox(height: largeVerticalSpacing),

                        // NFC Warning
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber[700],
                                size: isSmallScreen ? 20 : 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.get('nfc_warning'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: largeVerticalSpacing),

                        // Mode Selection Buttons
                        Column(
                          children: [
                            // Scan Mode Button
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
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
                                    : Icon(Icons.nfc, size: isSmallScreen ? 20 : 24),
                                label: Text(
                                  _isCheckingNFC ? l10n.get('checking_nfc') : l10n.get('scan_mode'),
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

                            // Manual Mode Button
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: OutlinedButton.icon(
                                onPressed: _onManualModePressed,
                                icon: Icon(Icons.map, size: isSmallScreen ? 20 : 24),
                                label: Text(
                                  l10n.get('manual_mode'),
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

                        // Mode Descriptions
                        Column(
                          children: [
                            _buildModeDescription(
                              icon: Icons.nfc,
                              title: l10n.get('scan_mode'),
                              description: l10n.get('scan_mode_desc'),
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            _buildModeDescription(
                              icon: Icons.map,
                              title: l10n.get('manual_mode'),
                              description: l10n.get('manual_mode_desc'),
                              color: colorScheme.secondary,
                            ),
                          ],
                        ),
                        
                        SizedBox(height: verticalSpacing),
                      ],
                    ),
                  ),
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
            color: color.withValues(alpha: 0.1),
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
