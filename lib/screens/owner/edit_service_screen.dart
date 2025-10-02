// screens/owner/edit_service_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class EditServiceScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const EditServiceScreen({
    super.key,
    required this.service,
  });

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _descriptionController;

  late String _selectedCategory;
  late bool _isActive;
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

  @override
  void initState() {
    super.initState();
    // Initialiser avec les données existantes
    _nameController = TextEditingController(text: widget.service['name'] ?? '');
    _priceController = TextEditingController(text: (widget.service['price'] ?? 0).toString());
    _durationController = TextEditingController(text: (widget.service['duration'] ?? 30).toString());
    _descriptionController = TextEditingController(text: widget.service['description'] ?? '');
    _selectedCategory = widget.service['category'] ?? 'autres';
    _isActive = widget.service['is_active'] ?? true;

    // Vérifier si la catégorie existe dans notre map
    if (!_categories.containsKey(_selectedCategory)) {
      _selectedCategory = 'autres';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final updates = {
          'name': _nameController.text.trim(),
          'price': int.parse(_priceController.text),
          'duration': int.parse(_durationController.text),
          'category': _selectedCategory,
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'is_active': _isActive,
        };

        final success = await context.read<OwnerProvider>().updateService(
          widget.service['id'],
          updates,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service modifié avec succès'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la modification'),
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
    final categoryData = _categories[_selectedCategory] ?? _categories['autres']!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Modifier - ${widget.service['name'] ?? 'Service'}'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec icône et statut
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryData['color'].withOpacity(0.1),
                      AppTheme.backgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _isActive
                                ? categoryData['color'].withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isActive ? categoryData['color'] : Colors.grey,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            categoryData['icon'],
                            size: 50,
                            color: _isActive ? categoryData['color'] : Colors.grey,
                          ),
                        ),
                        if (!_isActive)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      categoryData['label'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isActive ? categoryData['color'] : Colors.grey,
                      ),
                    ),
                    if (!_isActive) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Service inactif',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Statut du service
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Statut du service',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                          Text(
                            _isActive
                                ? 'Le service est disponible à la réservation'
                                : 'Le service n\'est pas disponible',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Catégorie
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

                    // Informations
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
}
