import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/theme.dart';
import '../../../config/supabase_config.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../providers/barbershop_provider.dart';
import '../booking/booking_screen.dart';

class BarbershopDetailScreen extends StatefulWidget {
  final String barbershopId;

  const BarbershopDetailScreen({
    super.key,
    required this.barbershopId,
  });

  @override
  State<BarbershopDetailScreen> createState() => _BarbershopDetailScreenState();
}

class _BarbershopDetailScreenState extends State<BarbershopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ServiceModel? _selectedService;
  bool _isFavorite = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Charger les détails du barbershop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarbershopProvider>().selectBarbershop(widget.barbershopId);
      _checkIfFavorite();
      _loadReviews();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Vérifier si c'est un favori
  Future<void> _checkIfFavorite() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return;

      final response = await SupabaseConfig.supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('barbershop_id', widget.barbershopId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
        });
      }
    } catch (e) {
      print('Erreur checkIfFavorite: $e');
    }
  }

  // Toggle favori
  Future<void> _toggleFavorite() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connectez-vous pour ajouter aux favoris'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      if (_isFavorite) {
        // Retirer des favoris
        await SupabaseConfig.supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('barbershop_id', widget.barbershopId);
      } else {
        // Ajouter aux favoris
        await SupabaseConfig.supabase.from('favorites').insert({
          'user_id': userId,
          'barbershop_id': widget.barbershopId,
        });
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('Erreur toggleFavorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour des favoris'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // Partager
  Future<void> _shareBarbershop() async {
    final barbershop = context.read<BarbershopProvider>().selectedBarbershop;
    if (barbershop == null) return;

    final text = '''
🔥 Découvrez ${barbershop.name} sur Barbershop Dakar !
📍 ${barbershop.address ?? ''}, ${barbershop.quartier ?? ''}
⭐ ${barbershop.rating.toStringAsFixed(1)}/5 (${barbershop.totalReviews} avis)
📱 ${barbershop.phone ?? ''}

Téléchargez l'app pour réserver : https://barbershop-dakar.com
    ''';

    try {
      await Share.share(text);
    } catch (e) {
      print('Erreur partage: $e');
    }
  }

  // Ouvrir Maps
  Future<void> _openMaps() async {
    final barbershop = context.read<BarbershopProvider>().selectedBarbershop;
    if (barbershop == null) return;

    String mapsUrl;

    // Si on a les coordonnées GPS
    if (barbershop.latitude != null && barbershop.longitude != null) {
      // URL Google Maps avec coordonnées
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${barbershop.latitude},${barbershop.longitude}';
    } else {
      // URL Google Maps avec adresse
      final address = Uri.encodeComponent('${barbershop.address ?? ''} ${barbershop.quartier ?? ''} Dakar Senegal');
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$address';
    }

    final uri = Uri.parse(mapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir Maps'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // Appeler
  Future<void> _makePhoneCall() async {
    final barbershop = context.read<BarbershopProvider>().selectedBarbershop;
    if (barbershop?.phone == null) return;

    final uri = Uri.parse('tel:${barbershop!.phone}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'appeler'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // Charger les avis
  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);

    try {
      final response = await SupabaseConfig.supabase
          .from('reviews')
          .select('''
            *,
            client:users!client_id(full_name, avatar_url),
            barber:barbers(display_name)
          ''')
          .eq('barbershop_id', widget.barbershopId)
          .order('created_at', ascending: false);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Erreur loadReviews: $e');
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarbershopProvider>();
    final barbershop = provider.selectedBarbershop;
    final services = provider.services;

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (barbershop == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Barbershop non trouvé'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header avec image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  barbershop.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    barbershop.mainImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.primaryColor.withOpacity(0.8),
                        child: const Icon(
                          Icons.store,
                          size: 100,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : AppTheme.primaryColor,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: AppTheme.primaryColor),
                  onPressed: _shareBarbershop,
                ),
              ),
            ],
          ),

          // Infos principales
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status et rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: barbershop.isOpenNow
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: barbershop.isOpenNow ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: barbershop.isOpenNow ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              barbershop.isOpenNow ? 'Ouvert' : 'Fermé',
                              style: TextStyle(
                                color: barbershop.isOpenNow ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            barbershop.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${barbershop.totalReviews} avis)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Adresse
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              barbershop.address ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              barbershop.quartier ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _openMaps,
                        child: const Text('Itinéraire'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Téléphone
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      Text(
                        barbershop.phone ?? 'Non disponible',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: barbershop.phone != null ? _makePhoneCall : null,
                        child: const Text('Appeler'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Horaires
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      Text(
                        '${barbershop.openingTime ?? "08:00"} - ${barbershop.closingTime ?? "20:00"}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Moyens de paiement
                  if (barbershop.acceptsOnlinePayment) ...[
                    Text(
                      'Moyens de paiement',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPaymentChip('Cash', Icons.money, Colors.green),
                        if (barbershop.waveNumber != null)
                          _buildPaymentChip('Wave', Icons.phone_android, Colors.blue),
                        if (barbershop.orangeMoneyNumber != null)
                          _buildPaymentChip('Orange Money', Icons.phone_android, Colors.orange),
                      ],
                    ),
                  ],

                  if (barbershop.description != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'À propos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      barbershop.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Services'),
                  Tab(text: 'Barbiers'),
                  Tab(text: 'Avis'),
                ],
              ),
            ),
          ),

          // Contenu des tabs
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab Services
                _buildServicesTab(services),

                // Tab Barbiers
                _buildBarbersTab(),

                // Tab Avis
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),

      // Bouton Réserver
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
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
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _selectedService != null
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingScreen(
                    barbershop: barbershop,
                    service: _selectedService!,
                  ),
                ),
              );
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _selectedService != null
                  ? 'Réserver - ${_selectedService!.formattedPrice}'
                  : 'Sélectionnez un service',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab(List<ServiceModel> services) {
    if (services.isEmpty) {
      return const Center(
        child: Text('Aucun service disponible'),
      );
    }

    // Grouper les services par catégorie
    final Map<String, List<ServiceModel>> groupedServices = {};
    for (var service in services) {
      final category = service.category ?? 'Autres';
      if (!groupedServices.containsKey(category)) {
        groupedServices[category] = [];
      }
      groupedServices[category]!.add(service);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: groupedServices.length,
      itemBuilder: (context, index) {
        final category = groupedServices.keys.elementAt(index);
        final categoryServices = groupedServices[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 20),
            Text(
              category,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            ...categoryServices.map((service) => _buildServiceCard(service)),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    final isSelected = _selectedService?.id == service.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = isSelected ? null : service;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icône ou image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getServiceIcon(service.category),
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 15),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (service.description != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      service.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        service.formattedDuration,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Prix
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  service.formattedPrice,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primaryColor : Colors.black,
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Sélectionné',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'coupe':
        return Icons.content_cut;
      case 'barbe':
        return Icons.face;
      case 'coloration':
        return Icons.palette;
      case 'soin':
        return Icons.spa;
      case 'enfant':
        return Icons.child_care;
      case 'locks':
        return Icons.auto_awesome;
      default:
        return Icons.star;
    }
  }

  Widget _buildBarbersTab() {
    final provider = context.watch<BarbershopProvider>();
    final barbers = provider.barbers;

    if (provider.isLoadingBarbers) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (barbers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun barbier disponible',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: barbers.length,
      itemBuilder: (context, index) {
        final barber = barbers[index];
        return _buildBarberCard(barber);
      },
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> barber) {
    final isAvailable = barber['is_available'] ?? true;
    final rating = (barber['rating'] ?? 0.0).toDouble();
    final displayName = barber['display_name'] ?? 'Barbier';
    final experience = barber['experience_years'] ?? 0;
    final specialties = barber['specialties'] as List? ?? [];
    final photoUrl = barber['photo_url'];
    final bio = barber['bio'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: InkWell(
        onTap: isAvailable
            ? () {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayName sélectionné'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              // Photo
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: photoUrl != null
                      ? DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: photoUrl == null
                    ? Icon(
                  Icons.person,
                  size: 35,
                  color: AppTheme.primaryColor,
                )
                    : null,
              ),
              const SizedBox(width: 15),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Indisponible',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Experience
                    if (experience > 0)
                      Text(
                        '$experience ans d\'expérience',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                    // Rating
                    if (rating > 0)
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < rating.floor() ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 5),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                    // Spécialités
                    if (specialties.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: specialties.take(3).map((specialty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              specialty.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Bio
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bouton sélectionner
              if (isAvailable)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Onglet Avis
  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun avis pour le moment',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier à donner votre avis !',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] ?? 0).toInt();
    final clientName = review['client']?['full_name'] ?? 'Client';
    final clientAvatar = review['client']?['avatar_url'];
    final barberName = review['barber']?['display_name'];
    final comment = review['comment'] ?? '';
    final createdAt = DateTime.parse(review['created_at']);
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  image: clientAvatar != null
                      ? DecorationImage(
                    image: NetworkImage(clientAvatar),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: clientAvatar == null
                    ? Icon(Icons.person, color: AppTheme.primaryColor, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),

              // Nom et date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Rating
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),

          if (barberName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Barbier: $barberName',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

// Delegate pour le header des tabs
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}