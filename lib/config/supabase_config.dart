import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // 🔴 IMPORTANT: Remplacez avec vos vraies clés
  // Trouvez-les dans Supabase Dashboard → Settings → API
  static const String supabaseUrl = 'https://asxazhaomtfkfosaxmaf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzeGF6aGFvbXRma2Zvc2F4bWFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MjYxOTIsImV4cCI6MjA3MzAwMjE5Mn0.8qQ7FCw0-YNGphZhxM3FJxZDeqjXK5FnW5vlfIWmzI0';
  
  // Instance Supabase
  static final supabase = Supabase.instance.client;
  
  // Getters utiles
  static User? get currentUser => supabase.auth.currentUser;
  static Session? get currentSession => supabase.auth.currentSession;
  
  // Check si user est connecté
  static bool get isAuthenticated => currentUser != null;
}