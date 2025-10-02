// config/app_constants.dart
class AppConstants {
  // App Info
  static const String appName = 'BarberGo';
  static const String appVersion = '1.0.0';

  // Defaults
  static const int otpLength = 6;
  static const int otpTimeoutSeconds = 60;

  // Zones et quartiers de Dakar (organisé par zone)
  static const Map<String, List<String>> dakarZones = {
    'Dakar-Plateau': [
      'Plateau',
      'Médina',
      'Fann',
      'Point E',
      'Gueule Tapée',
      'Fass',
      'Colobane',
    ],

    'Grand Dakar': [
      'Grand Dakar',
      'Biscuiterie',
      'Dieuppeul',
      'Derklé',
      'HLM',
      'HLM Grand Yoff',
      'Liberté 1',
      'Liberté 2',
      'Liberté 3',
      'Liberté 4',
      'Liberté 5',
      'Liberté 6',
    ],

    'Parcelles/Cambérène': [
      'Parcelles Assainies',
      'Cambérène',
      'Golf',
      'Keur Massar',
    ],

    'Pikine/Guédiawaye': [
      'Pikine',
      'Pikine Nord',
      'Pikine Est',
      'Pikine Ouest',
      'Guédiawaye',
      'Thiaroye',
      'Yeumbeul',
      'Malika',
    ],

    'Almadies/Ngor/Yoff': [
      'Almadies',
      'Ngor',
      'Virage',
      'Mamelles',
      'Ouakam',
      'Mermoz',
      'Sacré-Cœur',
      'Yoff',
      'Nord Foire',
      'Ouest Foire',
    ],

    'Sicap/Baobabs': [
      'Sicap Liberté',
      'Sicap Baobabs',
      'Sicap Karack',
      'Sicap Amitié',
    ],

    'Autres': [
      'Hann',
      'Hann Bel-Air',
      'Yarakh',
      'Rufisque',
      'Bargny',
      'Diamniadio',
    ],
  };

  // Liste plate de tous les quartiers (pour les filtres)
  static List<String> get dakarQuartiers {
    final List<String> quartiers = [];
    dakarZones.forEach((zone, list) {
      quartiers.addAll(list);
    });
    return quartiers..sort();
  }

  // Quartiers populaires (affichage prioritaire)
  static const List<String> popularQuartiers = [
    'Plateau',
    'Médina',
    'Almadies',
    'Parcelles Assainies',
    'Sacré-Cœur',
    'Mermoz',
    'Point E',
    'Grand Dakar',
    'Yoff',
    'HLM',
    'Pikine',
    'Ouakam',
  ];

  // Préfixes numéros Sénégal
  static const List<String> senegalPhonePrefixes = [
    '77', '78', '76', '70', '75', '33'
  ];

  // Services par catégorie
  static const Map<String, Map<String, int>> servicesByCategory = {
    'Coupe': {
      'Coupe Simple': 2000,
      'Coupe Moderne': 2500,
      'Dégradé': 3000,
      'Fade': 3500,
    },
    'Barbe': {
      'Taille Barbe': 1500,
      'Barbe Complète': 2500,
      'Rasage Traditionnel': 3000,
    },
    'Soins': {
      'Shampoing': 1000,
      'Masque': 2000,
      'Massage': 2500,
    },
    'Coloration': {
      'Coloration Simple': 5000,
      'Mèches': 6000,
      'Décoloration': 8000,
    },
    'Locks': {
      'Entretien Locks': 5000,
      'Création Locks': 10000,
      'Coiffure Locks': 7000,
    },
    'Enfant': {
      'Coupe Enfant': 1500,
      'Première Coupe': 2000,
    },
  };

  // Services par défaut (liste simplifiée)
  static Map<String, int> get defaultServices {
    final Map<String, int> services = {};
    servicesByCategory.forEach((category, items) {
      services.addAll(items);
    });
    return services;
  }

  // Horaires par défaut
  static const String defaultOpeningTime = '08:00:00';
  static const String defaultClosingTime = '20:00:00';
  static const List<String> defaultWorkingDays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'
  ];

  // Méthodes de paiement
  static const List<String> paymentMethods = [
    'Espèces',
    'Wave',
    'Orange Money',
    'Free Money',
  ];

  // Durées de réservation (en minutes)
  static const List<int> appointmentDurations = [
    15, 30, 45, 60, 90, 120
  ];

  // Messages de validation
  static const String phoneValidationError = 'Numéro de téléphone invalide';
  static const String emailValidationError = 'Email invalide';
  static const String requiredFieldError = 'Ce champ est obligatoire';

  // Helper pour obtenir la zone d'un quartier
  static String? getZoneForQuartier(String quartier) {
    for (final entry in dakarZones.entries) {
      if (entry.value.contains(quartier)) {
        return entry.key;
      }
    }
    return null;
  }

  // Helper pour valider un numéro sénégalais
  static bool isValidSenegalPhone(String phone) {
    // Enlever les espaces et le préfixe +221 si présent
    String cleaned = phone.replaceAll(' ', '').replaceAll('+221', '');

    // Vérifier la longueur (9 chiffres)
    if (cleaned.length != 9) return false;

    // Vérifier le préfixe
    String prefix = cleaned.substring(0, 2);
    return senegalPhonePrefixes.contains(prefix);
  }
}
