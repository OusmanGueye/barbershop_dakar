class UserModel {
  final String id;
  final String phone;
  final String? fullName;
  final String role;
  String? avatarUrl; // tu peux laisser non-final si tu modifies parfois en place
  final String preferredLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.phone,
    this.fullName,
    this.role = 'client',
    this.avatarUrl,
    this.preferredLanguage = 'fr',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory depuis JSON (DB)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String?,
      role: (json['role'] as String?) ?? 'client',
      avatarUrl: json['avatar_url'] as String?,
      preferredLanguage: (json['preferred_language'] as String?) ?? 'fr',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Vers JSON (utile si tu veux re-sérialiser localement)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'preferred_language': preferredLanguage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// ✅ copyWith pour mettre à jour proprement
  UserModel copyWith({
    String? id,
    String? phone,
    String? fullName,
    String? role,
    String? avatarUrl,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Pour debug
  @override
  String toString() =>
      'UserModel(id: $id, phone: $phone, fullName: $fullName, role: $role, avatarUrl: $avatarUrl, lang: $preferredLanguage)';

  /// Égalité par valeur (confortable pour Provider & tests)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.phone == phone &&
        other.fullName == fullName &&
        other.role == role &&
        other.avatarUrl == avatarUrl &&
        other.preferredLanguage == preferredLanguage &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    fullName,
    role,
    avatarUrl,
    preferredLanguage,
    createdAt,
    updatedAt,
  );
}
