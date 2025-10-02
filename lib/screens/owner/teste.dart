// screens/owner/shop_settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart' as supa;
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/owner_provider.dart';
import '../auth/login_screen.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _editedData;
  String? _profileImageUrl;
  List<String> _galleryImages = [];

  File? _newProfileImage;
  List<File> _newGalleryImages = [];
  List<int> _galleryImagesToDelete = [];

  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isUploadingImages = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadImages();
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

  Future<void> _loadImages() async {
    try {
      final provider = context.read<OwnerProvider>();
      final barbershopId = provider.barbershopInfo?['id'];

      if (barbershopId == null) return;

      final response = await _supabase
          .from('barbershops')
          .select('profile_image, gallery_images')
          .eq('id', barbershopId)
          .single();

      setState(() {
        _profileImageUrl = response['profile_image'];
        if (response['gallery_images'] != null) {
          _galleryImages = List<String>.from(response['gallery_images']);
        }
      });
    } catch (e) {
      debugPrint('Erreur chargement images: $e');
    }
  }

  String _storagePathFromPublicUrl(String url) {
    final uri = Uri.parse(url);
    final segs = uri.pathSegments;
    final i = segs.indexOf('barbershop-images');
    if (i >= 0 && i < segs.length - 1) {
      return segs.sublist(i + 1).join('/');
    }
    return '';
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

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges || _newProfileImage != null || _newGalleryImages.isNotEmpty || _galleryImagesToDelete.isNotEmpty) {
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
            if (_hasChanges || _newProfileImage != null || _newGalleryImages.isNotEmpty || _galleryImagesToDelete.isNotEmpty)
              TextButton(
                onPressed: _isUploadingImages ? null : _saveSettings,
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
                      ],
                    ),

                    // Localisation
                    _buildLocationSection(),

                    // Section Images
                    _buildImagesSection(),

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
                            maxLength: 500,
                            decoration: InputDecoration(
                              labelText: 'Description du barbershop',
                              hintText: 'Décrivez votre barbershop, vos services, votre ambiance...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'Cette description sera visible par les clients',
                            ),
                            onChanged: (value) => _updateField('description', value),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bouton sauvegarder
                    if (_hasChanges || _newProfileImage != null || _newGalleryImages.isNotEmpty || _galleryImagesToDelete.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ElevatedButton(
                          onPressed: _isUploadingImages ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isUploadingImages
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white),
                                )
                              : const Text(
                                  'Enregistrer les modifications',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

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

  Widget _buildLocationSection() {
    return _buildSettingSection(
      'Localisation',
      [
        // Sélecteur de quartier
        ListTile(
          leading: const Icon(Icons.location_city, color: AppTheme.primaryColor),
          title: const Text('Quartier'),
          subtitle: Text(
            _editedData['quartier']?.isNotEmpty == true
                ? _editedData['quartier']
                : 'Sélectionner un quartier',
            style: TextStyle(
              color: _editedData['quartier']?.isNotEmpty == true
                  ? Colors.black87
                  : Colors.grey[600],
              fontWeight: _editedData['quartier']?.isNotEmpty == true
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_editedData['quartier']?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppConstants.getZoneForQuartier(_editedData['quartier']) ?? 'Zone',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          onTap: () => _showQuartierPicker(),
        ),

        const Divider(height: 1),

        // Adresse précise
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            initialValue: _editedData['address'],
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Adresse précise',
              hintText: 'Ex: Rue 10 x Rue 15, près de la mosquée',
              prefixIcon: const Icon(Icons.place, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Donnez des repères pour faciliter la localisation',
              helperMaxLines: 2,
            ),
            onChanged: (value) => _updateField('address', value),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'L\'adresse est requise';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

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
          // Filtrer les quartiers selon la recherche
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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Barre de recherche
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

                // Quartiers populaires (si pas de recherche)
                if (searchQuery.isEmpty) ...[
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppConstants.popularQuartiers.length,
                      itemBuilder: (context, index) {
                        final quartier = AppConstants.popularQuartiers[index];
                        final isSelected = _editedData['quartier'] == quartier;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(quartier),
                            onPressed: () {
                              setState(() {
                                _updateField('quartier', quartier);
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
                  const Divider(),
                ],

                // Liste des quartiers
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
                                      Text(
                                        zone,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...quartiers.map((quartier) {
                                  final isSelected = _editedData['quartier'] == quartier;
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
                                            child: Text(
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
                                        _updateField('quartier', quartier);
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

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Principale
        _buildSettingSection(
          'Image Principale',
          [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                          color: (_profileImageUrl == null && _newProfileImage == null)
                              ? Colors.orange
                              : Colors.grey.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_newProfileImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _newProfileImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (_profileImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _profileImageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red[300], size: 40),
                                      const SizedBox(height: 8),
                                      Text('Erreur chargement', style: TextStyle(color: Colors.red[300])),
                                    ],
                                  );
                                },
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

                          if (_newProfileImage != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NOUVELLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          if (_profileImageUrl != null || _newProfileImage != null)
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
                ],
              ),
            ),
          ],
        ),

        // Galerie
        _buildSettingSection(
          'Galerie Photos',
          [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                      Widget content;
                      bool isExistingImage = index < _galleryImages.length && !_galleryImagesToDelete.contains(index);
                      bool isNewImage = false;
                      int newImageIndex = -1;

                      int deletedCount = _galleryImagesToDelete.where((i) => i <= index).length;
                      int effectiveIndex = index - _galleryImages.length + deletedCount;

                      if (effectiveIndex >= 0 && effectiveIndex < _newGalleryImages.length) {
                        isNewImage = true;
                        newImageIndex = effectiveIndex;
                      }

                      if (isExistingImage) {
                        final imageUrl = _galleryImages[index];
                        content = Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _galleryImagesToDelete.add(index);
                                  });
                                },
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
                      } else if (isNewImage) {
                        final newImage = _newGalleryImages[newImageIndex];
                        content = Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                newImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _newGalleryImages.removeAt(newImageIndex);
                                  });
                                },
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
                        int currentTotal = _galleryImages.length - _galleryImagesToDelete.length + _newGalleryImages.length;
                        bool canAdd = currentTotal < 4;

                        content = InkWell(
                          onTap: canAdd ? () => _pickImage(isProfile: false) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(canAdd ? 0.3 : 0.1),
                                width: 2,
                                style: BorderStyle.solid,
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

                      return content;
                    },
                  ),

                  const SizedBox(height: 12),
                  Text(
                    '${_galleryImages.length - _galleryImagesToDelete.length + _newGalleryImages.length}/4 photos',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
            _newProfileImage = File(image.path);
            debugPrint('[PICK] new profile image set: ${image.path}');
          } else {
            final canAdd = _galleryImages.length - _galleryImagesToDelete.length + _newGalleryImages.length < 4;
            if (canAdd) {
              _newGalleryImages.add(File(image.path));
              debugPrint('[PICK] add gallery image: ${image.path}');
            }
          }
          _hasChanges = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de l\'image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadImages() async {
    final provider = context.read<OwnerProvider>();
    final barbershopInfo = provider.barbershopInfo;

    final authUid  = _supabase.auth.currentUser?.id;
    final ownerId  = barbershopInfo?['owner_id']?.toString();

    if (authUid == null) {
      throw Exception('Pas de session Supabase');
    }
    if (ownerId == null) {
      throw Exception('owner_id manquant');
    }
    if (authUid != ownerId) {
      throw Exception('Erreur d\'autorisation');
    }

    final barbershopId = barbershopInfo?['id']?.toString();
    if (barbershopId == null) {
      throw Exception('Barbershop ID est null');
    }

    setState(() => _isUploadingImages = true);

    try {
      String? newProfileImageUrl = _profileImageUrl;
      List<String> updatedGalleryUrls = List.from(_galleryImages);

      // Upload nouvelle image principale
      if (_newProfileImage != null) {
        if (_profileImageUrl != null) {
          final oldPath = _storagePathFromPublicUrl(_profileImageUrl!);
          if (oldPath.isNotEmpty) {
            try {
              await _supabase.storage
                  .from('barbershop-images')
                  .remove([oldPath]);
            } catch (e) {
              debugPrint('Erreur suppression ancienne image: $e');
            }
          }
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final profilePath = '$barbershopId/profile_$timestamp.jpg';
        final mimeType = _getMimeType(_newProfileImage!.path);

        await _supabase.storage
            .from('barbershop-images')
            .upload(
          profilePath,
          _newProfileImage!,
          fileOptions: supa.FileOptions(
            upsert: true,
            contentType: mimeType,
            cacheControl: '3600',
          ),
        );

        newProfileImageUrl = _supabase.storage
            .from('barbershop-images')
            .getPublicUrl(profilePath);
      }

      // Supprimer les images de galerie marquées
      for (int indexToDelete in _galleryImagesToDelete.reversed) {
        if (indexToDelete < updatedGalleryUrls.length) {
          final url = updatedGalleryUrls[indexToDelete];
          final path = _storagePathFromPublicUrl(url);
          if (path.isNotEmpty) {
            try {
              await _supabase.storage
                  .from('barbershop-images')
                  .remove([path]);
            } catch (e) {
              debugPrint('Erreur suppression image galerie: $e');
            }
          }
          updatedGalleryUrls.removeAt(indexToDelete);
        }
      }

      // Upload nouvelles images de galerie
      for (int i = 0; i < _newGalleryImages.length && updatedGalleryUrls.length < 4; i++) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'gallery_${timestamp}_$i.jpg';
        final galleryPath = '$barbershopId/$fileName';
        final mimeType = _getMimeType(_newGalleryImages[i].path);

        await _supabase.storage
            .from('barbershop-images')
            .upload(
          galleryPath,
          _newGalleryImages[i],
          fileOptions: supa.FileOptions(
            upsert: true,
            contentType: mimeType,
            cacheControl: '3600',
          ),
        );

        final galleryUrl = _supabase.storage
            .from('barbershop-images')
            .getPublicUrl(galleryPath);

        updatedGalleryUrls.add(galleryUrl);
      }

      // Mettre à jour dans la base de données
      await _supabase
          .from('barbershops')
          .update({
        'profile_image': newProfileImageUrl,
        'gallery_images': updatedGalleryUrls,
      })
          .eq('id', barbershopId);

      setState(() {
        _profileImageUrl = newProfileImageUrl;
        _galleryImages = updatedGalleryUrls;
        _newProfileImage = null;
        _newGalleryImages.clear();
        _galleryImagesToDelete.clear();
      });

      await provider.loadBarbershopInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images enregistrées avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      debugPrint('Erreur upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Erreur upload images: $e');
    } finally {
      setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _saveSettings() async {
    debugPrint('[SAVE] start');

    final hasImageOps = _newProfileImage != null ||
        _newGalleryImages.isNotEmpty ||
        _galleryImagesToDelete.isNotEmpty;

    final formValid = _formKey.currentState?.validate() ?? false;

    if (_profileImageUrl == null && _newProfileImage == null) {
      debugPrint('[SAVE] bloque: image principale manquante');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'image principale est obligatoire'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (hasImageOps) {
        debugPrint('[SAVE] calling _uploadImages()...');
        await _uploadImages();
        debugPrint('[SAVE] _uploadImages() DONE');
      }

      if (formValid) {
        final provider = context.read<OwnerProvider>();

        final dataToSave = Map<String, dynamic>.from(_editedData);
        dataToSave['profile_image'] = _profileImageUrl;
        dataToSave['gallery_images'] = _galleryImages;

        if (dataToSave['accepts_online_payment'] != true) {
          dataToSave['wave_number'] = '';
          dataToSave['orange_money_number'] = '';
        }

        debugPrint('[SAVE] updateBarbershopInfo(...)');
        final success = await provider.updateBarbershopInfo(dataToSave);

        if (!success) {
          throw Exception('Erreur lors de la sauvegarde');
        }
      }

      await context.read<OwnerProvider>().loadBarbershopInfo();

      if (mounted) {
        setState(() {
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modifications enregistrées'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[SAVE] error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
              await context.read<AuthProvider>().signOut();
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
}
