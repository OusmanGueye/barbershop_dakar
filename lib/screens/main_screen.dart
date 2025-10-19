import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'client/home/client_home_screen.dart';
import 'barber/barber_main_screen.dart';
import 'owner/owner_main_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1) Pas authentifié → Login
    if (!auth.isAuthenticated || auth.currentUser == null) {
      // Evite de faire un push dans build : on renvoie juste l'écran Login
      return const LoginScreen();
    }

    final userRole = auth.currentUser!.role ?? 'client';
    // 2) Route par rôle
    switch (userRole) {
      case 'barber':
        return const BarberMainScreen();
      case 'owner':
        return const OwnerMainScreen();
      case 'client':
      default:
        return const ClientHomeScreen();
    }
  }
}
