class AppConstants {
  // App Info
  static const String appName = 'Barbershop Dakar';
  static const String appVersion = '1.0.0';
  
  // Defaults
  static const int otpLength = 6;
  static const int otpTimeoutSeconds = 60;
  
  // Quartiers de Dakar
  static const List<String> dakarQuartiers = [
    'Plateau',
    'Médina',
    'Grand Dakar',
    'Parcelles Assainies',
    'Pikine',
    'Almadies',
    'Point E',
    'Mermoz',
    'Sacré-Cœur',
    'HLM',
    'Ngor',
    'Yoff',
    'Fann',
    'Ouakam',
  ];
  
  // Préfixes numéros Sénégal
  static const List<String> senegalPhonePrefixes = [
    '77', '78', '76', '70', '75'
  ];
  
  // Services types
  static const Map<String, int> defaultServices = {
    'Coupe Simple': 2000,
    'Coupe + Barbe': 3000,
    'Défrisage': 5000,
    'Coupe Enfant': 1500,
    'Locks': 7000,
    'Coloration': 8000,
  };
}