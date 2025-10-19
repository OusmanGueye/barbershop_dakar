import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart' as supa;
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/barbershop_service.dart';
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
  final _imagePicker = ImagePicker();
  final _supabase = Supabase.instance.client;

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

  String _selectedQuartier = 'Almadies';  // Valeur par défaut
  bool _acceptsOnlinePayment = false;
  final _waveNumberController = TextEditingController();
  final _orangeMoneyController = TextEditingController();

  // Pour les horaires
  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 20, minute: 0);
  List<String> _workingDays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'
  ];

  // Photos du barbershop - COMME SHOP_SETTINGS
  File? _profileImage;              // Image principale (OBLIGATOIRE)
  List<File> _galleryImages = [];   // Galerie (max 4)

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

  // ==========================================
  // GESTION D'IMAGES - IDENTIQUE À SHOP_SETTINGS
  // ==========================================

  Future<void> _pickImage({required bool isProfile}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isProfile ? 1920 : 1200,
      );

      if (image != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(image.path);
          } else {
            final canAdd = _galleryImages.length < 4;
            if (canAdd) {
              _galleryImages.add(File(image.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Maximum 4 photos pour la galerie'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ==========================================
  // QUARTIER PICKER - IDENTIQUE À SHOP_SETTINGS
  // ==========================================

  void _showQuartierPicker() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Map<String, List<String>> filteredZones = {};

          if (searchQuery.isEmpty) {
            filteredZones = AppConstants.dakarZones;
          } else {
            AppConstants.dakarZones.forEach((zone, quartiers) {
              final filtered = quartiers
                  .where((q) => q.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();
              if (filtered.isNotEmpty) {
                filteredZones[zone] = filtered;
              }
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sélectionner votre quartier',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cela permettra aux clients de vous trouver facilement',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un quartier...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setModalState(() {
                          searchQuery = '';
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                if (searchQuery.isEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppConstants.popularQuartiers.length,
                      itemBuilder: (context, index) {
                        final quartier = AppConstants.popularQuartiers[index];
                        final isSelected = _selectedQuartier == quartier;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(quartier),
                            onPressed: () {
                              setState(() {
                                _selectedQuartier = quartier;
                              });
                              Navigator.pop(context);
                            },
                            backgroundColor: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[200],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 20),
                ],

                Expanded(
                  child: filteredZones.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          'Aucun quartier trouvé',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredZones.length,
                    itemBuilder: (context, index) {
                      final zone = filteredZones.keys.elementAt(index);
                      final quartiers = filteredZones[zone]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    zone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...quartiers.map((quartier) {
                            final isSelected = _selectedQuartier == quartier;
                            return ListTile(
                              dense: true,
                              title: Text(quartier),
                              leading: Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? AppTheme.primaryColor : Colors.grey,
                                size: 20,
                              ),
                              trailing: isSelected
                                  ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Sélectionné',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedQuartier = quartier;
                                });
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                          if (index < filteredZones.length - 1)
                            const Divider(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
    // Validations
    if (_ownerNameController.text.isEmpty) {
      _showError('Veuillez entrer votre nom complet', 0);
      return;
    }

    if (_ownerPhoneController.text.isEmpty || _ownerPhoneController.text.length != 9) {
      _showError('Veuillez entrer un numéro de téléphone valide (9 chiffres)', 0);
      return;
    }

    if (_shopNameController.text.isEmpty) {
      _showError('Veuillez entrer le nom du barbershop', 0);
      return;
    }

    if (_addressController.text.isEmpty) {
      _showError('Veuillez entrer l\'adresse du barbershop', 0);
      return;
    }

    if (_selectedQuartier.isEmpty) {
      _showError('Veuillez sélectionner un quartier', 0);
      return;
    }

    // VALIDATION IMAGE PRINCIPALE OBLIGATOIRE
    if (_profileImage == null) {
      _showError('L\'image principale est obligatoire pour être visible dans la liste', 2);
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendOTP(_ownerPhoneController.text);

      if (!mounted) return;

      if (success) {
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

  void _showError(String message, int step) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut
    );
  }

  Future<void> _onOTPVerified() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Mettre à jour le profil en tant qu'owner
      await authProvider.updateProfile(_tempOwnerData!);

      // 2. Créer le barbershop
      _tempBarbershopData!['owner_id'] = authProvider.currentUser!.id;
      final barbershopId = await _barbershopService.createBarbershop(_tempBarbershopData!);

      // 3. UPLOAD DES IMAGES - IDENTIQUE À SHOP_SETTINGS
      String? profileImageUrl;
      List<String> galleryUrls = [];

      // Upload image principale (OBLIGATOIRE)
      if (_profileImage != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final profilePath = '$barbershopId/profile_$timestamp.jpg';
        final mimeType = _getMimeType(_profileImage!.path);

        await _supabase.storage
            .from('barbershop-images')
            .upload(
          profilePath,
          _profileImage!,
          fileOptions: supa.FileOptions(
            upsert: true,
            contentType: mimeType,
            cacheControl: '3600',
          ),
        );

        profileImageUrl = _supabase.storage
            .from('barbershop-images')
            .getPublicUrl(profilePath);
      }

      // Upload galerie (max 4)
      for (int i = 0; i < _galleryImages.length && i < 4; i++) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final galleryPath = '$barbershopId/gallery_${timestamp}_$i.jpg';
        final mimeType = _getMimeType(_galleryImages[i].path);

        await _supabase.storage
            .from('barbershop-images')
            .upload(
          galleryPath,
          _galleryImages[i],
          fileOptions: supa.FileOptions(
            upsert: true,
            contentType: mimeType,
            cacheControl: '3600',
          ),
        );

        final galleryUrl = _supabase.storage
            .from('barbershop-images')
            .getPublicUrl(galleryPath);

        galleryUrls.add(galleryUrl);
      }

      // 4. Mettre à jour avec les URLs des images
      await _barbershopService.updateBarbershop(
        barbershopId,
        {
          'profile_image': profileImageUrl,
          'gallery_images': galleryUrls,
        },
      );

      // 5. Ajouter les services de base
      await _barbershopService.addDefaultServices(barbershopId);

      if (!mounted) return;

      // 6. Naviguer vers le dashboard owner
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
            ),

            const SizedBox(height: 16),

            // QUARTIER PICKER AVANCÉ
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                title: const Text('Quartier *'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedQuartier,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppConstants.getZoneForQuartier(_selectedQuartier) ?? 'Zone',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showQuartierPicker(),
              ),
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
          // IMAGE PRINCIPALE (OBLIGATOIRE)
          const Text(
            '📸 Image Principale',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Image obligatoire pour être visible dans la liste',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () => _pickImage(isProfile: true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _profileImage == null
                      ? Colors.orange
                      : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_profileImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _profileImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter image principale',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Format 16:9 recommandé',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                  if (_profileImage != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: () => _pickImage(isProfile: true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // GALERIE (OPTIONNELLE)
          const Text(
            '🖼️ Galerie Photos (optionnel)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jusqu\'à 4 photos additionnelles de votre barbershop',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              if (index < _galleryImages.length) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _galleryImages[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removeGalleryImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                bool canAdd = _galleryImages.length < 4;
                return InkWell(
                  onTap: canAdd ? () => _pickImage(isProfile: false) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(canAdd ? 0.3 : 0.1),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          color: AppTheme.primaryColor.withOpacity(canAdd ? 1 : 0.3),
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajouter',
                          style: TextStyle(
                            color: AppTheme.primaryColor.withOpacity(canAdd ? 1 : 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '${_galleryImages.length}/4 photos',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          const SizedBox(height: 24),

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
                    'Les photos aident les clients à découvrir votre barbershop. Vous pourrez en modifier dans les paramètres.',
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
