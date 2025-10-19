// lib/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://asxazhaomtfkfosaxmaf.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzeGF6aGFvbXRma2Zvc2F4bWFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MjYxOTIsImV4cCI6MjA3MzAwMjE5Mn0.8qQ7FCw0-YNGphZhxM3FJxZDeqjXK5FnW5vlfIWmzI0';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      // Optionnel : tu peux même retirer complètement ce bloc.
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
