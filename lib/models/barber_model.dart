class BarberModel {
  final String id;
  final String userId;
  final String barbershopId;
  final String? displayName;
  final String? photoUrl;
  final List<String> specialties;
  final int experienceYears;
  final bool isAvailable;
  final double rating;
  final String? bio;
  final int monthlyCuts;
  final int totalCuts;
  final DateTime createdAt;

  BarberModel({
    required this.id,
    required this.userId,
    required this.barbershopId,
    this.displayName,
    this.photoUrl,
    this.specialties = const [],
    this.experienceYears = 0,
    this.isAvailable = true,
    this.rating = 0.0,
    this.bio,
    this.monthlyCuts = 0,
    this.totalCuts = 0,
    required this.createdAt,
  });

  factory BarberModel.fromJson(Map<String, dynamic> json) {
    return BarberModel(
      id: json['id'],
      userId: json['user_id'],
      barbershopId: json['barbershop_id'],
      displayName: json['display_name'],
      photoUrl: json['photo_url'],
      specialties: json['specialties'] != null
          ? List<String>.from(json['specialties'])
          : [],
      experienceYears: json['experience_years'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      rating: (json['rating'] ?? 0).toDouble(),
      bio: json['bio'],
      monthlyCuts: json['monthly_cuts'] ?? 0,
      totalCuts: json['total_cuts'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get profileImage {
    return photoUrl ?? 'https://ui-avatars.com/api/?name=${displayName ?? 'Barbier'}&background=1A1A2E&color=fff';
  }
}