import '../config/supabase_config.dart';

class OwnerService {
  final _supabase = SupabaseConfig.client;

  // Obtenir le barbershop du propriétaire
  Future<String?> getOwnerBarbershopId() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) return null;

      final response = await _supabase
          .from('barbershops')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      print('Erreur getOwnerBarbershopId: $e');
      return null;
    }
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) {
        print('❌ Pas de barbershop trouvé pour ce owner');
        return {};
      }

      print('=== DEBUG OWNER STATS ===');
      print('Barbershop ID: $barbershopId');

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final todayStr = now.toIso8601String().split('T')[0];

      // Stats du jour avec debug
      final todayReservations = await _supabase
          .from('reservations')
          .select('total_amount, status')
          .eq('barbershop_id', barbershopId)
          .eq('date', todayStr);

      print('Réservations aujourd\'hui: ${todayReservations.length}');

      // Stats du mois
      final monthReservations = await _supabase
          .from('reservations')
          .select('total_amount, status')
          .eq('barbershop_id', barbershopId)
          .gte('date', startOfMonth.toIso8601String().split('T')[0]);

      print('Réservations du mois: ${monthReservations.length}');

      // Barbiers
      final barbers = await _supabase
          .from('barbers')
          .select('id, is_available')
          .eq('barbershop_id', barbershopId);

      print('Barbiers trouvés: ${(barbers as List).length}');

      // CORRECTION : Compter TOUS les revenus, pas seulement completed
      int todayRevenue = 0;
      int todayClients = 0;
      int monthRevenue = 0;
      int monthClients = 0;
      int cancelledToday = 0;

      for (var res in (todayReservations as List)) {
        final status = res['status'] as String;
        final amount = (res['total_amount'] as num?)?.toInt() ?? 0;

        // Inclure confirmed et in_progress pour les revenus
        if (status == 'completed' || status == 'confirmed' || status == 'in_progress') {
          todayRevenue += amount;
          todayClients++;
        } else if (status == 'cancelled') {
          cancelledToday++;
        }
      }

      for (var res in (monthReservations as List)) {
        final status = res['status'] as String;
        final amount = (res['total_amount'] as num?)?.toInt() ?? 0;

        if (status == 'completed' || status == 'confirmed' || status == 'in_progress') {
          monthRevenue += amount;
          monthClients++;
        }
      }

      final activeBarbers = (barbers as List).where((b) => b['is_available'] == true).length;
      final totalBarbers = barbers.length;

      // Taux d'occupation plus réaliste
      final totalSlots = 10 * totalBarbers;
      final occupancyRate = totalSlots > 0 ? (todayClients / totalSlots * 100).round() : 0;

      final stats = {
        'todayRevenue': todayRevenue,
        'todayClients': todayClients,
        'monthRevenue': monthRevenue,
        'monthClients': monthClients,
        'activeBarbers': activeBarbers,
        'totalBarbers': totalBarbers,
        'occupancyRate': occupancyRate,
        'cancelledToday': cancelledToday,
        'averageTicket': monthClients > 0 ? monthRevenue ~/ monthClients : 0,
      };

      print('Stats calculées: $stats');
      return stats;

    } catch (e) {
      print('❌ Erreur getDashboardStats: $e');
      return {};
    }
  }

  // Obtenir tous les barbiers
  Future<List<Map<String, dynamic>>> getBarbers() async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return [];

      // Charger les barbiers sans le join
      final response = await _supabase
          .from('barbers')
          .select()
          .eq('barbershop_id', barbershopId)
          .order('created_at', ascending: false);

      // Ajouter les stats et avatars pour chaque barbier
      final barbersWithData = <Map<String, dynamic>>[];

      for (var barber in response) {
        final barberData = Map<String, dynamic>.from(barber);

        // Charger l'avatar depuis users
        final userId = barber['user_id'];
        if (userId != null) {
          try {
            final userResponse = await _supabase
                .from('users')
                .select('avatar_url, full_name')
                .eq('id', userId)
                .maybeSingle();

            if (userResponse != null) {
              barberData['avatar_url'] = userResponse['avatar_url'];
              // Optionnel : mettre à jour le nom si nécessaire
              if (userResponse['full_name'] != null && barberData['display_name'] == null) {
                barberData['display_name'] = userResponse['full_name'];
              }
            }
          } catch (e) {
            print('Erreur chargement avatar pour user_id $userId: $e');
          }
        }

        // Charger les stats
        final barberStats = await getBarberStats(barber['id']);
        barberData['stats'] = barberStats;

        barbersWithData.add(barberData);
      }

      return barbersWithData;
    } catch (e) {
      print('Erreur getBarbers: $e');
      return [];
    }
  }

  // Stats d'un barbier
  Future<Map<String, dynamic>> getBarberStats(String barberId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final response = await _supabase
          .from('reservations')
          .select('total_amount, status')
          .eq('barber_id', barberId)
          .gte('date', startOfMonth.toIso8601String().split('T')[0]);

      int revenue = 0;
      int clients = 0;

      for (var res in (response as List)) {
        if (res['status'] == 'completed') {
          revenue += (res['total_amount'] as num).toInt();
          clients++;
        }
      }

      return {
        'monthRevenue': revenue,
        'monthClients': clients,
      };
    } catch (e) {
      return {'monthRevenue': 0, 'monthClients': 0};
    }
  }

  // Obtenir tous les services
  Future<List<Map<String, dynamic>>> getServices() async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return [];

      final response = await _supabase
          .from('services')
          .select()
          .eq('barbershop_id', barbershopId)
          .order('category', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getServices: $e');
      return [];
    }
  }

  // Ajouter un barbier
  Future<bool> addBarber(Map<String, dynamic> barberData) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      await _supabase.from('barbers').insert({
        ...barberData,
        'barbershop_id': barbershopId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Erreur addBarber: $e');
      return false;
    }
  }

  // Mettre à jour un barbier
  Future<bool> updateBarber(String barberId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('barbers')
          .update(updates)
          .eq('id', barberId);

      return true;
    } catch (e) {
      print('Erreur updateBarber: $e');
      return false;
    }
  }

  // Supprimer un barbier
  Future<bool> deleteBarber(String barberId) async {
    try {
      await _supabase
          .from('barbers')
          .delete()
          .eq('id', barberId);

      return true;
    } catch (e) {
      print('Erreur deleteBarber: $e');
      return false;
    }
  }

  // Ajouter un service
  Future<bool> addService(Map<String, dynamic> serviceData) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      await _supabase.from('services').insert({
        ...serviceData,
        'barbershop_id': barbershopId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Erreur addService: $e');
      return false;
    }
  }

  // Mettre à jour un service
  Future<bool> updateService(String serviceId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('services')
          .update(updates)
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Erreur updateService: $e');
      return false;
    }
  }

  // Supprimer un service
  Future<bool> deleteService(String serviceId) async {
    try {
      await _supabase
          .from('services')
          .delete()
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Erreur deleteService: $e');
      return false;
    }
  }

  // Obtenir les infos du barbershop
  Future<Map<String, dynamic>?> getBarbershopInfo() async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return null;

      final response = await _supabase
          .from('barbershops')
          .select()
          .eq('id', barbershopId)
          .single();

      return response;
    } catch (e) {
      print('Erreur getBarbershopInfo: $e');
      return null;
    }
  }

  // Mettre à jour les infos du barbershop
  Future<bool> updateBarbershopInfo(Map<String, dynamic> updates) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      await _supabase
          .from('barbershops')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', barbershopId);

      return true;
    } catch (e) {
      print('Erreur updateBarbershopInfo: $e');
      return false;
    }
  }

  // Analytics détaillées
  Future<Map<String, dynamic>> getDetailedAnalytics() async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return {};

      final now = DateTime.now();

      // Revenue par jour sur 7 jours
      final revenueByDay = <String, int>{};
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        final dayRevenue = await _supabase
            .from('reservations')
            .select('total_amount')
            .eq('barbershop_id', barbershopId)
            .eq('date', dateStr)
            .eq('status', 'completed');

        int total = 0;
        for (var res in (dayRevenue as List)) {
          total += (res['total_amount'] as num).toInt();
        }

        revenueByDay[dateStr] = total;
      }

      // Services populaires
      final services = await _supabase
          .from('reservations')
          .select('service:services(name)')
          .eq('barbershop_id', barbershopId)
          .eq('status', 'completed')
          .limit(100);

      final serviceCounts = <String, int>{};
      for (var res in (services as List)) {
        final serviceName = res['service']?['name'] ?? 'Service';
        serviceCounts[serviceName] = (serviceCounts[serviceName] ?? 0) + 1;
      }

      // Trier les services par popularité
      final sortedServices = serviceCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'revenueByDay': revenueByDay,
        'topServices': sortedServices.take(5).map((e) => {
          'name': e.key,
          'count': e.value,
        }).toList(),
      };
    } catch (e) {
      print('Erreur getDetailedAnalytics: $e');
      return {};
    }
  }




  // Ajouter ces méthodes dans OwnerService

// Récupérer l'historique des paiements
  Future<List<Map<String, dynamic>>> getCommissionPayments(String month) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) throw Exception('No barbershop found');

      final response = await _supabase
          .from('commission_payments')
          .select('*, barber:barbers(*)')
          .eq('barbershop_id', barbershopId)
          .eq('month', month)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('Error fetching commission payments: $e');
      return [];
    }
  }

// Créer ou mettre à jour un paiement
  Future<bool> upsertCommissionPayment(Map<String, dynamic> data) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      data['barbershop_id'] = barbershopId;

      await _supabase
          .from('commission_payments')
          .upsert(data, onConflict: 'barber_id,barbershop_id,month');

      return true;
    } catch (e) {
      print('Error upserting commission payment: $e');
      return false;
    }
  }

// Marquer comme payé
  Future<bool> markCommissionAsPaid(
      String barberId,
      String month,
      String paymentMethod,
      String? reference,
      ) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      await _supabase
          .from('commission_payments')
          .update({
        'is_paid': true,
        'paid_at': DateTime.now().toIso8601String(),
        'payment_method': paymentMethod,
        'payment_reference': reference,
      })
          .eq('barbershop_id', barbershopId)
          .eq('barber_id', barberId)
          .eq('month', month);

      return true;
    } catch (e) {
      print('Error marking commission as paid: $e');
      return false;
    }
  }

// Générer les commissions du mois
  Future<bool> generateMonthlyCommissions(String month) async {
    try {
      final barbershopId = await getOwnerBarbershopId();
      if (barbershopId == null) return false;

      // Récupérer tous les barbiers avec leurs stats
      final barbers = await getBarbers();

      for (var barber in barbers) {
        final stats = barber['stats'] ?? {};
        final revenue = stats['monthRevenue'] ?? 0;
        final clients = stats['monthClients'] ?? 0;
        final rate = barber['commission_rate'] ?? 30;
        final commission = (revenue * rate / 100).round();

        await upsertCommissionPayment({
          'barber_id': barber['id'],
          'month': month,
          'revenue': revenue,
          'commission_rate': rate,
          'commission_amount': commission,
          'clients_count': clients,
          'is_paid': false,
        });
      }

      return true;
    } catch (e) {
      print('Error generating monthly commissions: $e');
      return false;
    }
  }








}
