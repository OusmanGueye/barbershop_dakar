// lib/screens/auth/barber_login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/barber_service.dart';
import '../main_screen.dart';
import 'otp_screen.dart';

class BarberLoginScreen extends StatefulWidget {
  const BarberLoginScreen({super.key});

  @override
  State<BarberLoginScreen> createState() => _BarberLoginScreenState();
}

class _BarberLoginScreenState extends State<BarberLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _barberService = BarberService();
  bool _isLoading = false;

  Future<void> _verifyAndLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String phoneNumber = _phoneController.text.trim();
      String inviteCode = _codeController.text.trim().toUpperCase();

      String phoneForDatabase = phoneNumber;
      if (!phoneForDatabase.startsWith('221')) {
        phoneForDatabase = '221$phoneNumber';
      }

      // 1. Vérifier le code d'invitation
      final barber = await _barberService.verifyInviteCode(
        phoneForDatabase,
        inviteCode,
      );

      if (barber == null) {
        throw Exception('Code invalide ou téléphone incorrect.');
      }

      print('✅ Barbier trouvé: ${barber['display_name']}');

      // 2. Préparer le numéro pour l'OTP
      String phoneForOTP = phoneNumber;
      if (phoneForOTP.startsWith('221')) {
        phoneForOTP = phoneForOTP.substring(3);
      }

      // 3. Envoyer l'OTP
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendOTP(phoneForOTP);

      if (!mounted) return;

      if (success) {
        // 4. MODIFICATION ICI : Naviguer vers OTP avec pushReplacement
        Navigator.pushReplacement(  // Changé de push à pushReplacement
          context,
          MaterialPageRoute(
            builder: (_) => OTPScreen(
              phone: phoneForOTP,
              isBarberSignup: true,
              barberId: barber['id'],
              onVerified: () async {
                // Cette fonction sera appelée APRÈS le pop dans OTPScreen
                // Donc on fait la liaison et la navigation ici
                await _linkBarberToUserAndNavigate(barber['id']);
              },
            ),
          ),
        );
      } else {
        throw Exception('Impossible d\'envoyer le code OTP. Réessayez.');
      }

    } catch (e) {
      print('❌ Erreur: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Nouvelle fonction pour lier et naviguer
  Future<void> _linkBarberToUserAndNavigate(String barberId) async {
    try {
      print('Liaison barbier ID: $barberId');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final userId = authProvider.currentUser!.id;

      // 1. Mettre à jour le rôle
      await authProvider.updateProfile({
        'role': 'barber',
      });

      // 2. Lier le barbier
      final success = await _barberService.linkBarberToUser(barberId, userId);

      if (!success) {
        throw Exception('Impossible de lier le compte barbier');
      }

      print('✅ Barbier lié avec succès');

      if (!mounted) return;

      // 3. Navigation directe vers MainScreen (qui affichera le dashboard barbier)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
      );

    } catch (e) {
      print('❌ Erreur liaison: $e');

      if (!mounted) return;

      // En cas d'erreur, naviguer quand même vers MainScreen
      // car l'utilisateur est connecté
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
      );
    }
  }



  Future<void> _linkBarberToUser(String barberId) async {
    try {
      print('Début liaison barbier ID: $barberId');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Vérifier qu'on a bien un utilisateur connecté
      if (authProvider.currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final userId = authProvider.currentUser!.id;
      print('User ID: $userId');

      // 1. Mettre à jour le profil utilisateur avec le rôle barbier
      await authProvider.updateProfile({
        'role': 'barber',
      });
      print('✅ Rôle mis à jour');

      // 2. Lier le barbier au user dans la table barbers
      final success = await _barberService.linkBarberToUser(barberId, userId);

      if (!success) {
        throw Exception('Impossible de lier le compte barbier');
      }

      print('✅ Barbier lié avec succès');

      if (!mounted) return;

      // 3. Naviguer vers l'écran principal
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
      );

    } catch (e) {
      print('❌ Erreur liaison barbier: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Connexion Barbier'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rejoindre l\'équipe',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Utilisez le code fourni par votre manager',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 48),

                // Téléphone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  decoration: InputDecoration(
                    labelText: 'Votre téléphone',
                    prefixIcon: const Icon(Icons.phone),
                    prefixText: '+221 ',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Téléphone requis';
                    }
                    if (value.length != 9) {
                      return 'Le numéro doit contenir 9 chiffres';
                    }
                    if (!['77', '78', '76', '70', '75'].any((prefix) => value.startsWith(prefix))) {
                      return 'Numéro invalide (doit commencer par 77, 78, 76, 70 ou 75)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Code invitation
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Code d\'invitation',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: const OutlineInputBorder(),
                    hintText: 'ABC123',
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Code requis';
                    }
                    if (value.length != 6) {
                      return 'Le code doit contenir 6 caractères';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Bouton
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyAndLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Vérifier et Continuer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Demandez le code à votre manager si vous ne l\'avez pas reçu',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}