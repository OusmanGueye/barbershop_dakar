import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.supabase;

  // Envoyer OTP
  Future<void> sendOTP(String phone) async {
    try {
      // Formater le numéro pour le Sénégal
      String formattedPhone = phone;
      if (!phone.startsWith('+')) {
        formattedPhone = '+221$phone';
      }

      await _supabase.auth.signInWithOtp(
        phone: formattedPhone,
      );
    } catch (e) {
      throw Exception('Erreur envoi SMS: ${e.toString()}');
    }
  }

  // Vérifier OTP
  Future<AuthResponse> verifyOTP(String phone, String otp) async {
    try {
      String formattedPhone = phone;
      if (!phone.startsWith('+')) {
        formattedPhone = '+221$phone';
      }

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: formattedPhone,
        token: otp,
      );

      // Créer/Mettre à jour le profil utilisateur
      if (response.user != null) {
        await _createOrUpdateUserProfile(response.user!);
      }

      return response;
    } catch (e) {
      throw Exception('Code invalide: ${e.toString()}');
    }
  }

  // Créer ou mettre à jour le profil
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        // Créer nouveau profil
        await _supabase.from('users').insert({
          'id': user.id,
          'phone': user.phone,
          'role': 'client',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Erreur création profil: $e');
    }
  }

  // Récupérer le profil utilisateur
  Future<UserModel?> getUserProfile() async {
    try {
      if (SupabaseConfig.currentUser == null) return null;
      
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', SupabaseConfig.currentUser!.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Erreur récupération profil: $e');
      return null;
    }
  }

  // Mettre à jour le profil
  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      if (SupabaseConfig.currentUser == null) return;
      
      data['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabase
          .from('users')
          .update(data)
          .eq('id', SupabaseConfig.currentUser!.id);
    } catch (e) {
      throw Exception('Erreur mise à jour profil: ${e.toString()}');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}