// screens/owner/team_management_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';
import 'add_barber_screen.dart';
import 'edit_barber_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<OwnerProvider>();
    await provider.loadBarbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredBarbers(List<Map<String, dynamic>> barbers) {
    var filtered = barbers;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((barber) {
        final name = (barber['display_name'] ?? '').toLowerCase();
        final phone = (barber['phone'] ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtre par statut
    if (_filterStatus == 'active') {
      filtered = filtered.where((b) => b['is_available'] == true).toList();
    } else if (_filterStatus == 'inactive') {
      filtered = filtered.where((b) => b['is_available'] == false).toList();
    }

    // Tri par performance (revenus)
    filtered.sort((a, b) {
      final aRevenue = (a['stats']?['monthRevenue'] ?? 0) as int;
      final bRevenue = (b['stats']?['monthRevenue'] ?? 0) as int;
      return bRevenue.compareTo(aRevenue);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();
    final filteredBarbers = _getFilteredBarbers(ownerProvider.barbers);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestion de l\'Équipe'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddBarberScreen(),
                ),
              ).then((_) {
                _loadData();
              });
            },
            color: AppTheme.primaryColor,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Stats globales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat(
                      'Total Barbiers',
                      '${ownerProvider.barbers.length}',
                      Icons.group,
                      Colors.blue,
                    ),
                    _buildQuickStat(
                      'Actifs',
                      '${ownerProvider.barbers.where((b) => b['is_available'] == true).length}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildQuickStat(
                      'Revenus/mois',
                      '${NumberFormat('#,###').format(_calculateTotalRevenue(ownerProvider.barbers))} F',
                      Icons.attach_money,
                      AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un barbier...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 10),
                // Filtres
                Row(
                  children: [
                    _buildFilterChip('Tous', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Actifs', 'active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inactifs', 'inactive'),
                  ],
                ),
              ],
            ),
          ),

          // Liste des barbiers
          Expanded(
            child: ownerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBarbers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredBarbers.length,
                itemBuilder: (context, index) {
                  final barber = filteredBarbers[index];
                  return _buildBarberCard(barber, ownerProvider);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddBarberScreen(),
            ),
          ).then((_) {
            _loadData();
          });
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white,),
        label: const Text('Nouveau barbier', style: TextStyle(color: Colors.white,),),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat'
                : 'Aucun barbier dans votre équipe',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Ajouter un barbier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBarberScreen(),
                  ),
                ).then((_) {
                  _loadData();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> barber, OwnerProvider provider) {
    final stats = barber['stats'] ?? {};
    final isAvailable = barber['is_available'] ?? false;
    final inviteStatus = barber['invite_status'] ?? 'pending';
    final monthRevenue = stats['monthRevenue'] ?? 0;
    final monthClients = stats['monthClients'] ?? 0;
    final commission = (monthRevenue * (barber['commission_rate'] ?? 30) / 100).round();
    final avatarUrl = barber['avatar_url'] ?? barber['photo_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isAvailable ? Colors.green : Colors.grey,
            width: 4,
          ),
        ),
      ),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: isAvailable ? AppTheme.primaryColor : Colors.grey,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                (barber['display_name'] ?? 'B')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  isAvailable ? Icons.check : Icons.close,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                barber['display_name'] ?? 'Barbier',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (inviteStatus == 'pending')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  'En attente',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (barber['phone'] != null)
              Text(barber['phone'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 5),
            Row(
              children: [
                _buildStatChip(Icons.people, '$monthClients clients', Colors.blue),
                const SizedBox(width: 8),
                _buildStatChip(Icons.attach_money, '${NumberFormat('#,###').format(monthRevenue)} F', Colors.green),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations détaillées
                const Text(
                  'Informations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                _buildInfoRow('Nom complet', barber['display_name'] ?? 'Non renseigné'),
                _buildInfoRow('Téléphone', barber['phone'] ?? 'Non renseigné'),
                _buildInfoRow('Expérience', '${barber['experience_years'] ?? 0} ans'),
                _buildInfoRow('Commission', '${barber['commission_rate'] ?? 30}%'),
                _buildInfoRow('Spécialités',
                    barber['specialties'] is List
                        ? (barber['specialties'] as List).join(', ')
                        : barber['specialties']?.toString() ?? 'Toutes coupes'
                ),

                if (inviteStatus == 'pending') ...[
                  const Divider(height: 30),
                  _buildInfoRow('Code invitation', barber['invite_code'] ?? 'Non généré',
                      isCode: true),
                ],

                const Divider(height: 30),

                // Statistiques
                const Text(
                  'Performance ce mois',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Clients', '$monthClients', Icons.people, Colors.blue),
                    _buildStatCard('Revenus', '${NumberFormat('#,###').format(monthRevenue)} F', Icons.attach_money, Colors.green),
                    _buildStatCard('Commission', '${NumberFormat('#,###').format(commission)} F', Icons.percent, Colors.orange),
                  ],
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          isAvailable ? Icons.toggle_on : Icons.toggle_off,
                          color: isAvailable ? Colors.green : Colors.grey,
                        ),
                        label: Text(isAvailable ? 'Actif' : 'Inactif'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isAvailable ? Colors.green : Colors.grey,
                          side: BorderSide(
                            color: isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                        onPressed: () {
                          provider.updateBarber(barber['id'], {
                            'is_available': !isAvailable,
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditBarberScreen(barber: barber),
                            ),
                          ).then((_) {
                            _loadData(); // Rafraîchir après modification
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (barber['phone'] != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone),
                          label: const Text('Appeler'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                          ),
                          onPressed: () => _callBarber(barber['phone']),
                        ),
                      ),
                    if (barber['phone'] != null) const SizedBox(width: 10),
                    if (inviteStatus == 'pending')
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Renvoyer code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                          onPressed: () => _showInviteCodeDialog(
                            barber['display_name'],
                            barber['phone'],
                            barber['invite_code'],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _confirmDelete(barber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
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

  Widget _buildInfoRow(String label, String value, {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: isCode
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié!')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            )
                : Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditBarberDialog(Map<String, dynamic> barber) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: barber['display_name']);
    final phoneController = TextEditingController(
      text: barber['phone']?.replaceAll('221', '') ?? '',
    );
    final experienceController = TextEditingController(
      text: barber['experience_years']?.toString() ?? '0',
    );
    final commissionController = TextEditingController(
      text: barber['commission_rate']?.toString() ?? '30',
    );
    final specialtiesController = TextEditingController(
      text: barber['specialties'] is List
          ? (barber['specialties'] as List).join(', ')
          : barber['specialties']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier barbier'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Nom requis' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+221 ',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: specialtiesController,
                  decoration: const InputDecoration(
                    labelText: 'Spécialités',
                    prefixIcon: Icon(Icons.cut),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: experienceController,
                        decoration: const InputDecoration(
                          labelText: 'Expérience',
                          prefixIcon: Icon(Icons.work),
                          suffixText: 'ans',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: commissionController,
                        decoration: const InputDecoration(
                          labelText: 'Commission',
                          prefixIcon: Icon(Icons.percent),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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

                final success = await context.read<OwnerProvider>().updateBarber(
                  barber['id'],
                  {
                    'display_name': nameController.text,
                    'phone': phoneController.text.isNotEmpty
                        ? '221${phoneController.text}'
                        : null,
                    'specialties': specialtiesController.text,
                    'experience_years': int.tryParse(experienceController.text) ?? 0,
                    'commission_rate': int.tryParse(commissionController.text) ?? 30,
                  },
                );

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Barbier mis à jour'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(String name, String phone, String code) {
    final message = '''
Bonjour $name,

Vous êtes invité à rejoindre notre équipe sur BarberGo.

📱 Téléchargez l'application
🔑 Utilisez le code: $code
✨ Commencez à recevoir des réservations

Cordialement,
${context.read<OwnerProvider>().barbershopInfo?['name'] ?? 'Barbershop'}
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code d\'invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_open, color: Colors.white, size: 30),
                  const SizedBox(height: 10),
                  const Text(
                    'CODE D\'INVITATION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pour: $name',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Tél: +221 $phone',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 15),
            const Text(
              'Ce code permet au barbier de créer son compte et rejoindre votre équipe.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copier le message'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copié!')),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Envoyer par SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => _sendSMS(phone, message),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> barber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer barbier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment supprimer ${barber['display_name']} ?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              final success = await context.read<OwnerProvider>()
                  .deleteBarber(barber['id']);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Barbier supprimé'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Helpers
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  int _calculateTotalRevenue(List<Map<String, dynamic>> barbers) {
    return barbers.fold(0, (sum, barber) {
      return sum + ((barber['stats']?['monthRevenue'] ?? 0) as int);
    });
  }

  void _callBarber(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _sendSMS(String phone, String message) async {
    final uri = Uri.parse('sms:+221$phone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      Navigator.pop(context);
    }
  }
}
