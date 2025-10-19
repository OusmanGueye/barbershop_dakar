import '../config/supabase_config.dart';
import '../models/barbershop_model.dart';
import '../models/service_model.dart';

class BarbershopService {
  final _supabase = SupabaseConfig.client;

  // Récupérer tous les barbershops
  Future<List<BarbershopModel>> getBarbershops() async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => BarbershopModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur chargement barbershops: ${e.toString()}');
    }
  }

  // Récupérer un barbershop par ID
  Future<BarbershopModel> getBarbershopById(String id) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('id', id)
          .single();

      return BarbershopModel.fromJson(response);
    } catch (e) {
      throw Exception('Erreur chargement barbershop: ${e.toString()}');
    }
  }

  // Récupérer les services d'un barbershop
  Future<List<ServiceModel>> getServices(String barbershopId) async {
    try {
      final response = await _supabase
          .from('services')
          .select()
          .eq('barbershop_id', barbershopId)
          .eq('is_active', true)
          .order('price', ascending: true);

      return (response as List)
          .map((json) => ServiceModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur chargement services: ${e.toString()}');
    }
  }

  // Rechercher des barbershops
  Future<List<BarbershopModel>> searchBarbershops(String query) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('is_active', true)
          .or('name.ilike.%$query%,quartier.ilike.%$query%,address.ilike.%$query%')
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => BarbershopModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur recherche: ${e.toString()}');
    }
  }

  // Récupérer les barbershops par quartier
  Future<List<BarbershopModel>> getBarbershopsByQuartier(String quartier) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('is_active', true)
          .eq('quartier', quartier)
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => BarbershopModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur filtrage quartier: ${e.toString()}');
    }
  }

  // Créer un barbershop
  Future<String> createBarbershop(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .insert(data)
          .select()
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Erreur création barbershop: $e');
    }
  }

  // AJOUTER CETTE MÉTHODE
  Future<void> updateBarbershop(String barbershopId, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('barbershops')
          .update(data)
          .eq('id', barbershopId);
    } catch (e) {
      throw Exception('Erreur mise à jour barbershop: $e');
    }
  }



// Ajouter les services par défaut
  Future<void> addDefaultServices(String barbershopId) async {
    try {
      final defaultServices = [
        {
          'barbershop_id': barbershopId,
          'name': 'Coupe Simple',
          'price': 2000,
          'duration': 30,
          'category': 'Coupe',
          'is_active': true,
        },
        {
          'barbershop_id': barbershopId,
          'name': 'Coupe + Barbe',
          'price': 3000,
          'duration': 45,
          'category': 'Coupe',
          'is_active': true,
        },
        {
          'barbershop_id': barbershopId,
          'name': 'Barbe Seule',
          'price': 1500,
          'duration': 20,
          'category': 'Barbe',
          'is_active': true,
        },
        {
          'barbershop_id': barbershopId,
          'name': 'Coupe Enfant',
          'price': 1500,
          'duration': 20,
          'category': 'Enfant',
          'is_active': true,
        },
        {
          'barbershop_id': barbershopId,
          'name': 'Défrisage',
          'price': 5000,
          'duration': 60,
          'category': 'Traitement',
          'is_active': true,
        },
      ];

      await _supabase.from('services').insert(defaultServices);
    } catch (e) {
      print('Erreur ajout services par défaut: $e');
    }
  }

  // Optionnel : Récupérer un barbershop
  Future<Map<String, dynamic>?> getBarbershop(String barbershopId) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('id', barbershopId)
          .single();

      return response;
    } catch (e) {
      print('Erreur récupération barbershop: $e');
      return null;
    }
  }

  // Optionnel : Récupérer les barbershops d'un owner
  Future<List<Map<String, dynamic>>> getOwnerBarbershops(String ownerId) async {
    try {
      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur récupération barbershops owner: $e');
      return [];
    }
  }



}
