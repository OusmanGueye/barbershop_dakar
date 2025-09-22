import '../config/supabase_config.dart';

class FavoriteService {
  final _supabase = SupabaseConfig.supabase;

  Future<bool> toggleFavorite(String barbershopId) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return false;

      // Vérifier si déjà en favori
      final existing = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('barbershop_id', barbershopId)
          .maybeSingle();

      if (existing != null) {
        // Retirer des favoris
        await _supabase
            .from('favorites')
            .delete()
            .eq('id', existing['id']);
        return false;
      } else {
        // Ajouter aux favoris
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'barbershop_id': barbershopId,
        });
        return true;
      }
    } catch (e) {
      print('Erreur toggle favorite: $e');
      return false;
    }
  }

  Future<List<String>> getUserFavorites() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('favorites')
          .select('barbershop_id')
          .eq('user_id', userId);

      return (response as List)
          .map((f) => f['barbershop_id'] as String)
          .toList();
    } catch (e) {
      print('Erreur get favorites: $e');
      return [];
    }
  }
}