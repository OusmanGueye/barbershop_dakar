import 'package:barbershop_dakar/providers/barber_provider.dart';
import 'package:barbershop_dakar/providers/owner_provider.dart';
import 'package:barbershop_dakar/providers/reservation_provider.dart';
import 'package:barbershop_dakar/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/barbershop_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications
  await NotificationService.initialize();

  // Locales FR pour Intl
  await initializeDateFormatting('fr', null);

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Initialiser Supabase via ta config centralisée
  await SupabaseConfig.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BarbershopProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => BarberProvider()),
        ChangeNotifierProvider(create: (_) => OwnerProvider()),
      ],
      child: MaterialApp(
        title: 'BarberGo', // ou 'Barbershop Dakar' si tu préfères
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
