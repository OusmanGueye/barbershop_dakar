// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../models/user_model.dart';
import '../config/supabase_config.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UploadService _uploadService = UploadService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// À appeler au démarrage (depuis Splash)
  Future<void> initialize() async {
    await loadCurrentUser();
  }

  /// Charge le profil utilisateur (à partir de l'ID auth courant)
  Future<void> loadCurrentUser() async {
    try {
      _currentUser = await _authService.getUserProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement user: $e');
    }
  }

  /// Envoi OTP via Supabase Auth (ton Hook Orange s’exécutera si activé)
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

  /// Vérifie OTP puis crée/maj le profil utilisateur si besoin
  Future<bool> verifyOTP(String phone, String otp) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      await _authService.verifyOTP(phone, otp);
      await loadCurrentUser(); // récupère UserModel

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Mise à jour du profil (DB) puis rafraîchit le cache local
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final supabase = SupabaseConfig.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        throw Exception('Utilisateur non authentifié');
      }

      data['updated_at'] = DateTime.now().toIso8601String();

      await supabase.from('users').update(data).eq('id', uid);

      await loadCurrentUser();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload avatar (stockage) puis MAJ locale ; si tu veux le persister,
  /// ajoute aussi un UPDATE DB ici.
  Future<bool> uploadAvatar() async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final avatarUrl = await _uploadService.uploadAvatar();
      if (avatarUrl != null) {
        // Option 1: MAJ locale seulement
        _currentUser = (_currentUser == null)
            ? null
            : _currentUser!.copyWith(avatarUrl: avatarUrl); // ajoute copyWith si pas déjà
        notifyListeners();

        // Option 2 (recommandée): persister aussi en DB
        await updateProfile({'avatar_url': avatarUrl});
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Déconnexion
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
