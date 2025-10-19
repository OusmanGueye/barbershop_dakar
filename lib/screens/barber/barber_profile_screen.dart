import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'package:supabase/supabase.dart' as supa;

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isEditing = false;

  String? _avatarUrl;
  Map<String, dynamic>? _barberData;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadBarberProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadBarberProfile() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return;

      // Charger les données users
      final userResponse = await SupabaseConfig.client
          .from('users')
          .select('full_name, avatar_url, phone')
          .eq('id', userId)
          .single();

      // Charger les données barber
      final barberResponse = await SupabaseConfig.client
          .from('barbers')
          .select('*, barbershop:barbershops(name)')
          .eq('user_id', userId)
          .single();

      setState(() {
        _userData = userResponse;
        _barberData = barberResponse;
        _displayNameController.text = barberResponse['display_name'] ?? '';
        _bioController.text = barberResponse['bio'] ?? '';
        _avatarUrl = userResponse['avatar_url'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Session expirée');
      }

      String? newAvatarUrl;

      // 1) Upload photo si une nouvelle image a été choisie
      if (_imageFile != null) {
        final ext = _imageFile!.path.split('.').last.toLowerCase();
        final mime = (ext == 'png')
            ? 'image/png'
            : (ext == 'webp')
            ? 'image/webp'
            : 'image/jpeg';

        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = '$userId/$fileName';
        final bytes = await _imageFile!.readAsBytes();

        await SupabaseConfig.client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: supa.FileOptions(
            upsert: true,
            contentType: mime,
            cacheControl: '3600',
          ),
        );

        newAvatarUrl = SupabaseConfig.client.storage
            .from('avatars')
            .getPublicUrl(path);

        // Mettre à jour dans users
        await SupabaseConfig.client
            .from('users')
            .update({'avatar_url': newAvatarUrl})
            .eq('id', userId);
      }

      // 2) Mettre à jour le profil barbier
      await SupabaseConfig.client
          .from('barbers')
          .update({
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
      })
          .eq('user_id', userId);

      setState(() {
        _isEditing = false;
        if (newAvatarUrl != null) {
          _avatarUrl = newAvatarUrl;
        }
        _imageFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      await _loadBarberProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _barberData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(color: Colors.white,),),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white,),
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header avec dégradé
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Photo de profil
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _imageFile == null && _avatarUrl == null
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nom
                  Text(
                    _barberData?['display_name'] ?? 'Barbier',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Barbershop
                  Text(
                    _barberData?['barbershop']?['name'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        '${_barberData?['total_cuts'] ?? 0}',
                        'Coupes',
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        '${_barberData?['rating'] ?? 0}',
                        'Note',
                        icon: Icons.star,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        '${_barberData?['experience_years'] ?? 0}',
                        'Ans',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Formulaire
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom d'affichage
                    const Text(
                      'Nom d\'affichage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _displayNameController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(
                        hintText: 'Votre nom professionnel',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Bio
                    const Text(
                      'Biographie',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      enabled: _isEditing,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez votre style, votre passion...',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value != null && value.length > 500) {
                          return 'Maximum 500 caractères';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Téléphone (lecture seule)
                    const Text(
                      'Téléphone',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _userData?['phone'] ?? 'Non renseigné',
                      enabled: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Informations fixes
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cut_outlined, color: AppTheme.primaryColor),
                    title: const Text('Spécialités'),
                    subtitle: Text(_formatSpecialties(_barberData?['specialties'])),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.monetization_on_outlined, color: AppTheme.primaryColor),
                    title: const Text('Taux de commission'),
                    subtitle: Text('${_barberData?['commission_rate'] ?? 30}%'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.store_outlined, color: AppTheme.primaryColor),
                    title: const Text('Barbershop'),
                    subtitle: Text(_barberData?['barbershop']?['name'] ?? 'Non assigné'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Déconnexion
            Container(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _logout,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {IconData? icon}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, color: AppTheme.secondaryColor, size: 18),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatSpecialties(dynamic specialties) {
    if (specialties == null) return 'Non renseignées';
    if (specialties is List && specialties.isEmpty) return 'Non renseignées';
    if (specialties is List) {
      return (specialties as List).join(', ');
    }
    return specialties.toString();
  }
}
