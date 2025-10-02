// screens/owner/add_barber_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class AddBarberScreen extends StatefulWidget {
  const AddBarberScreen({super.key});

  @override
  State<AddBarberScreen> createState() => _AddBarberScreenState();
}

class _AddBarberScreenState extends State<AddBarberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController(text: '0');
  final _commissionController = TextEditingController(text: '30');

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Liste des spécialités disponibles
  final List<String> _availableSpecialties = [
    'Dégradé', 'Afro', 'Barbe', 'Locks', 'Teinture',
    'Défrisage', 'Coupe enfant', 'Coupe classique',
    'Fade', 'Taper', 'Brush', 'Waves', 'Design',
    'Coupe aux ciseaux', 'Rasage traditionnel'
  ];

  List<String> _selectedSpecialties = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (pickedFile != null) {
                  setState(() {
                    _imageFile = File(pickedFile.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Choisir de la galerie'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (pickedFile != null) {
                  setState(() {
                    _imageFile = File(pickedFile.path);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedSpecialties.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner au moins une spécialité'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final inviteCode = _generateInviteCode();

        final barberData = {
          'display_name': _nameController.text.trim(),
          'phone': '221${_phoneController.text.trim()}',
          'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
          'specialties': _selectedSpecialties,
          'experience_years': int.tryParse(_experienceController.text) ?? 0,
          'commission_rate': int.tryParse(_commissionController.text) ?? 30,
          'is_available': true,
          'invite_code': inviteCode,
          'invite_status': 'pending',
          'total_cuts': 0,
          'rating': 0.0,
        };

        final success = await context.read<OwnerProvider>().addBarberWithInvite(barberData);

        if (success) {
          _showSuccessDialog(inviteCode);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'ajout du barbier'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String inviteCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Barbier ajouté avec succès !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'CODE D\'INVITATION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    inviteCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Partagez ce code avec ${_nameController.text}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copié !'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            child: const Text('Copier'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Terminé'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau Barbier'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec photo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.backgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _imageFile != null
                            ? ClipOval(
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 35,
                              color: AppTheme.primaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Ajouter photo',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Informations de base
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Informations personnelles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom complet *',
                              hintText: 'Ex: Mamadou Diallo',
                              prefixIcon: Icon(Icons.badge),
                            ),
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Nom requis' : null,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone *',
                              hintText: '77 123 45 67',
                              prefixIcon: Icon(Icons.phone),
                              prefixText: '+221 ',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Téléphone requis';
                              if (value!.length < 9) return 'Numéro invalide';
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _bioController,
                            decoration: const InputDecoration(
                              labelText: 'Bio / Présentation',
                              hintText: 'Décrivez le barbier en quelques mots...',
                              prefixIcon: Icon(Icons.info_outline),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            maxLength: 200,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Expérience et commission
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.work_history, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Expérience & Rémunération',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _experienceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Expérience',
                                    suffixText: 'ans',
                                    prefixIcon: Icon(Icons.timeline),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextFormField(
                                  controller: _commissionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Commission',
                                    suffixText: '%',
                                    prefixIcon: Icon(Icons.percent),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Spécialités
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Spécialités',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _selectedSpecialties.isEmpty
                                      ? AppTheme.errorColor.withOpacity(0.1)
                                      : AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_selectedSpecialties.length} sélectionnée${_selectedSpecialties.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedSpecialties.isEmpty
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSpecialties.map((specialty) {
                              final isSelected = _selectedSpecialties.contains(specialty);
                              return FilterChip(
                                label: Text(specialty),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSpecialties.add(specialty);
                                    } else {
                                      _selectedSpecialties.remove(specialty);
                                    }
                                  });
                                },
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Bouton submit
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Créer et générer le code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
    );
  }
}
