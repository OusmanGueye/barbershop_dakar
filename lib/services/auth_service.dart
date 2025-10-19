// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  // ✅ utilise le client unique
  final SupabaseClient _supabase = SupabaseConfig.client;

  // -------- OTP --------

  // Envoi OTP via Supabase Auth (ton Hook Orange s’exécute côté serveur si activé)
  Future<void> sendOTP(String phone) async {
    try {
      // normaliser en E.164 Sénégal
      String formatted = phone.trim();
      if (!formatted.startsWith('+')) {
        formatted = '+221$formatted';
      }

      await _supabase.auth.signInWithOtp(phone: formatted);
    } on AuthException catch (e) {
      throw Exception('Auth error (sendOTP): ${e.message}');
    } catch (e) {
      throw Exception('Erreur envoi SMS: $e');
    }
  }

  // Vérifier OTP
  Future<AuthResponse> verifyOTP(String phone, String otp) async {
    try {
      String formatted = phone.trim();
      if (!formatted.startsWith('+')) {
        formatted = '+221$formatted';
      }

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: formatted,
        token: otp,
      );

      // Créer/mettre à jour le profil utilisateur
      if (response.user != null) {
        await _createOrUpdateUserProfile(response.user!);
      }

      return response;
    } on AuthException catch (e) {
      throw Exception('Erreur authentification: ${e.message}');
    } catch (e) {
      throw Exception('Code invalide: $e');
    }
  }

  // -------- Profil --------

  // Créer/mettre à jour le profil en DB (table users)
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final existing = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('users').insert({
          'id': user.id,
          'phone': user.phone ?? '',
          'role': 'client',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('users')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', user.id);
      }
    } catch (e) {
      // on log seulement (pas d'exception bloquante pour laisser le login continuer)
      // ignore: avoid_print
      print('Erreur création/mise à jour profil: $e');
    }
  }

  // Récupérer le profil utilisateur (UserModel) pour l’utilisateur courant
  Future<UserModel?> getUserProfile() async {
    try {
      final uid = _supabase.auth.currentUser?.id; // ✅ plus de SupabaseConfig.currentUser
      if (uid == null) return null;

      final data = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();

      return UserModel.fromJson(data);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur récupération profil: $e');
      return null;
    }
  }

  // Mettre à jour le profil de l’utilisateur courant
  Future<void> updateProfile(Map<String, dynamic> patch) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('Non authentifié');

      patch['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('users').update(patch).eq('id', uid);
    } catch (e) {
      throw Exception('Erreur mise à jour profil: $e');
    }
  }

  // -------- Session --------

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
