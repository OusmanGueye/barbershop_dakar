import 'package:flutter/material.dart';
import '../services/barber_service.dart';
import '../config/supabase_config.dart';

class BarberProvider extends ChangeNotifier {
  final BarberService _service = BarberService();
  final _supabase = SupabaseConfig.supabase;

  // Données
  List<Map<String, dynamic>> _todayReservations = [];
  List<Map<String, dynamic>> _selectedDateReservations = [];
  List<Map<String, dynamic>> _allClients = [];
  Map<String, dynamic> _stats = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isAvailable = true;
  String? _barberId;

  // Getters
  List<Map<String, dynamic>> get todayReservations => _todayReservations;
  List<Map<String, dynamic>> get selectedDateReservations => _selectedDateReservations;
  List<Map<String, dynamic>> get allClients => _allClients;
  Map<String, dynamic> get stats => _stats;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isAvailable => _isAvailable;
  String? get barberId => _barberId;

  // AJOUT : Map pour stocker les réservations par jour (pour le calendrier)
  Map<DateTime, int> _reservationsByDay = <DateTime, int>{};

  // AJOUT : Getter pour les événements calendrier
  List<String> getReservationsCountForDay(DateTime day) {
    try {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final count = _reservationsByDay[normalizedDay] ?? 0;
      return List.generate(count, (index) => 'event');
    } catch (e) {
      print('Erreur getReservationsCountForDay: $e');
      return []; // Retourner une liste vide en cas d'erreur
    }
  }

  // Charger toutes les données
  Future<void> loadBarberData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _barberId = await _service.getBarberId();

      if (_barberId != null) {
        // Charger les données en parallèle
        await Future.wait([
          loadTodayReservations(),
          loadStats(),
          loadClients(),
        ]);
      }
    } catch (e) {
      print('Erreur loadBarberData: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger réservations du jour
  Future<void> loadTodayReservations() async {
    _todayReservations = await _service.getReservationsByDate(DateTime.now());
    notifyListeners();
  }

  // Charger réservations pour une date
  Future<void> loadReservationsByDate(DateTime date) async {
    _selectedDate = date;
    _selectedDateReservations = await _service.getReservationsByDate(date);

    // AJOUT : Stocker le count pour le calendrier
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _reservationsByDay[normalizedDate] = _selectedDateReservations.length;

    notifyListeners();
  }

  // AJOUT : Précharger plusieurs jours
  Future<void> preloadDays(List<DateTime> days) async {
    for (final day in days) {
      final reservations = await _service.getReservationsByDate(day);
      final normalizedDay = DateTime(day.year, day.month, day.day);
      _reservationsByDay[normalizedDay] = reservations.length;
    }
    notifyListeners();
  }

  // CORRECTION : Charger statistiques avec le format attendu par le dashboard
  Future<void> loadStats() async {
    print('=== DEBUG LOAD STATS COMPLET ===');
    print('Barbier ID: $_barberId');

    if (_barberId == null) {
      print('Pas de barbier ID');
      return;
    }

    // Charger les stats dashboard ET les stats complètes
    final dashboardStats = await _service.getBarberDashboardStats(_barberId!);
    final completeStats = await _service.getCompleteStats(); // AJOUT

    print('Stats dashboard: $dashboardStats');
    print('Stats complètes: $completeStats');

    // Calculer le prochain client
    String? nextClientTime = await _calculateNextClient();

    // CORRECTION : Formatter avec TOUTES les stats
    _stats = {
      // Stats dashboard (pour le dashboard principal)
      'todayRevenue': dashboardStats['todayRevenue'] ?? 0,
      'todayClients': dashboardStats['todayClients'] ?? 0,
      'monthRevenue': dashboardStats['monthRevenue'] ?? 0,
      'monthClients': dashboardStats['monthClients'] ?? 0,
      'nextClientTime': nextClientTime,

      // AJOUT : Stats complètes (pour l'écran des revenus)
      'today': completeStats['today'] ?? {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
      'week': completeStats['week'] ?? {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
      'month': completeStats['month'] ?? {'revenue': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'total': 0},
      'regularClients': completeStats['regularClients'] ?? 0,
      'averagePerDay': completeStats['averagePerDay'] ?? 0,
      'topService': completeStats['topService'] ?? 'Aucun',
    };

    print('Stats finales dans provider: $_stats');
    notifyListeners();
  }

  // AJOUT : Calculer le prochain client
  Future<String?> _calculateNextClient() async {
    if (_barberId == null) return null;

    try {
      final now = DateTime.now();
      print('=== DEBUG PROCHAIN CLIENT DÉTAILLÉ ===');
      print('Heure actuelle: ${now.hour}:${now.minute.toString().padLeft(2, '0')} (${now})');
      print('Date recherchée: ${now.toIso8601String().split('T')[0]}');

      // D'abord, récupérer TOUTES les réservations d'aujourd'hui pour debug
      final allToday = await _supabase
          .from('reservations')
          .select('date, time_slot, status')
          .eq('barber_id', _barberId!)
          .eq('date', now.toIso8601String().split('T')[0]);

      print('TOUTES les réservations d\'aujourd\'hui: ${allToday.length}');
      for (var res in allToday) {
        print('  - ${res['time_slot']} (${res['status']})');
      }

      // Maintenant, chercher avec la requête normale
      final response = await _supabase
          .from('reservations')
          .select('date, time_slot, status')
          .eq('barber_id', _barberId!)
          .or('status.eq.pending,status.eq.confirmed')
          .eq('date', now.toIso8601String().split('T')[0])
          .order('time_slot', ascending: true);

      print('Réservations pending/confirmed aujourd\'hui: ${response.length}');

      for (var reservation in response) {
        final timeSlot = reservation['time_slot'] as String;
        final status = reservation['status'] as String;
        print('Vérification: ${timeSlot} (${status})');

        // Parser l'heure
        final timeParts = timeSlot.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final reservationTime = DateTime(
            now.year, now.month, now.day, hour, minute
        );

        print('  Heure réservation: ${hour}:${minute.toString().padLeft(2, '0')} → $reservationTime');
        print('  Est après maintenant? ${reservationTime.isAfter(now)}');

        if (reservationTime.isAfter(now)) {
          final result = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          print('✅ Prochain client trouvé: $result');
          return result;
        } else {
          print('  ❌ Réservation passée');
        }
      }

      print('❌ Aucun prochain client trouvé');
      return null;

    } catch (e) {
      print('Erreur calcul prochain client: $e');
      return null;
    }
  }

  // Charger clients
  Future<void> loadClients() async {
    _allClients = await _service.getAllClients();
    notifyListeners();
  }

  // Marquer comme terminé
  Future<bool> completeReservation(String reservationId) async {
    try {
      await _service.updateReservationStatus(reservationId, 'completed');
      await loadBarberData();
      return true;
    } catch (e) {
      print('Erreur completeReservation: $e');
      return false;
    }
  }

  // Marquer absent
  Future<bool> markNoShow(String reservationId) async {
    try {
      await _service.updateReservationStatus(reservationId, 'no_show');
      await loadBarberData();
      return true;
    } catch (e) {
      print('Erreur markNoShow: $e');
      return false;
    }
  }

  // Commencer service
  Future<bool> startService(String reservationId) async {
    try {
      await _service.updateReservationStatus(reservationId, 'in_progress');
      await loadBarberData();
      return true;
    } catch (e) {
      print('Erreur startService: $e');
      return false;
    }
  }



  // Changer disponibilité
  Future<void> toggleAvailability() async {
    if (_barberId == null) return;

    _isAvailable = !_isAvailable;
    await _service.updateAvailability(_barberId!, _isAvailable);
    notifyListeners();
  }
}