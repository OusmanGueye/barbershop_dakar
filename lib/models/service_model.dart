class ServiceModel {
  final String id;
  final String barbershopId;
  final String name;
  final String? description;
  final int price;
  final int duration;
  final String? category;
  final bool isActive;
  final String? imageUrl;
  final DateTime createdAt;

  ServiceModel({
    required this.id,
    required this.barbershopId,
    required this.name,
    this.description,
    required this.price,
    required this.duration,
    this.category,
    this.isActive = true,
    this.imageUrl,
    required this.createdAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      barbershopId: json['barbershop_id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      duration: json['duration'],
      category: json['category'],
      isActive: json['is_active'] ?? true,
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barbershop_id': barbershopId,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'category': category,
      'is_active': isActive,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedPrice => '${price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ',
  )} FCFA';

  String get formattedDuration => '$duration min';
}