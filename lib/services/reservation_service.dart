import '../config/supabase_config.dart';
import '../models/reservation_model.dart';

class ReservationService {
  final _supabase = SupabaseConfig.client;

  // Créer une réservation
  Future<ReservationModel> createReservation(Map<String, dynamic> data) async {
    try {
      print('Tentative de création avec: $data'); // Debug

      final response = await _supabase
          .from('reservations')
          .insert(data)
          .select()
          .single();

      print('Réponse Supabase: $response'); // Debug
      return ReservationModel.fromJson(response);
    } catch (e) {
      print('Erreur détaillée: $e'); // Debug
      throw Exception('Erreur création réservation: ${e.toString()}');
    }
  }

  // Récupérer mes réservations
  Future<List<ReservationModel>> getMyReservations() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) throw Exception('Non connecté');

      final response = await _supabase
          .from('reservations')
          .select('''
            *,
            barbershops!inner(*),
            services!inner(*)
          ''')
          .eq('client_id', userId)
          .order('date', ascending: false);

      return (response as List)
          .map((json) {
        // Restructurer les données pour correspondre au modèle
        json['barbershop'] = json['barbershops'];
        json['service'] = json['services'];
        return ReservationModel.fromJson(json);
      })
          .toList();
    } catch (e) {
      print('Erreur chargement réservations: $e');
      throw Exception('Erreur chargement réservations: ${e.toString()}');
    }
  }

  // Annuler une réservation
  Future<void> cancelReservation(String reservationId) async {
    try {
      await _supabase
          .from('reservations')
          .update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String()
      })
          .eq('id', reservationId);
    } catch (e) {
      throw Exception('Erreur annulation: ${e.toString()}');
    }
  }

  // Vérifier disponibilité - VERSION CORRIGÉE
  Future<List<String>> getBookedSlots(String barbershopId, DateTime date) async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('time_slot')
          .eq('barbershop_id', barbershopId)
          .eq('date', date.toIso8601String().split('T')[0])
          .inFilter('status', ['confirmed', 'pending']); // Utiliser inFilter au lieu de in_

      return (response as List)
          .map((r) => r['time_slot'] as String)
          .toList();
    } catch (e) {
      print('Erreur vérification disponibilité: $e');
      throw Exception('Erreur vérification disponibilité: ${e.toString()}');
    }
  }
}
