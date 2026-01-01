import '../providers/language_provider.dart';

/// Application localizations with translations for all supported languages
class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  /// Get the localized string for a given key
  String get(String key) {
    return _translations[language]?[key] ?? _translations[AppLanguage.english]?[key] ?? key;
  }

  /// All translations organized by language
  static final Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.english: {
      // Start Screen
      'app_name': 'NaviTag',
      'app_subtitle': 'NFC Navigator',
      'nfc_warning': 'Make sure NFC is enabled on your device for the best experience',
      'scan_mode': 'Scan Mode',
      'manual_mode': 'Manual Mode',
      'checking_nfc': 'Checking NFC...',
      'scan_mode_desc': 'Scan NFC tags to navigate step-by-step',
      'manual_mode_desc': 'Choose start and end points manually. Use if you know where you are.',
      
      // Scan Mode Screen
      'scan_mode_title': 'Scan Mode',
      'navigation_active': 'Navigation Active',
      'scan_nearest_tag': 'Scan the nearest NFC tag',
      'set_as_starting': 'This will be set as your starting position',
      'start_location_set': 'Start location set!',
      'choose_destination_begin': 'Choose your destination to begin navigation',
      'choose_destination': 'Choose Destination',
      'stop_navigation': 'Stop Navigation',
      'scan_next_checkpoint': 'Scan the next checkpoint to continue',
      'next_scan': 'Next: Scan',
      'look_for_marker': 'Look for the orange marker on the map',
      
      // Manual Mode Screen
      'manual_mode_title': 'Manual Mode',
      'start': 'Start',
      'destination': 'Destination',
      'not_selected': 'Not selected',
      'select_starting_location': 'Select your starting location',
      'select_destination': 'Now select your destination',
      'both_selected': 'Both locations selected!',
      'nav_active_follow': 'Navigation active - Follow the route',
      'start_navigation': 'Start Navigation',
      'simulate_arrival': 'Simulate Arrival',
      'reset_selection': 'Reset Selection',
      
      // Destination Reached Screen
      'destination_reached': 'Destination Reached!',
      'success_message': 'You have successfully reached your destination.',
      'journey_summary': 'Journey Summary',
      'actual_time': 'Actual Time',
      'est_time': 'Est. Time',
      'checkpoints': 'Checkpoints',
      'view_journey_map': 'View Journey Map',
      'go_home': 'Go Home',
      'journey_completed': 'Journey Completed',
      'path_from_start': 'Your path from start to destination',
      
      // Common
      'cancel': 'Cancel',
      'try_again': 'Try Again',
      'select_language': 'Select Language',
      'language_changed': 'Language changed to',
      
      // NFC Dialogs
      'nfc_not_available': 'NFC Not Available',
      'nfc_disabled': 'NFC Disabled',
      'nfc_not_supported': 'NFC Not Supported',
      'nfc_status_unknown': 'NFC Status Unknown',
      'nfc_issue': 'NFC Issue',
      'nfc_not_applicable': 'Your device is not NFC applicable. Try Manual mode instead.',
      'nfc_disabled_message': 'NFC is disabled on your device. Please enable NFC in Settings and try again, or use Manual mode instead.',
      'nfc_not_supported_message': 'Your device does not support NFC. Please use Manual mode instead.',
      'nfc_unknown_message': 'Unable to determine NFC status. This may be due to device restrictions. Try Manual mode instead.',
      'nfc_available_issue': 'NFC appears to be available but there was an issue starting scan mode. Try again or use Manual mode.',
      
      // Instructions
      'start_journey': 'Start your journey',
      'move_forward': 'Move forward until you reach the checkpoint',
      'take_turn': 'Take a turn and keep moving forward',
      'reached_destination': 'You have reached your destination!',
      'continue_path': 'Continue following the path',
    },
    
    AppLanguage.spanish: {
      // Start Screen
      'app_name': 'NaviTag',
      'app_subtitle': 'Navegador NFC',
      'nfc_warning': 'Asegúrese de que NFC esté habilitado en su dispositivo para la mejor experiencia',
      'scan_mode': 'Modo Escaneo',
      'manual_mode': 'Modo Manual',
      'checking_nfc': 'Verificando NFC...',
      'scan_mode_desc': 'Escanee etiquetas NFC para navegar paso a paso',
      'manual_mode_desc': 'Elija los puntos de inicio y fin manualmente. Úselo si sabe dónde está.',
      
      // Scan Mode Screen
      'scan_mode_title': 'Modo Escaneo',
      'navigation_active': 'Navegación Activa',
      'scan_nearest_tag': 'Escanee la etiqueta NFC más cercana',
      'set_as_starting': 'Esta será su posición inicial',
      'start_location_set': '¡Ubicación inicial establecida!',
      'choose_destination_begin': 'Elija su destino para comenzar la navegación',
      'choose_destination': 'Elegir Destino',
      'stop_navigation': 'Detener Navegación',
      'scan_next_checkpoint': 'Escanee el siguiente punto de control para continuar',
      'next_scan': 'Siguiente: Escanear',
      'look_for_marker': 'Busque el marcador naranja en el mapa',
      
      // Manual Mode Screen
      'manual_mode_title': 'Modo Manual',
      'start': 'Inicio',
      'destination': 'Destino',
      'not_selected': 'No seleccionado',
      'select_starting_location': 'Seleccione su ubicación inicial',
      'select_destination': 'Ahora seleccione su destino',
      'both_selected': '¡Ambas ubicaciones seleccionadas!',
      'nav_active_follow': 'Navegación activa - Siga la ruta',
      'start_navigation': 'Iniciar Navegación',
      'simulate_arrival': 'Simular Llegada',
      'reset_selection': 'Restablecer Selección',
      
      // Destination Reached Screen
      'destination_reached': '¡Destino Alcanzado!',
      'success_message': 'Ha llegado exitosamente a su destino.',
      'journey_summary': 'Resumen del Viaje',
      'actual_time': 'Tiempo Real',
      'est_time': 'Tiempo Est.',
      'checkpoints': 'Puntos de Control',
      'view_journey_map': 'Ver Mapa del Viaje',
      'go_home': 'Ir al Inicio',
      'journey_completed': 'Viaje Completado',
      'path_from_start': 'Su ruta desde el inicio hasta el destino',
      
      // Common
      'cancel': 'Cancelar',
      'try_again': 'Intentar de Nuevo',
      'select_language': 'Seleccionar Idioma',
      'language_changed': 'Idioma cambiado a',
      
      // NFC Dialogs
      'nfc_not_available': 'NFC No Disponible',
      'nfc_disabled': 'NFC Deshabilitado',
      'nfc_not_supported': 'NFC No Soportado',
      'nfc_status_unknown': 'Estado NFC Desconocido',
      'nfc_issue': 'Problema con NFC',
      'nfc_not_applicable': 'Su dispositivo no es compatible con NFC. Pruebe el modo Manual.',
      'nfc_disabled_message': 'NFC está deshabilitado. Habilítelo en Configuración e intente de nuevo, o use el modo Manual.',
      'nfc_not_supported_message': 'Su dispositivo no soporta NFC. Use el modo Manual.',
      'nfc_unknown_message': 'No se puede determinar el estado de NFC. Pruebe el modo Manual.',
      'nfc_available_issue': 'NFC parece disponible pero hubo un problema. Intente de nuevo o use el modo Manual.',
      
      // Instructions
      'start_journey': 'Comience su viaje',
      'move_forward': 'Avance hasta llegar al punto de control',
      'take_turn': 'Gire y siga adelante',
      'reached_destination': '¡Ha llegado a su destino!',
      'continue_path': 'Continue siguiendo la ruta',
    },
    
    AppLanguage.french: {
      // Start Screen
      'app_name': 'NaviTag',
      'app_subtitle': 'Navigateur NFC',
      'nfc_warning': 'Assurez-vous que NFC est activé sur votre appareil pour la meilleure expérience',
      'scan_mode': 'Mode Scan',
      'manual_mode': 'Mode Manuel',
      'checking_nfc': 'Vérification NFC...',
      'scan_mode_desc': 'Scannez les balises NFC pour naviguer étape par étape',
      'manual_mode_desc': 'Choisissez les points de départ et d\'arrivée manuellement.',
      
      // Scan Mode Screen
      'scan_mode_title': 'Mode Scan',
      'navigation_active': 'Navigation Active',
      'scan_nearest_tag': 'Scannez la balise NFC la plus proche',
      'set_as_starting': 'Ceci sera défini comme votre position de départ',
      'start_location_set': 'Position de départ définie!',
      'choose_destination_begin': 'Choisissez votre destination pour commencer',
      'choose_destination': 'Choisir Destination',
      'stop_navigation': 'Arrêter Navigation',
      'scan_next_checkpoint': 'Scannez le prochain point de contrôle',
      'next_scan': 'Suivant: Scanner',
      'look_for_marker': 'Recherchez le marqueur orange sur la carte',
      
      // Manual Mode Screen
      'manual_mode_title': 'Mode Manuel',
      'start': 'Départ',
      'destination': 'Destination',
      'not_selected': 'Non sélectionné',
      'select_starting_location': 'Sélectionnez votre position de départ',
      'select_destination': 'Maintenant sélectionnez votre destination',
      'both_selected': 'Les deux emplacements sélectionnés!',
      'nav_active_follow': 'Navigation active - Suivez l\'itinéraire',
      'start_navigation': 'Démarrer Navigation',
      'simulate_arrival': 'Simuler Arrivée',
      'reset_selection': 'Réinitialiser Sélection',
      
      // Destination Reached Screen
      'destination_reached': 'Destination Atteinte!',
      'success_message': 'Vous avez atteint votre destination avec succès.',
      'journey_summary': 'Résumé du Voyage',
      'actual_time': 'Temps Réel',
      'est_time': 'Temps Est.',
      'checkpoints': 'Points de Contrôle',
      'view_journey_map': 'Voir Carte du Voyage',
      'go_home': 'Accueil',
      'journey_completed': 'Voyage Terminé',
      'path_from_start': 'Votre itinéraire du début à la destination',
      
      // Common
      'cancel': 'Annuler',
      'try_again': 'Réessayer',
      'select_language': 'Choisir la Langue',
      'language_changed': 'Langue changée en',
      
      // NFC Dialogs
      'nfc_not_available': 'NFC Non Disponible',
      'nfc_disabled': 'NFC Désactivé',
      'nfc_not_supported': 'NFC Non Supporté',
      'nfc_status_unknown': 'État NFC Inconnu',
      'nfc_issue': 'Problème NFC',
      'nfc_not_applicable': 'Votre appareil n\'est pas compatible NFC. Essayez le mode Manuel.',
      'nfc_disabled_message': 'NFC est désactivé. Activez-le dans les Paramètres et réessayez.',
      'nfc_not_supported_message': 'Votre appareil ne supporte pas NFC. Utilisez le mode Manuel.',
      'nfc_unknown_message': 'Impossible de déterminer l\'état NFC. Essayez le mode Manuel.',
      'nfc_available_issue': 'NFC semble disponible mais il y a eu un problème. Réessayez ou utilisez le mode Manuel.',
      
      // Instructions
      'start_journey': 'Commencez votre voyage',
      'move_forward': 'Avancez jusqu\'au point de contrôle',
      'take_turn': 'Tournez et continuez tout droit',
      'reached_destination': 'Vous êtes arrivé à destination!',
      'continue_path': 'Continuez à suivre le chemin',
    },
  };
}
