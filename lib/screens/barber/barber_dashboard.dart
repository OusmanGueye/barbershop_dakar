import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/barber_provider.dart';
import '../auth/login_screen.dart';

class BarberDashboard extends StatefulWidget {
  const BarberDashboard({super.key});

  @override
  State<BarberDashboard> createState() => _BarberDashboardState();
}

class _BarberDashboardState extends State<BarberDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarberProvider>().loadBarberData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final barberProvider = Provider.of<BarberProvider>(context);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard Barbier'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BarberProvider>().loadBarberData();
            },
          ),
          // AJOUT DU BOUTON DÉCONNEXION
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: barberProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => barberProvider.loadBarberData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Salutation
              Text(
                'Bonjour ${authProvider.currentUser?.fullName ?? "Barbier"} !',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEEE d MMMM yyyy', 'fr').format(now),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 20),

              // Stats du jour
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Clients aujourd\'hui',
                      '${barberProvider.stats['todayClients'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      'Revenus du jour',
                      '${barberProvider.stats['todayRevenue'] ?? 0} FCFA',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Prochain client',
                      barberProvider.stats['nextClientTime'] ?? '--:--',
                      Icons.access_time,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      'Ce mois',
                      '${barberProvider.stats['monthClients'] ?? 0} clients',
                      Icons.calendar_month,
                      Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Réservations du jour
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Réservations d\'aujourd\'hui',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${barberProvider.todayReservations.length} total',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Liste des réservations
              if (barberProvider.todayReservations.isEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Aucune réservation aujourd\'hui',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...barberProvider.todayReservations.map((reservation) {
                  return _buildReservationItem(
                    reservation['time_slot']?.substring(0, 5) ?? '',
                    reservation['client']?['full_name'] ?? 'Client',
                    reservation['service']?['name'] ?? 'Service',
                    reservation['status'] ?? 'confirmed',
                    reservation['id'],
                    reservation['client']?['phone'],
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationItem(
      String time,
      String client,
      String service,
      String status,
      String reservationId,
      String? phone,
      ) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Terminé';
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusText = 'En cours';
        break;
      case 'confirmed':
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'À venir';
        break;
      case 'no_show':
        statusColor = Colors.red;
        statusText = 'Absent';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  service,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (phone != null)
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (status == 'confirmed' || status == 'pending') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) => _handleReservationAction(value, reservationId),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'start',
                  child: Text('▶ Commencer'),
                ),
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('✓ Terminé'),
                ),
                const PopupMenuItem(
                  value: 'no_show',
                  child: Text('✗ Absent'),
                ),
              ],
            ),
          ] else if (status == 'in_progress') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) => _handleReservationAction(value, reservationId),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('✓ Terminé'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleReservationAction(String action, String reservationId) async {
    final barberProvider = context.read<BarberProvider>();
    bool success = false;

    switch (action) {
      case 'start':
        success = await barberProvider.startService(reservationId);
        break;
      case 'complete':
        success = await barberProvider.completeReservation(reservationId);
        break;
      case 'no_show':
        success = await barberProvider.markNoShow(reservationId);
        break;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statut mis à jour'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Déconnexion
              await context.read<AuthProvider>().signOut();

              // Retour au login
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
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