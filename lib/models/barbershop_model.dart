class BarbershopModel {
  final String id;
  final String? ownerId;
  final String name;
  final String? phone;
  final String? address;
  final String? quartier;
  final double? latitude;
  final double? longitude;
  final String? openingTime;
  final String? closingTime;
  final List<String>? workingDays;
  final double rating;
  final int totalReviews;
  final bool isActive;
  final bool acceptsOnlinePayment;
  final String? waveNumber;
  final String? orangeMoneyNumber;
  final List<String>? photos; // Ancien champ, à garder pour compatibilité
  final String? description;
  final String? profileImage; // Image principale
  final List<String>? galleryImages; // Galerie
  final DateTime createdAt;
  final DateTime updatedAt;

  BarbershopModel({
    required this.id,
    this.ownerId,
    required this.name,
    this.phone,
    this.address,
    this.quartier,
    this.latitude,
    this.longitude,
    this.openingTime,
    this.closingTime,
    this.workingDays,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.isActive = true,
    this.acceptsOnlinePayment = false,
    this.waveNumber,
    this.orangeMoneyNumber,
    this.photos,
    this.description,
    this.profileImage,
    this.galleryImages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BarbershopModel.fromJson(Map<String, dynamic> json) {
    return BarbershopModel(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      quartier: json['quartier'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      openingTime: json['opening_time'],
      closingTime: json['closing_time'],
      workingDays: json['working_days'] != null
          ? List<String>.from(json['working_days'])
          : ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'],
      rating: (json['rating'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      isActive: json['is_active'] ?? true,
      acceptsOnlinePayment: json['accepts_online_payment'] ?? false,
      waveNumber: json['wave_number'],
      orangeMoneyNumber: json['orange_money_number'],
      photos: json['photos'] != null
          ? List<String>.from(json['photos'])
          : [],
      description: json['description'],
      profileImage: json['profile_image'], // AJOUT
      galleryImages: json['gallery_images'] != null
          ? List<String>.from(json['gallery_images'])
          : [], // AJOUT
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Vérifier si ouvert maintenant
  bool get isOpenNow {
    if (openingTime == null || closingTime == null) return false;

    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);

    if (workingDays?.contains(currentDay) != true) return false;

    final openTime = _parseTime(openingTime!);
    final closeTime = _parseTime(closingTime!);
    final currentMinutes = now.hour * 60 + now.minute;

    return currentMinutes >= openTime && currentMinutes <= closeTime;
  }

  String _getDayName(int weekday) {
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    return days[weekday - 1];
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // Obtenir l'image principale (avec fallback)
  String get mainImage {
    // Priorité : profileImage > photos > placeholder
    if (profileImage != null && profileImage!.isNotEmpty) {
      return profileImage!;
    }
    if (photos != null && photos!.isNotEmpty) {
      return photos!.first;
    }
    return 'https://via.placeholder.com/400x200/1A1A2E/FFFFFF?text=${Uri.encodeComponent(name)}';
  }
}
