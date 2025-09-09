import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Initialiser
  Future<void> initialize() async {
    await loadCurrentUser();
  }

  // Charger l'utilisateur actuel
  Future<void> loadCurrentUser() async {
    try {
      _currentUser = await _authService.getUserProfile();
      notifyListeners();
    } catch (e) {
      print('Erreur chargement user: $e');
    }
  }

  // Envoyer OTP
  Future<bool> sendOTP(String phone) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      await _authService.sendOTP(phone);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Vérifier OTP
  Future<bool> verifyOTP(String phone, String otp) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      
      await _authService.verifyOTP(phone, otp);
      await loadCurrentUser();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Mettre à jour le profil
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await _authService.updateProfile(data);
      await loadCurrentUser();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}