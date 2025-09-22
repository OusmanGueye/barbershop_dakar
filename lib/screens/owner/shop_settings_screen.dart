import 'package:barbershop_dakar/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/owner_provider.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _editedData;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final provider = context.read<OwnerProvider>();
    final shop = provider.barbershopInfo ?? {};

    _editedData = {
      'name': shop['name'] ?? '',
      'phone': shop['phone'] ?? '',
      'address': shop['address'] ?? '',
      'quartier': shop['quartier'] ?? '',
      'opening_time': shop['opening_time'] ?? '08:00:00',
      'closing_time': shop['closing_time'] ?? '20:00:00',
      'working_days': List<String>.from(shop['working_days'] ?? [
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'
      ]),
      'description': shop['description'] ?? '',
      'accepts_online_payment': shop['accepts_online_payment'] ?? false,
      'wave_number': shop['wave_number'] ?? '',
      'orange_money_number': shop['orange_money_number'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();
    final barbershop = ownerProvider.barbershopInfo ?? {};

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Modifications non sauvegardées'),
              content: const Text('Voulez-vous vraiment quitter sans sauvegarder?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Quitter'),
                ),
              ],
            ),
          );
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Paramètres Barbershop'),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveSettings,
                child: const Text('Sauvegarder', style: TextStyle(color: AppTheme.primaryColor)),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Informations générales
              _buildSettingSection(
                'Informations générales',
                [
                  _buildTextField(
                    'Nom du barbershop',
                    _editedData['name'],
                    Icons.store,
                        (value) => _updateField('name', value),
                    validator: (value) => value?.isEmpty ?? true ? 'Nom requis' : null,
                  ),
                  _buildTextField(
                    'Téléphone',
                    _editedData['phone'],
                    Icons.phone,
                        (value) => _updateField('phone', value),
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty ?? true ? 'Téléphone requis' : null,
                  ),
                  _buildTextField(
                    'Adresse',
                    _editedData['address'],
                    Icons.location_on,
                        (value) => _updateField('address', value),
                  ),
                  _buildTextField(
                    'Quartier',
                    _editedData['quartier'],
                    Icons.map,
                        (value) => _updateField('quartier', value),
                  ),
                ],
              ),

              // Horaires
              _buildSettingSection(
                'Horaires d\'ouverture',
                [
                  _buildTimeSelector(
                    'Heure d\'ouverture',
                    _editedData['opening_time'],
                    Icons.access_time,
                        (time) => _updateField('opening_time', time),
                  ),
                  _buildTimeSelector(
                    'Heure de fermeture',
                    _editedData['closing_time'],
                    Icons.access_time_filled,
                        (time) => _updateField('closing_time', time),
                  ),
                  _buildWorkingDaysSelector(),
                ],
              ),

              // Paiements
              _buildSettingSection(
                'Méthodes de paiement',
                [
                  SwitchListTile(
                    title: const Text('Paiements en ligne'),
                    subtitle: const Text('Activer Wave et Orange Money'),
                    value: _editedData['accepts_online_payment'] ?? false,
                    onChanged: (val) => _updateField('accepts_online_payment', val),
                    activeColor: AppTheme.primaryColor,
                  ),
                  if (_editedData['accepts_online_payment'] == true) ...[
                    _buildTextField(
                      'Numéro Wave',
                      _editedData['wave_number'],
                      Icons.phone_android,
                          (value) => _updateField('wave_number', value),
                      keyboardType: TextInputType.phone,
                      prefixText: '+221 ',
                    ),
                    _buildTextField(
                      'Numéro Orange Money',
                      _editedData['orange_money_number'],
                      Icons.phone_android,
                          (value) => _updateField('orange_money_number', value),
                      keyboardType: TextInputType.phone,
                      prefixText: '+221 ',
                    ),
                  ],
                ],
              ),

              // Description
              _buildSettingSection(
                'Description',
                [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      initialValue: _editedData['description'],
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description du barbershop',
                        hintText: 'Décrivez votre barbershop...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) => _updateField('description', value),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Bouton sauvegarder
              if (_hasChanges)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Enregistrer les modifications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Dans la méthode build, après tous les autres widgets et avant la dernière parenthèse
              const SizedBox(height: 20),

// Section Compte
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: AppTheme.primaryColor),
                      title: const Text('Mon compte'),
                      subtitle: Text(
                        context.read<AuthProvider>().currentUser?.fullName ?? '',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        // Pour plus tard : écran profil
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Déconnexion'),
                      subtitle: Text(
                        'Se déconnecter de l\'application',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      onTap: () => _showLogoutDialog(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildTextField(
      String label,
      String value,
      IconData icon,
      Function(String) onChanged, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
        String? prefixText,
      }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          initialValue: value,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            prefixText: prefixText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTimeSelector(
      String label,
      String value,
      IconData icon,
      Function(String) onChanged,
      ) {
    final time = value.substring(0, 5);

    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(label),
      subtitle: Text(time, style: TextStyle(color: Colors.grey[600])),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () async {
          final parts = time.split(':');
          final initialTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );

          final picked = await showTimePicker(
            context: context,
            initialTime: initialTime,
          );

          if (picked != null) {
            final newTime = '${picked.hour.toString().padLeft(2, '0')}:'
                '${picked.minute.toString().padLeft(2, '0')}:00';
            onChanged(newTime);
          }
        },
      ),
    );
  }

  Widget _buildWorkingDaysSelector() {
    final allDays = [
      'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
    ];

    return ExpansionTile(
      leading: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
      title: const Text('Jours de travail'),
      subtitle: Text(
        _formatWorkingDays(_editedData['working_days']),
        style: TextStyle(color: Colors.grey[600]),
      ),
      children: allDays.map((day) {
        final isSelected = (_editedData['working_days'] as List).contains(day);
        return CheckboxListTile(
          title: Text(day.substring(0, 1).toUpperCase() + day.substring(1)),
          value: isSelected,
          activeColor: AppTheme.primaryColor,
          onChanged: (val) {
            setState(() {
              final days = List<String>.from(_editedData['working_days']);
              if (val == true) {
                days.add(day);
              } else {
                days.remove(day);
              }
              _updateField('working_days', days);
            });
          },
        );
      }).toList(),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Déconnexion
              await context.read<AuthProvider>().signOut();

              // Navigation vers LoginScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  String _formatWorkingDays(dynamic days) {
    if (days == null || days is! List) return 'Non défini';
    if (days.isEmpty) return 'Aucun jour';
    if (days.length == 7) return 'Tous les jours';
    if (days.length == 6 && !days.contains('dimanche')) return 'Lun - Sam';
    if (days.length == 5 && !days.contains('samedi') && !days.contains('dimanche')) {
      return 'Lun - Ven';
    }
    return '${days.length} jours';
  }

  void _updateField(String field, dynamic value) {
    setState(() {
      _editedData[field] = value;
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<OwnerProvider>();

      // Nettoyer les données avant l'envoi
      final dataToSave = Map<String, dynamic>.from(_editedData);

      // Enlever les numéros de paiement si les paiements en ligne sont désactivés
      if (dataToSave['accepts_online_payment'] != true) {
        dataToSave['wave_number'] = '';
        dataToSave['orange_money_number'] = '';
      }

      final success = await provider.updateBarbershopInfo(dataToSave);

      if (success) {
        setState(() {
          _hasChanges = false;
        });

        // Recharger les infos du barbershop
        await provider.loadBarbershopInfo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paramètres enregistrés avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de la sauvegarde');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}