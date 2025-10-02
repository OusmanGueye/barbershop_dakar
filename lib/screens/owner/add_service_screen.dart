// screens/owner/add_service_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'coupe';
  IconData _selectedIcon = Icons.content_cut;
  bool _isLoading = false;

  // Catégories avec leurs icônes
  final Map<String, Map<String, dynamic>> _categories = {
    'coupe': {'label': 'Coupe', 'icon': Icons.content_cut, 'color': Colors.blue},
    'barbe': {'label': 'Barbe', 'icon': Icons.face, 'color': Colors.brown},
    'soins': {'label': 'Soins', 'icon': Icons.spa, 'color': Colors.green},
    'coloration': {'label': 'Coloration', 'icon': Icons.palette, 'color': Colors.purple},
    'locks': {'label': 'Locks/Tresses', 'icon': Icons.grain, 'color': Colors.orange},
    'enfant': {'label': 'Enfant', 'icon': Icons.child_care, 'color': Colors.pink},
    'autres': {'label': 'Autres', 'icon': Icons.auto_awesome, 'color': Colors.grey},
  };

  // Services prédéfinis par catégorie
  final Map<String, List<Map<String, dynamic>>> _presetServices = {
    'coupe': [
      {'name': 'Coupe simple', 'price': 2000, 'duration': 20},
      {'name': 'Coupe + Dégradé', 'price': 3000, 'duration': 30},
      {'name': 'Coupe moderne', 'price': 3500, 'duration': 35},
      {'name': 'Fade', 'price': 4000, 'duration': 40},
    ],
    'barbe': [
      {'name': 'Taille barbe simple', 'price': 1500, 'duration': 15},
      {'name': 'Barbe complète', 'price': 2500, 'duration': 25},
      {'name': 'Rasage traditionnel', 'price': 3000, 'duration': 30},
    ],
    'soins': [
      {'name': 'Shampoing', 'price': 1000, 'duration': 10},
      {'name': 'Masque capillaire', 'price': 2000, 'duration': 20},
      {'name': 'Massage crânien', 'price': 2500, 'duration': 25},
    ],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectPreset(Map<String, dynamic> preset) {
    setState(() {
      _nameController.text = preset['name'];
      _priceController.text = preset['price'].toString();
      _durationController.text = preset['duration'].toString();
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final serviceData = {
          'name': _nameController.text.trim(),
          'price': int.parse(_priceController.text),
          'duration': int.parse(_durationController.text),
          'category': _selectedCategory,
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'is_active': true,
        };

        final success = await context.read<OwnerProvider>().addService(serviceData);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service ajouté avec succès'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'ajout'),
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
        title: const Text('Nouveau Service'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec icône
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
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _categories[_selectedCategory]!['color'].withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _categories[_selectedCategory]!['color'],
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _categories[_selectedCategory]!['icon'],
                        size: 50,
                        color: _categories[_selectedCategory]!['color'],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _categories[_selectedCategory]!['label'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _categories[_selectedCategory]!['color'],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélection de catégorie
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
                          const Text(
                            'Catégorie',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _categories.entries.map((entry) {
                              final isSelected = _selectedCategory == entry.key;
                              return FilterChip(
                                label: Text(entry.value['label']),
                                avatar: Icon(
                                  entry.value['icon'],
                                  size: 18,
                                  color: isSelected ? Colors.white : entry.value['color'],
                                ),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedCategory = entry.key;
                                    _selectedIcon = entry.value['icon'];
                                  });
                                },
                                selectedColor: entry.value['color'],
                                backgroundColor: entry.value['color'].withOpacity(0.1),
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Services prédéfinis
                    if (_presetServices[_selectedCategory] != null) ...[
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
                            const Text(
                              'Services suggérés',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _presetServices[_selectedCategory]!.map((preset) {
                                return ActionChip(
                                  label: Text(preset['name']),
                                  onPressed: () => _selectPreset(preset),
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  labelStyle: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Formulaire
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
                          const Text(
                            'Informations du service',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom du service *',
                              hintText: 'Ex: Coupe moderne',
                              prefixIcon: Icon(Icons.content_cut),
                            ),
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Nom requis' : null,
                          ),
                          const SizedBox(height: 15),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Prix *',
                                    hintText: '3000',
                                    prefixIcon: Icon(Icons.attach_money),
                                    suffixText: 'FCFA',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (value) =>
                                  value?.isEmpty ?? true ? 'Prix requis' : null,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextFormField(
                                  controller: _durationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Durée *',
                                    hintText: '30',
                                    prefixIcon: Icon(Icons.timer),
                                    suffixText: 'min',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (value) =>
                                  value?.isEmpty ?? true ? 'Durée requise' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optionnel)',
                              hintText: 'Décrivez le service...',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            maxLength: 200,
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
                            Icon(Icons.add_circle, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Créer le service',
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
