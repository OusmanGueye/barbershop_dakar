import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/barber_provider.dart';

class BarberClientsScreen extends StatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  State<BarberClientsScreen> createState() => _BarberClientsScreenState();
}

class _BarberClientsScreenState extends State<BarberClientsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = context.read<BarberProvider>();
    await Future.wait([
      provider.loadClients(),
      provider.loadTodayReservations(),
    ]);

    // Debug
    print('=== DEBUG CLIENTS ===');
    print('Réservations aujourd\'hui: ${provider.todayReservations.length}');
    print('Tous les clients: ${provider.allClients.length}');

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredClients(BarberProvider provider) {
    var clients = provider.allClients;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      clients = clients.where((client) {
        final name = (client['full_name'] ?? '').toLowerCase();
        final phone = (client['phone'] ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return clients;
  }

  @override
  Widget build(BuildContext context) {
    final barberProvider = context.watch<BarberProvider>();
    final filteredClients = _getFilteredClients(barberProvider);

    // Calculer les nombres pour les tabs
    final todayCount = barberProvider.todayReservations.length;
    final regularClients = filteredClients.where((c) => (c['visits'] ?? 0) >= 3).toList();
    final allClients = filteredClients;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Clients'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Aujourd\'hui ($todayCount)'),
            Tab(text: 'Réguliers (${regularClients.length})'),
            Tab(text: 'Tous (${allClients.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
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
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Contenu des tabs
          Expanded(
            child: _isLoading || barberProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                // Tab Aujourd'hui
                _buildTodayClients(barberProvider),

                // Tab Réguliers
                _buildClientsList(regularClients, showVisits: true, isRegular: true),

                // Tab Tous
                _buildClientsList(allClients, showVisits: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayClients(BarberProvider provider) {
    final todayReservations = provider.todayReservations;

    if (todayReservations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'Aucun client aujourd\'hui',
        subtitle: 'Aucune réservation prévue pour aujourd\'hui',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: todayReservations.length,
        itemBuilder: (context, index) {
          final reservation = todayReservations[index];
          final client = reservation['client'];

          if (client == null) {
            return const SizedBox.shrink();
          }

          return _buildTodayClientCard(reservation, client);
        },
      ),
    );
  }

  Widget _buildTodayClientCard(Map<String, dynamic> reservation, Map<String, dynamic> client) {
    final status = reservation['status'] ?? 'confirmed';
    final timeSlot = reservation['time_slot'] as String?;
    final formattedTime = timeSlot?.substring(0, 5) ?? '';

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
            color: _getStatusColor(status),
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar + heure
            Column(
              children: [
                _buildClientAvatar(client, size: 50),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Informations client
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          client['full_name'] ?? 'Client',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.content_cut, reservation['service']?['name'] ?? 'Service'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.timer, '${reservation['service']?['duration'] ?? 30} min'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.attach_money, '${reservation['total_amount'] ?? 0} FCFA'),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: AppTheme.primaryColor),
                  onPressed: () => _callClient(client['phone']),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
                if (client['phone'] != null)
                  IconButton(
                    icon: Icon(Icons.message, color: Colors.green[600]),
                    onPressed: () => _smsClient(client['phone']),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsList(List<Map<String, dynamic>> clients, {bool showVisits = false, bool isRegular = false}) {
    if (clients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: _searchQuery.isNotEmpty ? 'Aucun résultat' : 'Aucun client',
        subtitle: _searchQuery.isNotEmpty
            ? 'Aucun client ne correspond à votre recherche'
            : isRegular
            ? 'Aucun client régulier (3+ visites)'
            : 'Vous n\'avez pas encore de clients',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final client = clients[index];
          return _buildClientCard(client, showVisits: showVisits);
        },
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, {bool showVisits = false}) {
    final visits = client['visits'] ?? 0;
    final isVip = visits >= 10;
    final isRegular = visits >= 3;

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
        border: isVip
            ? Border.all(color: Colors.amber, width: 2)
            : isRegular
            ? Border.all(color: Colors.green.withOpacity(0.3), width: 1)
            : null,
      ),
      child: ExpansionTile(
        leading: _buildClientAvatar(client),
        title: Row(
          children: [
            Expanded(
              child: Text(
                client['full_name'] ?? 'Client',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isVip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          client['phone'] ?? 'Téléphone non renseigné',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVisits)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isVip
                      ? Colors.amber.withOpacity(0.1)
                      : isRegular
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '$visits visite${visits > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isVip
                        ? Colors.amber[700]
                        : isRegular
                        ? Colors.green[700]
                        : Colors.blue[700],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 12),

                // Informations détaillées
                _buildDetailRow('Téléphone', client['phone'] ?? 'Non renseigné'),
                _buildDetailRow('Langue préférée',
                    client['preferred_language'] == 'wo' ? 'Wolof' : 'Français'),
                _buildDetailRow('Client depuis', _formatJoinDate(client['created_at'])),
                _buildDetailRow('Dernière visite', _getLastVisitInfo(client)),

                if (isVip) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Client VIP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Fidélité exceptionnelle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Appeler'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                        onPressed: () => _callClient(client['phone']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('SMS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green),
                        ),
                        onPressed: () => _smsClient(client['phone']),
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

  Widget _buildClientAvatar(Map<String, dynamic> client, {double size = 40}) {
    final visits = client['visits'] ?? 0;
    final isVip = visits >= 10;

    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: client['avatar_url'] != null
              ? Colors.transparent
              : AppTheme.primaryColor,
          backgroundImage: client['avatar_url'] != null
              ? NetworkImage(client['avatar_url'])
              : null,
          child: client['avatar_url'] == null
              ? Text(
            (client['full_name'] ?? 'C')[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
        ),
        if (isVip)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star,
                size: size * 0.25,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    String label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      case 'no_show':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Terminé';
      case 'in_progress':
        return 'En cours';
      case 'confirmed':
        return 'Confirmé';
      case 'pending':
        return 'En attente';
      case 'no_show':
        return 'Absent';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _formatJoinDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM yyyy', 'fr').format(date);
    } catch (e) {
      return 'Date inconnue';
    }
  }

  String _getLastVisitInfo(Map<String, dynamic> client) {
    // Ici vous pourriez récupérer la vraie dernière visite
    // Pour l'instant, simulé
    final visits = client['visits'] ?? 0;
    if (visits == 0) return 'Aucune visite';
    if (visits == 1) return 'Première visite';
    return 'Il y a quelques jours'; // À remplacer par vraie logique
  }

  void _callClient(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'appeler ce numéro')),
          );
        }
      }
    }
  }

  void _smsClient(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('sms:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'envoyer un SMS')),
          );
        }
      }
    }
  }
}