import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/barbershop_service.dart';
import '../../services/upload_service.dart';
import '../owner/owner_main_screen.dart';
import 'otp_screen.dart';

class OwnerSignupScreen extends StatefulWidget {
  const OwnerSignupScreen({super.key});

  @override
  State<OwnerSignupScreen> createState() => _OwnerSignupScreenState();
}

class _OwnerSignupScreenState extends State<OwnerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _barbershopService = BarbershopService();
  final _uploadService = UploadService();

  // Étape actuelle
  int _currentStep = 0;

  // Controllers pour le owner
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  // Controllers pour le barbershop
  final _shopNameController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedQuartier = 'Almadies';
  bool _acceptsOnlinePayment = false;
  final _waveNumberController = TextEditingController();
  final _orangeMoneyController = TextEditingController();

  // Pour les horaires
  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 20, minute: 0);
  List<String> _workingDays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'
  ];

  // Photos du barbershop
  List<File> _shopPhotos = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  // Données temporaires pour après OTP
  Map<String, dynamic>? _tempOwnerData;
  Map<String, dynamic>? _tempBarbershopData;

  @override
  void dispose() {
    _pageController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _shopNameController.dispose();
    _shopPhoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _waveNumberController.dispose();
    _orangeMoneyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_shopPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _shopPhotos.add(File(image.path));
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_shopPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (photo != null) {
      setState(() {
        _shopPhotos.add(File(photo.path));
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _shopPhotos.removeAt(index);
    });
  }

  Future<void> _selectTime(bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openingTime : _closingTime,
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _proceedToOTP() async {
    // Validation manuelle des champs obligatoires
    if (_ownerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer votre nom complet'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut
      );
      return;
    }

    if (_ownerPhoneController.text.isEmpty || _ownerPhoneController.text.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un numéro de téléphone valide (9 chiffres)'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut
      );
      return;
    }

    if (_shopNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer le nom du barbershop'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer l\'adresse du barbershop'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut
      );
      return;
    }

    // Sauvegarder les données temporairement
    _tempOwnerData = {
      'full_name': _ownerNameController.text,
      'phone': _ownerPhoneController.text,
      'role': 'owner',
    };

    _tempBarbershopData = {
      'name': _shopNameController.text,
      'phone': '221${_shopPhoneController.text.isEmpty ? _ownerPhoneController.text : _shopPhoneController.text}',
      'address': _addressController.text,
      'quartier': _selectedQuartier,
      'description': _descriptionController.text.isEmpty
          ? 'Barbershop professionnel à $_selectedQuartier'
          : _descriptionController.text,
      'opening_time': '${_openingTime.hour.toString().padLeft(2, '0')}:${_openingTime.minute.toString().padLeft(2, '0')}',
      'closing_time': '${_closingTime.hour.toString().padLeft(2, '0')}:${_closingTime.minute.toString().padLeft(2, '0')}',
      'working_days': _workingDays.isEmpty ? ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'] : _workingDays,
      'is_active': true,
      'accepts_online_payment': _acceptsOnlinePayment,
      'wave_number': _waveNumberController.text.isEmpty ? null : '221${_waveNumberController.text}',
      'orange_money_number': _orangeMoneyController.text.isEmpty ? null : '221${_orangeMoneyController.text}',
    };

    setState(() => _isLoading = true);

    try {
      // Envoyer OTP
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendOTP(_ownerPhoneController.text);

      if (!mounted) return;

      if (success) {
        // Naviguer vers OTP avec callback
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPScreen(
              phone: _ownerPhoneController.text,
              isOwnerSignup: true,
              onVerified: _onOTPVerified,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Erreur envoi SMS'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onOTPVerified() async {
    // Cette fonction est appelée après vérification OTP réussie
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Mettre à jour le profil en tant qu'owner
      await authProvider.updateProfile(_tempOwnerData!);

      // 2. Créer le barbershop
      _tempBarbershopData!['owner_id'] = authProvider.currentUser!.id;
      final barbershopId = await _barbershopService.createBarbershop(_tempBarbershopData!);

      // 3. Upload des photos si présentes
      if (_shopPhotos.isNotEmpty) {
        List<String> photoUrls = [];
        for (var photo in _shopPhotos) {
          final url = await _uploadService.uploadBarbershopPhoto(
            barbershopId,
            photo,
          );
          if (url != null) photoUrls.add(url);
        }

        // Mettre à jour avec les URLs des photos
        await _barbershopService.updateBarbershop(
          barbershopId,
          {'photos': photoUrls},
        );
      }

      // 4. Ajouter les services de base
      await _barbershopService.addDefaultServices(barbershopId);

      if (!mounted) return;

      // 5. Naviguer vers le dashboard owner
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OwnerMainScreen()),
            (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Barbershop créé avec succès!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Créer mon Barbershop'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Informations'),
                  Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppTheme.primaryColor : Colors.grey[300])),
                  _buildStepIndicator(1, 'Horaires'),
                  Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppTheme.primaryColor : Colors.grey[300])),
                  _buildStepIndicator(2, 'Photos'),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Précédent'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_currentStep < 2) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _proceedToOTP();
                        }
                      },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_currentStep < 2 ? 'Suivant' : 'Créer le compte'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppTheme.primaryColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👤 Vos informations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Votre nom complet *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nom requis';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _ownerPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 9,
              decoration: const InputDecoration(
                labelText: 'Votre téléphone *',
                prefixIcon: Icon(Icons.phone),
                prefixText: '+221 ',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Téléphone requis';
                }
                if (value.length != 9) {
                  return 'Format invalide (9 chiffres)';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            const Text(
              '💈 Votre barbershop',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du barbershop *',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nom requis';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _shopPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 9,
              decoration: const InputDecoration(
                labelText: 'Téléphone barbershop (optionnel)',
                prefixIcon: Icon(Icons.phone_in_talk),
                prefixText: '+221 ',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Adresse requise';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedQuartier,
              decoration: const InputDecoration(
                labelText: 'Quartier',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
              ),
              items: const [
                'Almadies', 'Point E', 'Plateau', 'Médina',
                'Mermoz', 'Sacré-Cœur', 'HLM', 'Parcelles Assainies',
                'Ngor', 'Yoff', 'Grand Dakar', 'Pikine',
              ].map((quartier) {
                return DropdownMenuItem(
                  value: quartier,
                  child: Text(quartier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedQuartier = value!);
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.description),
                hintText: 'Décrivez votre barbershop...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '* Champs obligatoires',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🕐 Horaires d\'ouverture',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Horaires
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Ouverture'),
                  subtitle: Text(_openingTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(true),
                  tileColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  title: const Text('Fermeture'),
                  subtitle: Text(_closingTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(false),
                  tileColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            '📅 Jours d\'ouverture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Jours de la semaine
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'lundi', 'mardi', 'mercredi', 'jeudi',
              'vendredi', 'samedi', 'dimanche'
            ].map((day) {
              final isSelected = _workingDays.contains(day);
              return FilterChip(
                label: Text(day.substring(0, 1).toUpperCase() + day.substring(1)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _workingDays.add(day);
                    } else {
                      _workingDays.remove(day);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          const Text(
            '💳 Paiements mobiles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Accepter les paiements mobiles'),
            subtitle: const Text('Wave, Orange Money'),
            value: _acceptsOnlinePayment,
            onChanged: (value) {
              setState(() => _acceptsOnlinePayment = value);
            },
            tileColor: Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          if (_acceptsOnlinePayment) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _waveNumberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Wave (optionnel)',
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: '+221 ',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orangeMoneyController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Orange Money (optionnel)',
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: '+221 ',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📸 Photos du barbershop',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez jusqu\'à 5 photos (optionnel)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Grid des photos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _shopPhotos.length + 1,
            itemBuilder: (context, index) {
              if (index == _shopPhotos.length) {
                // Bouton ajouter
                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Prendre une photo'),
                              onTap: () {
                                Navigator.pop(context);
                                _takePhoto();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choisir de la galerie'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                );
              } else {
                // Photo existante
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_shopPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Les photos aident les clients à découvrir votre barbershop. Vous pourrez en ajouter plus tard.',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}