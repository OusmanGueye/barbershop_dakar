// screens/owner/edit_barber_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class EditBarberScreen extends StatefulWidget {
  final Map<String, dynamic> barber;

  const EditBarberScreen({
    super.key,
    required this.barber,
  });

  @override
  State<EditBarberScreen> createState() => _EditBarberScreenState();
}

class _EditBarberScreenState extends State<EditBarberScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _experienceController;
  late TextEditingController _commissionController;

  File? _imageFile;
  String? _currentAvatarUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableSpecialties = [
    'Dégradé', 'Afro', 'Barbe', 'Locks', 'Teinture',
    'Défrisage', 'Coupe enfant', 'Coupe classique',
    'Fade', 'Taper', 'Brush', 'Waves', 'Design',
    'Coupe aux ciseaux', 'Rasage traditionnel'
  ];

  List<String> _selectedSpecialties = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialiser les controllers avec les données existantes
    _nameController = TextEditingController(text: widget.barber['display_name'] ?? '');
    _phoneController = TextEditingController(
      text: widget.barber['phone']?.replaceAll('221', '') ?? '',
    );
    _bioController = TextEditingController(text: widget.barber['bio'] ?? '');
    _experienceController = TextEditingController(
      text: (widget.barber['experience_years'] ?? 0).toString(),
    );
    _commissionController = TextEditingController(
      text: (widget.barber['commission_rate'] ?? 30).toString(),
    );

    // Récupérer l'avatar actuel
    _currentAvatarUrl = widget.barber['avatar_url'] ?? widget.barber['photo_url'];

    // Gérer les spécialités
    if (widget.barber['specialties'] != null) {
      if (widget.barber['specialties'] is List) {
        _selectedSpecialties = List<String>.from(widget.barber['specialties']);
      } else if (widget.barber['specialties'] is String) {
        // Si c'est une string séparée par des virgules
        _selectedSpecialties = widget.barber['specialties']
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
  }

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
            if (_currentAvatarUrl != null || _imageFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  setState(() {
                    _imageFile = null;
                    _currentAvatarUrl = null;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final updates = {
          'display_name': _nameController.text.trim(),
          'phone': _phoneController.text.isNotEmpty
              ? '221${_phoneController.text.trim()}'
              : null,
          'bio': _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
          'specialties': _selectedSpecialties.isNotEmpty
              ? _selectedSpecialties
              : ['Toutes coupes'],
          'experience_years': int.tryParse(_experienceController.text) ?? 0,
          'commission_rate': int.tryParse(_commissionController.text) ?? 30,
        };

        final success = await context.read<OwnerProvider>().updateBarber(
          widget.barber['id'],
          updates,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barbier mis à jour avec succès'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la mise à jour'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Modifier - ${widget.barber['display_name'] ?? 'Barbier'}'),
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
                        child: ClipOval(
                          child: _imageFile != null
                              ? Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          )
                              : _currentAvatarUrl != null
                              ? Image.network(
                            _currentAvatarUrl!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPhotoPlaceholder();
                            },
                          )
                              : _buildPhotoPlaceholder(),
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
                              prefixIcon: Icon(Icons.badge),
                            ),
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Nom requis' : null,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone',
                              prefixIcon: Icon(Icons.phone),
                              prefixText: '+221 ',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _bioController,
                            decoration: const InputDecoration(
                              labelText: 'Bio / Présentation',
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
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Enregistrer les modifications',
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

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt,
          size: 35,
          color: AppTheme.primaryColor.withOpacity(0.7),
        ),
        const SizedBox(height: 5),
        Text(
          'Photo',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
