import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'profile_setup_screen.dart';
import '../main_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  final bool isOwnerSignup;
  final bool isBarberSignup;
  final String? barberId;
  final Function()? onVerified;

  const OTPScreen({
    super.key,
    required this.phone,
    this.isOwnerSignup = false,
    this.isBarberSignup = false,
    this.barberId,
    this.onVerified,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
        (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    6,
        (index) => FocusNode(),
  );

  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Focus automatique sur le premier champ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getOTP() {
    return _controllers.map((c) => c.text).join();
  }

  String _getTitle() {
    if (widget.isOwnerSignup) return 'Vérification Propriétaire';
    if (widget.isBarberSignup) return 'Vérification Barbier';
    return 'Vérification';
  }

  String _getInfoMessage() {
    if (widget.isOwnerSignup) {
      return 'Code de vérification pour créer votre compte propriétaire de barbershop.';
    }
    if (widget.isBarberSignup) {
      return 'Code de vérification pour rejoindre l\'équipe de barbiers.';
    }
    return 'Si vous n\'avez pas reçu de code, vérifiez votre numéro ou attendez quelques secondes.';
  }

  String _getButtonText() {
    if (widget.isOwnerSignup) return 'Vérifier et Créer';
    if (widget.isBarberSignup) return 'Vérifier et Rejoindre';
    return 'Vérifier';
  }

  Widget _getHeaderIcon() {
    if (widget.isOwnerSignup) {
      return Icon(Icons.store, color: Colors.orange[700], size: 20);
    }
    if (widget.isBarberSignup) {
      return Icon(Icons.content_cut, color: Colors.green[700], size: 20);
    }
    return Icon(Icons.info_outline, color: Colors.blue[700], size: 20);
  }

  Color _getHeaderColor() {
    if (widget.isOwnerSignup) return Colors.orange[50]!;
    if (widget.isBarberSignup) return Colors.green[50]!;
    return Colors.blue[50]!;
  }

  Color _getHeaderBorderColor() {
    if (widget.isOwnerSignup) return Colors.orange[200]!;
    if (widget.isBarberSignup) return Colors.green[200]!;
    return Colors.blue[200]!;
  }

  Color _getHeaderTextColor() {
    if (widget.isOwnerSignup) return Colors.orange[700]!;
    if (widget.isBarberSignup) return Colors.green[700]!;
    return Colors.blue[700]!;
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer les 6 chiffres'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyOTP(widget.phone, otp);

    if (!mounted) return;

    if (success) {

      // if (widget.isOwnerSignup && widget.onVerified != null) {
      //   await widget.onVerified!();  // ✅ Callback d'abord (avec await)
      //   if (!mounted) return;
      //   // Le callback gère déjà la navigation vers OwnerMainScreen
      //   return;
      // }

      // Si c'est une inscription owner avec callback
      if (widget.isOwnerSignup && widget.onVerified != null) {
        Navigator.pop(context);
        widget.onVerified!();
        return;
      }

      // if (widget.isBarberSignup && widget.onVerified != null) {
      //   await widget.onVerified!();  // ✅ Callback d'abord
      //   if (!mounted) return;
      //   return;
      // }

      // Si c'est une inscription barbier avec callback
      if (widget.isBarberSignup && widget.onVerified != null) {
        Navigator.pop(context);
        widget.onVerified!();
        return;
      }

      // Pour les autres cas (connexion normale)
      final user = authProvider.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: utilisateur non trouvé'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // CORRECTION : Vérifier le rôle d'abord
      if (user.role == 'barber' || user.role == 'owner') {
        // Les barbiers et owners vont directement au MainScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      } else if (user.fullName == null || user.fullName!.isEmpty) {
        // Seuls les clients sans nom vont au setup profil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        // Clients existants avec profil complet
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      }
    } else {
      // Erreur - vider les champs
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Code invalide'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOTP(widget.phone);

    if (success) {
      setState(() => _resendTimer = 60);
      _startTimer();

      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code renvoyé avec succès'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Erreur envoi code'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildOTPField(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? AppTheme.primaryColor
              : Colors.grey[300]!,
          width: _controllers[index].text.isNotEmpty ? 2 : 1,
        ),
      ),
      child: Center(
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                _verifyOTP();
              }
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTitle(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code envoyé au +221 ${widget.phone}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              if (widget.isOwnerSignup || widget.isBarberSignup) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getHeaderColor(),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getHeaderBorderColor()),
                  ),
                  child: Row(
                    children: [
                      _getHeaderIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isOwnerSignup
                              ? 'Après vérification, votre compte propriétaire sera créé'
                              : 'Après vérification, vous rejoindrez l\'équipe',
                          style: TextStyle(
                            fontSize: 13,
                            color: _getHeaderTextColor(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Les 6 champs OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOTPField(index)),
              ),

              const SizedBox(height: 32),

              // Timer et bouton renvoyer
              Center(
                child: TextButton(
                  onPressed: _resendTimer == 0 ? _resendOTP : null,
                  child: Text(
                    _resendTimer > 0
                        ? 'Renvoyer le code dans $_resendTimer s'
                        : 'Renvoyer le code',
                    style: TextStyle(
                      fontSize: 14,
                      color: _resendTimer > 0 ? Colors.grey : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getInfoMessage(),
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bouton Vérifier
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    _getButtonText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
