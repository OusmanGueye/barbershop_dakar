// lib/providers/owner_provider.dart

import 'dart:math';

import 'package:flutter/material.dart';
import '../services/owner_service.dart';

class OwnerProvider extends ChangeNotifier {
  final OwnerService _service = OwnerService();

  // Données
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _barbershopInfo;
  Map<String, dynamic> _analytics = {};
  bool _isLoading = false;
  String? _barbershopId;
  String? _errorMessage;

  // Getters
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get barbers => _barbers;
  List<Map<String, dynamic>> get services => _services;
  Map<String, dynamic>? get barbershopInfo => _barbershopInfo;
  Map<String, dynamic> get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Charger toutes les données
  Future<void> loadOwnerData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _barbershopId = await _service.getOwnerBarbershopId();

      if (_barbershopId != null) {
        await Future.wait([
          loadDashboardStats(),
          loadBarbers(),
          loadServices(),
          loadBarbershopInfo(),
        ]);
      }
    } catch (e) {
      print('Erreur loadOwnerData: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger stats dashboard
  Future<void> loadDashboardStats() async {
    _dashboardStats = await _service.getDashboardStats();
    notifyListeners();
  }

  // Charger barbiers
  Future<void> loadBarbers() async {
    _barbers = await _service.getBarbers();
    notifyListeners();
  }

  // Charger services
  Future<void> loadServices() async {
    _services = await _service.getServices();
    notifyListeners();
  }

  // Charger infos barbershop
  Future<void> loadBarbershopInfo() async {
    _barbershopInfo = await _service.getBarbershopInfo();
    notifyListeners();
  }

  // Charger analytics
  Future<void> loadAnalytics() async {
    _analytics = await _service.getDetailedAnalytics();
    notifyListeners();
  }

  // Ajouter barbier
  Future<bool> addBarber(Map<String, dynamic> barberData) async {
    try {
      _errorMessage = null;
      final success = await _service.addBarber(barberData);
      if (success) await loadBarbers();
      return success;
    } catch (e) {
      print('Erreur addBarber: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  // Mettre à jour barbier
  Future<bool> updateBarber(String barberId, Map<String, dynamic> updates) async {
    try {
      final success = await _service.updateBarber(barberId, updates);
      if (success) await loadBarbers();
      return success;
    } catch (e) {
      print('Erreur updateBarber: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  // Supprimer barbier
  Future<bool> deleteBarber(String barberId) async {
    try {
      final success = await _service.deleteBarber(barberId);
      if (success) await loadBarbers();
      return success;
    } catch (e) {
      print('Erreur deleteBarber: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  // Ajouter service
  Future<bool> addService(Map<String, dynamic> serviceData) async {
    final success = await _service.addService(serviceData);
    if (success) await loadServices();
    return success;
  }

  // Mettre à jour service
  Future<bool> updateService(String serviceId, Map<String, dynamic> updates) async {
    final success = await _service.updateService(serviceId, updates);
    if (success) await loadServices();
    return success;
  }

  // Supprimer service
  Future<bool> deleteService(String serviceId) async {
    final success = await _service.deleteService(serviceId);
    if (success) await loadServices();
    return success;
  }

  // Mettre à jour infos barbershop
  Future<bool> updateBarbershopInfo(Map<String, dynamic> updates) async {
    final success = await _service.updateBarbershopInfo(updates);
    if (success) await loadBarbershopInfo();
    return success;
  }

  // Récupérer l'ID du barbershop du owner
  Future<String?> _getOwnerBarbershopId() async {
    return await _service.getOwnerBarbershopId();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> addBarberWithInvite(Map<String, dynamic> barberData) async {
    try {
      _errorMessage = null;

      // Générer un code d'invitation si pas fourni
      if (barberData['invite_code'] == null) {
        barberData['invite_code'] = _generateInviteCode();
      }

      final success = await _service.addBarber(barberData);
      if (success) await loadBarbers();
      return success;
    } catch (e) {
      print('Erreur addBarberWithInvite: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }


  // Ajouter ces propriétés et méthodes dans OwnerProvider

  List<Map<String, dynamic>> _commissionPayments = [];
  List<Map<String, dynamic>> get commissionPayments => _commissionPayments;

// Charger l'historique des paiements
  Future<void> loadCommissionPayments(String month) async {
    _isLoading = true;
    notifyListeners();

    try {
      _commissionPayments = await _service.getCommissionPayments(month);
    } catch (e) {
      print('Error loading commission payments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Générer les commissions du mois
  Future<bool> generateMonthlyCommissions(String month) async {
    try {
      final success = await _service.generateMonthlyCommissions(month);
      if (success) {
        await loadCommissionPayments(month);
      }
      return success;
    } catch (e) {
      print('Error generating commissions: $e');
      return false;
    }
  }

// Marquer comme payé
  Future<bool> markCommissionAsPaid(
      String barberId,
      String month,
      String paymentMethod, [
        String? reference,
      ]) async {
    try {
      final success = await _service.markCommissionAsPaid(
        barberId,
        month,
        paymentMethod,
        reference,
      );

      if (success) {
        await loadCommissionPayments(month);
      }
      return success;
    } catch (e) {
      print('Error marking as paid: $e');
      return false;
    }
  }


}