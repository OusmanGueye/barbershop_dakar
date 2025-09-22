import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'client/home/client_home_screen.dart';
import 'barber/barber_main_screen.dart';
import 'owner/owner_main_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.currentUser?.role ?? 'client';
    print(authProvider.currentUser?.role);

    // Navigation selon le rôle
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