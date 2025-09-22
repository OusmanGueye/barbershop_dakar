import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({super.key});

  @override
  State<ServicesManagementScreen> createState() => _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServices();
    });
  }

  Future<void> _loadServices() async {
    final provider = context.read<OwnerProvider>();
    await provider.loadServices();
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();
    final services = _filterServices(ownerProvider.services);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestion des Services'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServices,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => _showAddServiceDialog(),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats rapides
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  'Total Services',
                  '${ownerProvider.services.length}',
                  Icons.content_cut,
                  Colors.blue,
                ),
                _buildQuickStat(
                  'Actifs',
                  '${ownerProvider.services.where((s) => s['is_active'] == true).length}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildQuickStat(
                  'Prix moyen',
                  '${_calculateAveragePrice(ownerProvider.services)} F',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ],
            ),
          ),

          // Filtres par catégorie
          Container(
            height: 50,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              children: [
                _buildCategoryChip('Tous', 'all', Icons.all_inclusive),
                _buildCategoryChip('Coupe', 'coupe', Icons.content_cut),
                _buildCategoryChip('Barbe', 'barbe', Icons.face),
                _buildCategoryChip('Soins', 'soins', Icons.spa),
                _buildCategoryChip('Coloration', 'coloration', Icons.palette),
                _buildCategoryChip('Autres', 'autres', Icons.auto_awesome),
              ],
            ),
          ),

          // Liste des services
          Expanded(
            child: ownerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : services.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadServices,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  return _buildServiceCard(services[index], ownerProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterServices(List<Map<String, dynamic>> services) {
    if (_selectedCategory == 'all') return services;
    return services.where((s) => s['category'] == _selectedCategory).toList();
  }

  Widget _buildCategoryChip(String label, String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    final count = category == 'all'
        ? context.read<OwnerProvider>().services.length
        : context.read<OwnerProvider>().services
        .where((s) => s['category'] == category).length;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppTheme.primaryColor,
        ),
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.content_cut, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Aucun service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedCategory == 'all'
                ? 'Commencez par ajouter vos services'
                : 'Aucun service dans cette catégorie',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_selectedCategory == 'all')
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () => _showAddServiceDialog(),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, OwnerProvider provider) {
    final isActive = service['is_active'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isActive ? AppTheme.primaryColor : Colors.grey,
            width: 4,
          ),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getServiceIcon(service['category']),
            color: isActive ? AppTheme.primaryColor : Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                service['name'] ?? 'Service',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isActive ? null : TextDecoration.lineThrough,
                  color: isActive ? null : Colors.grey,
                ),
              ),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Inactif',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${NumberFormat('#,###').format(service['price'] ?? 0)} FCFA',
              style: TextStyle(
                color: isActive ? AppTheme.primaryColor : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 12, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${service['duration'] ?? 30} min',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (val) async {
            await provider.updateService(service['id'], {'is_active': val});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val ? 'Service activé' : 'Service désactivé'),
                backgroundColor: val ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          activeColor: AppTheme.primaryColor,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (service['description'] != null && service['description'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            service['description'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoCard(
                      Icons.category,
                      'Catégorie',
                      _formatCategory(service['category'] ?? 'autres'),
                      Colors.purple,
                    ),
                    _buildInfoCard(
                      Icons.timer,
                      'Durée',
                      '${service['duration'] ?? 30} min',
                      Colors.blue,
                    ),
                    _buildInfoCard(
                      Icons.attach_money,
                      'Prix',
                      '${NumberFormat('#,###').format(service['price'] ?? 0)} F',
                      Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                        onPressed: () => _showEditServiceDialog(service),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Supprimer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => _confirmDelete(service, provider),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getServiceIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'coupe': return Icons.content_cut;
      case 'barbe': return Icons.face;
      case 'soins': return Icons.spa;
      case 'coloration': return Icons.palette;
      default: return Icons.auto_awesome;
    }
  }

  String _formatCategory(String category) {
    switch (category.toLowerCase()) {
      case 'coupe': return 'Coupe';
      case 'barbe': return 'Barbe';
      case 'soins': return 'Soins';
      case 'coloration': return 'Coloration';
      default: return 'Autres';
    }
  }

  int _calculateAveragePrice(List<Map<String, dynamic>> services) {
    if (services.isEmpty) return 0;
    final total = services.fold<int>(0, (sum, s) => sum + (s['price'] ?? 0) as int);
    return (total / services.length).round();
  }

  void _showAddServiceDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final descriptionController = TextEditingController();
    String selectedCategory = 'coupe';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(  // Utiliser dialogContext
        title: const Text('Ajouter un service'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du service *',
                    hintText: 'Ex: Coupe simple',
                    prefixIcon: Icon(Icons.content_cut),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Nom requis' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (FCFA) *',
                    hintText: 'Ex: 3000',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Prix requis' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (minutes) *',
                    hintText: 'Ex: 30',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Durée requise' : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'coupe', child: Text('Coupe')),
                    DropdownMenuItem(value: 'barbe', child: Text('Barbe')),
                    DropdownMenuItem(value: 'soins', child: Text('Soins')),
                    DropdownMenuItem(value: 'coloration', child: Text('Coloration')),
                    DropdownMenuItem(value: 'autres', child: Text('Autres')),
                  ],
                  onChanged: (val) => selectedCategory = val ?? 'coupe',
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Description du service',
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),  // Utiliser dialogContext
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                // Fermer le dialogue AVANT l'appel async
                Navigator.pop(dialogContext);

                // Maintenant faire l'appel async
                final success = await context.read<OwnerProvider>().addService({
                  'name': nameController.text.trim(),
                  'price': int.parse(priceController.text),
                  'duration': int.tryParse(durationController.text) ?? 30,
                  'category': selectedCategory,
                  'description': descriptionController.text.trim().isNotEmpty
                      ? descriptionController.text.trim()
                      : null,
                  'is_active': true,
                  'barbershop_id': context.read<OwnerProvider>().barbershopInfo?['id'],
                });

                // Vérifier que le widget est toujours monté
                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service ajouté avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erreur lors de l\'ajout'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditServiceDialog(Map<String, dynamic> service) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: service['name']);
    final priceController = TextEditingController(text: service['price'].toString());
    final durationController = TextEditingController(text: service['duration'].toString());
    final descriptionController = TextEditingController(text: service['description'] ?? '');
    String selectedCategory = service['category'] ?? 'coupe';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le service'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du service',
                    prefixIcon: Icon(Icons.content_cut),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Nom requis' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (FCFA)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Prix requis' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (minutes)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'Durée requise' : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'coupe', child: Text('Coupe')),
                    DropdownMenuItem(value: 'barbe', child: Text('Barbe')),
                    DropdownMenuItem(value: 'soins', child: Text('Soins')),
                    DropdownMenuItem(value: 'coloration', child: Text('Coloration')),
                    DropdownMenuItem(value: 'autres', child: Text('Autres')),
                  ],
                  onChanged: (val) => selectedCategory = val ?? 'coupe',
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);

                final success = await context.read<OwnerProvider>().updateService(
                  service['id'],
                  {
                    'name': nameController.text.trim(),
                    'price': int.parse(priceController.text),
                    'duration': int.parse(durationController.text),
                    'category': selectedCategory,
                    'description': descriptionController.text.trim(),
                  },
                );

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service modifié'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> service, OwnerProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment supprimer "${service['name']}" ?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cette action est irréversible',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await provider.deleteService(service['id']);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Service supprimé'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}