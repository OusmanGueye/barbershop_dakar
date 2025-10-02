// screens/client/home/client_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/barbershop_provider.dart';
import '../../../providers/reservation_provider.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/cards/barbershop_card.dart';
import '../../auth/login_screen.dart';
import '../barbershop/barbershop_detail_screen.dart';
import '../reservations/my_reservations_screen.dart';
import '../profile/client_profile_screen.dart';
import '../search/search_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Charger les données initiales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarbershopProvider>().loadBarbershops();
      context.read<ReservationProvider>().loadReservations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HomeTab(),
      const SearchScreen(),
      const MyReservationsScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Recherche',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Réservations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}

// Widget séparé pour l'onglet Accueil
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final barbershopProvider = Provider.of<BarbershopProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await barbershopProvider.loadBarbershops();
          },
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour,',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                authProvider.currentUser?.fullName ?? 'Client',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Notifications
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.notifications_outlined),
                                  onPressed: () async {
                                    // Pour plus tard : écran de notifications
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Notifications à venir'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Profile
                              GestureDetector(
                                onTap: () {
                                  _showProfileMenu(context, authProvider);
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: authProvider.currentUser?.avatarUrl != null
                                      ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      authProvider.currentUser!.avatarUrl!,
                                    ),
                                  )
                                      : Center(
                                    child: Text(
                                      (authProvider.currentUser?.fullName ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un barbershop...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          onChanged: (value) {
                            barbershopProvider.searchBarbershops(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filtres par quartier populaires
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(top: 10, bottom: 5),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: AppConstants.popularQuartiers.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildFilterChip(
                              'Tous',
                              barbershopProvider.selectedQuartier == null,
                                  () => barbershopProvider.filterByQuartier(null),
                              Icons.all_inclusive,
                            );
                          }

                          final quartier = AppConstants.popularQuartiers[index - 1];
                          return _buildFilterChip(
                            quartier,
                            barbershopProvider.selectedQuartier == quartier,
                                () => barbershopProvider.filterByQuartier(quartier),
                            null,
                          );
                        },
                      ),
                    ),

                    // Bouton voir tous les quartiers
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextButton.icon(
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: const Text('Voir tous les quartiers'),
                        onPressed: () => _showAllQuartiersModal(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Section titre avec indicateur
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Barbershops disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            '${barbershopProvider.barbershops.length} trouvé${barbershopProvider.barbershops.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      // Indicateur pour barbershops sans photo
                      if (!barbershopProvider.isLoading &&
                          barbershopProvider.barbershops.any((b) => b.profileImage == null))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Certains barbershops n\'ont pas encore de photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Liste des barbershops
              if (barbershopProvider.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              else if (barbershopProvider.barbershops.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 100,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Aucun barbershop trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essayez de modifier vos filtres',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            barbershopProvider.filterByQuartier(null);
                            barbershopProvider.loadBarbershops();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualiser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final barbershop = barbershopProvider.barbershops[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: BarbershopCard(
                          barbershop: barbershop,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BarbershopDetailScreen(
                                  barbershopId: barbershop.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: barbershopProvider.barbershops.length,
                  ),
                ),

              // Padding en bas pour la dernière carte
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, IconData? icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        avatar: icon != null ? Icon(icon, size: 18) : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.primaryColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
      ),
    );
  }

  void _showAllQuartiersModal() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final barbershopProvider = context.read<BarbershopProvider>();

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
                          'Filtrer par quartier',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppConstants.dakarQuartiers.length} quartiers disponibles',
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
                const SizedBox(height: 15),

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

                // Bouton "Tous les quartiers"
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      barbershopProvider.filterByQuartier(null);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: barbershopProvider.selectedQuartier == null
                          ? AppTheme.primaryColor
                          : Colors.grey[200],
                      foregroundColor: barbershopProvider.selectedQuartier == null
                          ? Colors.white
                          : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tous les quartiers'),
                  ),
                ),

                const Divider(),

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
                            final isSelected = barbershopProvider.selectedQuartier == quartier;
                            return ListTile(
                              dense: true,
                              title: Text(
                                quartier,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
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
                                barbershopProvider.filterByQuartier(quartier);
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

  void _showProfileMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de tirage
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
              title: const Text('Mon profil'),
              onTap: () {
                Navigator.pop(context);
                // Navigation vers l'onglet profil
                final parent = context.findAncestorStateOfType<_ClientHomeScreenState>();
                parent?.setState(() {
                  parent._currentIndex = 3;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
              title: const Text('Mes réservations'),
              onTap: () {
                Navigator.pop(context);
                // Navigation vers l'onglet réservations
                final parent = context.findAncestorStateOfType<_ClientHomeScreenState>();
                parent?.setState(() {
                  parent._currentIndex = 2;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
