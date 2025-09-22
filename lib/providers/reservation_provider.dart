import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../services/notification_service.dart';
import '../services/reservation_service.dart';
import '../config/supabase_config.dart';
import 'package:intl/intl.dart';

class ReservationProvider extends ChangeNotifier {
  final ReservationService _service = ReservationService();

  List<ReservationModel> _reservations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReservationModel> get reservations => _reservations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Créer une réservation avec calcul automatique de end_time
  Future<bool> createReservation({
    required String barbershopId,
    required String barberId,
    required String serviceId,
    required DateTime date,
    required String timeSlot,
    required int totalAmount,
    required int serviceDuration, // AJOUT pour calculer end_time
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Calculer l'heure de fin basée sur la durée du service
      final startTime = DateTime.parse('${date.toIso8601String().split('T')[0]} $timeSlot:00');
      final endTime = startTime.add(Duration(minutes: serviceDuration));
      final endTimeFormatted = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      final data = {
        'client_id': userId,
        'barbershop_id': barbershopId,
        'barber_id': barberId,
        'service_id': serviceId,
        'date': date.toIso8601String().split('T')[0],
        'time_slot': '$timeSlot:00', // Normaliser le format
        'end_time': endTimeFormatted, // AJOUT calculé automatiquement
        'status': 'confirmed',
        'payment_method': 'cash',
        'payment_status': 'pending',
        'total_amount': totalAmount,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _service.createReservation(data);

      // Obtenir les infos pour la notification
      final barbershop = await _getBarbershopInfo(barbershopId);
      final service = await _getServiceInfo(serviceId);
      final barber = await _getBarberInfo(barberId);

      // Notification de confirmation immédiate avec durée
      await NotificationService.showReservationConfirmation(
        barbershopName: barbershop['name'] ?? 'Barbershop',
        service: '${service['name']} (${serviceDuration}min)', // AJOUT durée
        date: DateFormat('EEEE d MMMM', 'fr').format(date),
        time: '$timeSlot - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}', // AJOUT heure fin
        reservationId: response.id,
      );

      // Programmer les rappels
      final dateTimeStr = '${date.toIso8601String().split('T')[0]} $timeSlot:00';
      final dateTime = DateTime.parse(dateTimeStr);

      await NotificationService.scheduleClientReminders(
        reservationId: response.id,
        barbershopName: barbershop['name'] ?? 'Barbershop',
        service: service['name'] ?? 'Service',
        dateTime: dateTime,
      );

      // Notifier le barbier
      await NotificationService.showNewReservationForBarber(
        clientName: SupabaseConfig.currentUser?.userMetadata?['full_name'] ?? 'Client',
        service: '${service['name']} (${serviceDuration}min)',
        time: '$timeSlot - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        date: DateFormat('d MMMM', 'fr').format(date),
        reservationId: response.id,
      );

      await loadReservations();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reste du code inchangé...
  Future<void> loadReservations() async {
    try {
      _setLoading(true);
      _errorMessage = null;
      _reservations = await _service.getMyReservations();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      print('Erreur chargement réservations: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelReservation(String reservationId) async {
    try {
      _setLoading(true);
      await _service.cancelReservation(reservationId);
      await NotificationService.cancelNotification(reservationId);
      await loadReservations();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> _getBarbershopInfo(String id) async {
    final response = await SupabaseConfig.supabase
        .from('barbershops')
        .select()
        .eq('id', id)
        .single();
    return response;
  }

  Future<Map<String, dynamic>> _getServiceInfo(String id) async {
    final response = await SupabaseConfig.supabase
        .from('services')
        .select()
        .eq('id', id)
        .single();
    return response;
  }

  Future<Map<String, dynamic>> _getBarberInfo(String id) async {
    final response = await SupabaseConfig.supabase
        .from('barbers')
        .select()
        .eq('id', id)
        .single();
    return response;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}