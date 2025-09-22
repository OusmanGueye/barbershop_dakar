import '../config/supabase_config.dart';

class BarberService {
  final _supabase = SupabaseConfig.supabase;

  // Obtenir l'ID du barbier
  Future<String?> getBarberId() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('barbers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      print('Erreur getBarberId: $e');
      return null;
    }
  }

  // Réservations pour une date donnée
  Future<List<Map<String, dynamic>>> getReservationsByDate(DateTime date) async {
    try {
      final barberId = await getBarberId();
      if (barberId == null) return [];

      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('reservations')
          .select('''
            *,
            client:users!client_id(*),
            service:services(*)
          ''')
          .eq('barber_id', barberId)
          .eq('date', dateStr)
          .order('time_slot', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getReservationsByDate: $e');
      return [];
    }
  }

  // Stats complètes
  Future<Map<String, dynamic>> getCompleteStats() async {
    try {
      final barberId = await getBarberId();
      if (barberId == null) {
        return {
          'today': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
          'week': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
          'month': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
          'regularClients': 0,
          'averagePerDay': 0,
          'topService': 'Aucun',
        };
      }

      final now = DateTime.now();

      // Stats jour
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Stats semaine
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      // Stats mois
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      // Requêtes
      final todayRes = await _getStatsForPeriod(barberId, todayStart, todayEnd);
      final weekRes = await _getStatsForPeriod(barberId, weekStart, weekEnd);
      final monthRes = await _getStatsForPeriod(barberId, monthStart, monthEnd);

      // CORRECTION : Clients réguliers - requête simplifiée
      int regularCount = 0;
      try {
        // Récupérer toutes les réservations complétées pour ce barbier
        final regularClients = await _supabase
            .from('reservations')
            .select('client_id')  // Enlever 'count' qui n'existe pas
            .eq('barber_id', barberId)
            .eq('status', 'completed');

        // Compter les visites par client
        final clientVisits = <String, int>{};
        for (var res in (regularClients as List)) {
          final clientId = res['client_id'] as String;
          clientVisits[clientId] = (clientVisits[clientId] ?? 0) + 1;
        }
        regularCount = clientVisits.values.where((v) => v >= 3).length;
      } catch (e) {
        print('Erreur calcul clients réguliers: $e');
      }

      return {
        'today': todayRes,
        'week': weekRes,
        'month': monthRes,
        'regularClients': regularCount,
        'averagePerDay': monthRes['total'] > 0 ? monthRes['revenue'] ~/ 30 : 0,
        'topService': await _getTopService(barberId),
      };
    } catch (e) {
      print('Erreur getCompleteStats: $e');
      return {
        'today': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
        'week': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
        'month': {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
        'regularClients': 0,
        'averagePerDay': 0,
        'topService': 'Aucun',
      };
    }
  }

  // Stats pour une période
  Future<Map<String, dynamic>> _getStatsForPeriod(
      String barberId,
      DateTime start,
      DateTime end,
      ) async {
    final response = await _supabase
        .from('reservations')
        .select('total_amount, status')
        .eq('barber_id', barberId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lt('date', end.toIso8601String().split('T')[0]);

    int revenue = 0;
    int completed = 0;
    int cancelled = 0;
    int noShow = 0;

    for (var res in (response as List)) {
      switch (res['status']) {
        case 'completed':
          completed++;
          revenue += (res['total_amount'] as num).toInt();
          break;
        case 'cancelled':
          cancelled++;
          break;
        case 'no_show':
          noShow++;
          break;
      }
    }

    // Retourner explicitement Map<String, dynamic>
    return <String, dynamic>{
      'revenue': revenue,
      'completed': completed,
      'cancelled': cancelled,
      'noShow': noShow,
      'total': response.length,
    };
  }

  // Service le plus demandé
  Future<String> _getTopService(String barberId) async {
    final response = await _supabase
        .from('reservations')
        .select('service:services(name)')
        .eq('barber_id', barberId)
        .eq('status', 'completed')
        .limit(100);

    final serviceCounts = <String, int>{};
    for (var res in (response as List)) {
      final serviceName = res['service']?['name'] ?? 'Service';
      serviceCounts[serviceName] = (serviceCounts[serviceName] ?? 0) + 1;
    }

    if (serviceCounts.isEmpty) return 'Aucun';

    return serviceCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }


  // Dans barber_service.dart
  Future<double> getCommissionRate() async {
    try {
      final barberId = await getBarberId();
      if (barberId == null) return 70.0; // Défaut 70%

      final response = await _supabase
          .from('barbers')
          .select('commission_rate')
          .eq('id', barberId)
          .maybeSingle();

      return (response?['commission_rate'] as num?)?.toDouble() ?? 70.0;
    } catch (e) {
      print('Erreur getCommissionRate: $e');
      return 70.0;
    }
  }


  // Clients du barbier
  Future<List<Map<String, dynamic>>> getAllClients() async {
    try {
      final barberId = await getBarberId();
      print('=== DEBUG getAllClients (contournement policies) ===');
      print('Barbier ID: $barberId');

      if (barberId == null) {
        print('Pas de barbier ID trouvé');
        return [];
      }

      // ÉTAPE 1: Récupérer les client_id depuis les réservations
      final response = await _supabase
          .from('reservations')
          .select('client_id, created_at')
          .eq('barber_id', barberId)
          .order('created_at', ascending: false);

      print('Réservations trouvées: ${response.length}');

      if (response.isEmpty) {
        return [];
      }

      // ÉTAPE 2: Extraire les IDs uniques et compter les visites
      final clientIds = <String>{};
      final clientVisits = <String, int>{};

      for (var res in (response as List)) {
        final clientId = res['client_id'] as String?;
        if (clientId != null) {
          clientIds.add(clientId);
          clientVisits[clientId] = (clientVisits[clientId] ?? 0) + 1;
        }
      }

      print('Client IDs uniques: ${clientIds.length}');

      if (clientIds.isEmpty) {
        return [];
      }

      // ÉTAPE 3: Récupérer les données des clients
      final clientsData = await _supabase
          .from('users')
          .select('id, full_name, phone, avatar_url, preferred_language, created_at')
          .filter('id', 'in', '(${clientIds.join(',')})');

      print('Données clients récupérées: ${clientsData.length}');

      // ÉTAPE 4: Combiner avec le nombre de visites
      final clientsList = (clientsData as List).map((client) {
        final clientData = Map<String, dynamic>.from(client);
        clientData['visits'] = clientVisits[client['id']] ?? 0;
        return clientData;
      }).toList();

      // Trier par nombre de visites
      clientsList.sort((a, b) => (b['visits'] as int).compareTo(a['visits'] as int));

      print('Liste finale: ${clientsList.length} clients');
      for (var client in clientsList.take(3)) {
        print('  ${client['full_name']}: ${client['visits']} visites');
      }

      return clientsList;

    } catch (e) {
      print('Erreur getAllClients: $e');
      return [];
    }
  }
  // Mettre à jour la disponibilité
  Future<bool> updateAvailability(String barberId, bool isAvailable) async {
    try {
      await _supabase
          .from('barbers')
          .update({'is_available': isAvailable})
          .eq('id', barberId);

      return true;
    } catch (e) {
      print('Erreur updateAvailability: $e');
      return false;
    }
  }

  // Vérifier le code d'invitation - VERSION CORRIGÉE
  Future<Map<String, dynamic>?> verifyInviteCode(String phone, String code) async {
    try {
      print('=== VÉRIFICATION CODE BARBIER ===');
      print('Phone reçu: $phone');
      print('Code reçu: $code');

      // Nettoyer les entrées
      String formattedPhone = phone.trim();
      if (!formattedPhone.startsWith('221')) {
        formattedPhone = '221$formattedPhone';
      }
      String formattedCode = code.trim().toUpperCase();

      print('Phone formaté: $formattedPhone');
      print('Code formaté: $formattedCode');

      // Test 1: Récupérer TOUS les barbiers (sans spécifier de colonnes problématiques)
      print('\n1. Test lecture simple...');
      try {
        final allBarbers = await _supabase
            .from('barbers')
            .select(); // Sans spécifier de colonnes

        print('Nombre de barbiers trouvés: ${allBarbers.length}');
        if (allBarbers.isNotEmpty) {
          print('Structure d\'un barbier: ${allBarbers[0].keys.toList()}');

          // Afficher les barbiers avec invite_status = pending
          for (var b in allBarbers) {
            if (b['invite_status'] == 'pending') {
              print('Barbier pending:');
              print('  - display_name: ${b['display_name']}');
              print('  - phone: ${b['phone']}');
              print('  - invite_code: ${b['invite_code']}');
              print('  - invite_status: ${b['invite_status']}');
            }
          }
        }
      } catch (e) {
        print('Erreur lecture barbiers: $e');
      }

      // Test 2: Recherche avec les critères exacts
      print('\n2. Recherche avec critères exacts...');
      try {
        final response = await _supabase
            .from('barbers')
            .select()
            .eq('phone', formattedPhone)
            .eq('invite_code', formattedCode)
            .eq('invite_status', 'pending')
            .maybeSingle();

        if (response != null) {
          print('✅ Barbier trouvé!');
          print('ID: ${response['id']}');
          print('Display Name: ${response['display_name']}');
          return response;
        } else {
          print('❌ Aucun barbier avec ces critères exacts');
        }
      } catch (e) {
        print('Erreur recherche exacte: $e');
      }

      // Test 3: Recherche par code seulement pour debug
      print('\n3. Recherche par code uniquement...');
      try {
        final byCode = await _supabase
            .from('barbers')
            .select()
            .eq('invite_code', formattedCode);

        if (byCode.isNotEmpty) {
          print('Barbier(s) avec ce code:');
          for (var b in byCode) {
            print('  - Phone: ${b['phone']}, Status: ${b['invite_status']}');
          }

          // Vérifier pourquoi ça ne matche pas
          final first = byCode[0];
          if (first['phone'] != formattedPhone) {
            throw Exception('Le numéro de téléphone ne correspond pas à ce code.');
          }
          if (first['invite_status'] != 'pending') {
            throw Exception('Ce code a déjà été utilisé (status: ${first['invite_status']}).');
          }
        } else {
          throw Exception('Code d\'invitation invalide.');
        }
      } catch (e) {
        print('Erreur recherche par code: $e');
        rethrow;
      }

      return null;

    } catch (e) {
      print('❌ Erreur verifyInviteCode: $e');
      rethrow;
    }
  }

  // Lier un barbier à un utilisateur
  Future<bool> linkBarberToUser(String barberId, String userId) async {
    try {
      await _supabase
          .from('barbers')
          .update({
        'user_id': userId,
        'invite_status': 'accepted',
      })
          .eq('id', barberId);

      return true;
    } catch (e) {
      print('Erreur linkBarberToUser: $e');
      return false;
    }
  }

  // Obtenir le barbier par user_id
  Future<Map<String, dynamic>?> getBarberByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('barbers')
          .select('*, barbershop:barbershops(*)')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Erreur getBarberByUserId: $e');
      return null;
    }
  }

  // Dashboard stats barbier
  Future<Map<String, dynamic>> getBarberDashboardStats(String barberId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final todayStr = now.toIso8601String().split('T')[0];

      print('=== DEBUG STATS DASHBOARD ===');
      print('Barbier ID: $barberId');
      print('Date du jour: $todayStr');

      // Stats du jour - TOUTES les réservations
      final todayReservations = await _supabase
          .from('reservations')
          .select('total_amount, status')
          .eq('barber_id', barberId)
          .eq('date', todayStr);

      print('Réservations du jour: ${todayReservations.length}');

      // Stats du mois - TOUTES les réservations
      final monthReservations = await _supabase
          .from('reservations')
          .select('total_amount, status')
          .eq('barber_id', barberId)
          .gte('date', startOfMonth.toIso8601String().split('T')[0]);

      print('Réservations du mois: ${monthReservations.length}');

      int todayRevenue = 0;
      int todayClients = 0;
      int monthRevenue = 0;
      int monthClients = 0;

      // CORRECTION : Compter TOUS les statuts, pas seulement 'completed'
      for (var res in (todayReservations as List)) {
        final status = res['status'] as String;
        print('Réservation jour - Status: $status, Montant: ${res['total_amount']}');

        if (status == 'completed') {
          todayRevenue += (res['total_amount'] as num? ?? 0).toInt();
        }
        // Compter TOUS les clients (sauf annulés)
        if (status != 'cancelled') {
          todayClients++;
        }
      }

      for (var res in (monthReservations as List)) {
        final status = res['status'] as String;

        if (status == 'completed') {
          monthRevenue += (res['total_amount'] as num? ?? 0).toInt();
        }
        // Compter TOUS les clients (sauf annulés)
        if (status != 'cancelled') {
          monthClients++;
        }
      }

      // Récupérer le taux de commission
      final commissionRate = await getCommissionRate();

      // Calculer la commission
      final todayCommission = (todayRevenue * commissionRate / 100).round();
      final monthCommission = (monthRevenue * commissionRate / 100).round();

      final result = {
        'todayRevenue': todayCommission,        // Revenus bruts
        'todayCommission': todayCommission,  // Sa part
        'monthRevenue': monthCommission,        // Revenus bruts
        'monthCommission': monthCommission,  // Sa part
        'todayClients': todayClients,
        'monthClients': monthClients,
        'commissionRate': commissionRate,
      };

      print('Stats calculées: $result');
      return result;

    } catch (e) {
      print('Erreur getBarberDashboardStats: $e');
      return {
        'todayRevenue': 0,
        'todayClients': 0,
        'monthRevenue': 0,
        'monthClients': 0,
      };
    }
  }

  // Obtenir les réservations du barbier
  Future<List<Map<String, dynamic>>> getBarberReservations(String barberId) async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('''
            *,
            client:users!client_id(*),
            service:services(*)
          ''')
          .eq('barber_id', barberId)
          .order('date', ascending: false)
          .order('time_slot', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getBarberReservations: $e');
      return [];
    }
  }

  // Mettre à jour le statut d'une réservation
  Future<bool> updateReservationStatus(String reservationId, String status) async {
    try {
      await _supabase
          .from('reservations')
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', reservationId);

      return true;
    } catch (e) {
      print('Erreur updateReservationStatus: $e');
      return false;
    }
  }

  // Obtenir les infos du barbier connecté
  Future<Map<String, dynamic>?> getCurrentBarberInfo() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('barbers')
          .select('''
            *,
            barbershop:barbershops(*)
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Erreur getCurrentBarberInfo: $e');
      return null;
    }
  }
}