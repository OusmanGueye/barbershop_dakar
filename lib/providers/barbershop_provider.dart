// lib/providers/barbershop_provider.dart

import 'package:flutter/material.dart';
import '../models/barbershop_model.dart';
import '../models/service_model.dart';
import '../services/barbershop_service.dart';
import '../config/supabase_config.dart';

class BarbershopProvider extends ChangeNotifier {
  final BarbershopService _service = BarbershopService();
  final _supabase = SupabaseConfig.supabase;

  // États existants
  List<BarbershopModel> _barbershops = [];
  List<BarbershopModel> _filteredBarbershops = [];
  BarbershopModel? _selectedBarbershop;
  List<ServiceModel> _services = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedQuartier;

  // Nouveaux états pour les barbiers
  List<Map<String, dynamic>> _barbers = [];
  bool _isLoadingBarbers = false;

  // Getters existants
  List<BarbershopModel> get barbershops =>
      _filteredBarbershops.isEmpty ? _barbershops : _filteredBarbershops;
  BarbershopModel? get selectedBarbershop => _selectedBarbershop;
  List<ServiceModel> get services => _services;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedQuartier => _selectedQuartier;

  // Nouveaux getters pour les barbiers
  List<Map<String, dynamic>> get barbers => _barbers;
  bool get isLoadingBarbers => _isLoadingBarbers;

  // Charger les barbershops
  Future<void> loadBarbershops() async {
    try {
      _setLoading(true);
      _errorMessage = null;
      _barbershops = await _service.getBarbershops();
      _filteredBarbershops = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Rechercher
  Future<void> searchBarbershops(String query) async {
    if (query.isEmpty) {
      _filteredBarbershops = [];
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _filteredBarbershops = await _service.searchBarbershops(query);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Filtrer par quartier
  void filterByQuartier(String? quartier) {
    _selectedQuartier = quartier;

    if (quartier == null) {
      _filteredBarbershops = [];
    } else {
      _filteredBarbershops = _barbershops
          .where((shop) => shop.quartier == quartier)
          .toList();
    }

    notifyListeners();
  }

  // Sélectionner un barbershop (MODIFIÉ pour charger aussi les barbiers)
  Future<void> selectBarbershop(String id) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      print('=== SÉLECTION BARBERSHOP ===');
      print('ID demandé: $id');

      // Charger le barbershop
      _selectedBarbershop = await _service.getBarbershopById(id);
      print('Barbershop chargé: ${_selectedBarbershop?.name} (ID: ${_selectedBarbershop?.id})');

      // Charger les services
      _services = await _service.getServices(id);
      print('Services chargés: ${_services.length}');

      // Charger les barbiers
      await loadBarbers(id);

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      print('Erreur selectBarbershop: $e');
    } finally {
      _setLoading(false);
    }
  }

  // NOUVELLE MÉTHODE : Charger les barbiers d'un barbershop
  Future<void> loadBarbers(String barbershopId) async {
    _isLoadingBarbers = true;
    notifyListeners();

    try {
      // Requête simplifiée sans jointure pour éviter les erreurs
      final response = await _supabase
          .from('barbers')
          .select()
          .eq('barbershop_id', barbershopId)
          .eq('invite_status', 'accepted');

      _barbers = List<Map<String, dynamic>>.from(response);

      // Pour chaque barbier, récupérer les infos user si disponible
      for (var barber in _barbers) {
        if (barber['user_id'] != null) {
          try {
            final userResponse = await _supabase
                .from('users')
                .select('full_name, avatar_url')
                .eq('id', barber['user_id'])
                .maybeSingle();

            if (userResponse != null) {
              // Enrichir avec les données user
              if (userResponse['full_name'] != null) {
                barber['display_name'] = userResponse['full_name'];
              }
              if (userResponse['avatar_url'] != null) {
                barber['photo_url'] = userResponse['avatar_url'];
              }
            }
          } catch (e) {
            print('Erreur récupération user pour barbier ${barber['id']}: $e');
          }
        }
      }

      print('Barbiers chargés: ${_barbers.length}');

    } catch (e) {
      print('Erreur loadBarbers: $e');
      _barbers = [];
    } finally {
      _isLoadingBarbers = false;
      notifyListeners();
    }
  }

  // Obtenir un barbier par ID
  Map<String, dynamic>? getBarberById(String barberId) {
    try {
      return _barbers.firstWhere((b) => b['id'] == barberId);
    } catch (e) {
      return null;
    }
  }

  // Vérifier si un barbier est disponible
  bool isBarberAvailable(String barberId) {
    final barber = getBarberById(barberId);
    return barber != null && (barber['is_available'] ?? false);
  }

  // Obtenir les barbiers disponibles
  List<Map<String, dynamic>> get availableBarbers {
    return _barbers.where((b) => b['is_available'] ?? false).toList();
  }

  // Helper pour loading
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear sélection
  void clearSelection() {
    _selectedBarbershop = null;
    _services = [];
    _barbers = [];
    notifyListeners();
  }

  // Rafraîchir les données du barbershop sélectionné
  Future<void> refreshSelectedBarbershop() async {
    if (_selectedBarbershop != null) {
      await selectBarbershop(_selectedBarbershop!.id);
    }
  }
}