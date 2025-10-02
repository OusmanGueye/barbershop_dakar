// screens/client/search/search_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../config/app_constants.dart';
import '../../../providers/barbershop_provider.dart';
import '../../../widgets/cards/barbershop_card.dart';
import '../barbershop/barbershop_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedQuartier;
  String? _selectedZone;
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _onlyOpen = false;
  bool _onlyWithOnlinePayment = false;
  bool _showAdvancedFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarbershopProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recherche avancée'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Nom du barbershop, quartier...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              provider.searchBarbershops('');
                            },
                          ),
                        IconButton(
                          icon: Badge(
                            label: Text(_countActiveFilters().toString()),
                            isLabelVisible: _countActiveFilters() > 0,
                            child: const Icon(Icons.tune),
                          ),
                          onPressed: _showFilterSheet,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    provider.searchBarbershops(value);
                  },
                ),

                const SizedBox(height: 15),

                // Chips de filtres actifs
                if (_hasActiveFilters())
                  Container(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_selectedZone != null)
                          Chip(
                            avatar: const Icon(Icons.location_city, size: 18),
                            label: Text(_selectedZone!),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedZone = null;
                                _selectedQuartier = null;
                              });
                              _applyFilters();
                            },
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        if (_selectedQuartier != null)
                          Chip(
                            avatar: const Icon(Icons.place, size: 18),
                            label: Text(_selectedQuartier!),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() => _selectedQuartier = null);
                              _applyFilters();
                            },
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        if (_onlyOpen)
                          Chip(
                            avatar: const Icon(Icons.access_time, size: 18, color: Colors.green),
                            label: const Text('Ouvert maintenant'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() => _onlyOpen = false);
                              _applyFilters();
                            },
                            backgroundColor: Colors.green.withOpacity(0.1),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        if (_onlyWithOnlinePayment)
                          Chip(
                            avatar: const Icon(Icons.phone_android, size: 18, color: Colors.orange),
                            label: const Text('Paiement mobile'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() => _onlyWithOnlinePayment = false);
                              _applyFilters();
                            },
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        if (_hasActiveFilters())
                          ActionChip(
                            avatar: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Tout effacer'),
                            onPressed: _clearAllFilters,
                            backgroundColor: Colors.grey[200],
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Nombre de résultats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getFilteredResults(provider).length} résultat${_getFilteredResults(provider).length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sort, size: 18),
                  label: const Text('Trier'),
                  onPressed: _showSortOptions,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Résultats
          Expanded(
            child: provider.isLoading
                ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
                : _getFilteredResults(provider).isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _getFilteredResults(provider).length,
              itemBuilder: (context, index) {
                final barbershop = _getFilteredResults(provider)[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
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
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Réinitialiser les filtres'),
            onPressed: _clearAllFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtres de recherche',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),

              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Zone
                      const Text(
                        'Zone',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedZone,
                        decoration: InputDecoration(
                          hintText: 'Sélectionner une zone',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Toutes les zones'),
                          ),
                          ...AppConstants.dakarZones.keys.map(
                                (zone) => DropdownMenuItem(
                              value: zone,
                              child: Text(zone),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            _selectedZone = value;
                            _selectedQuartier = null; // Reset quartier
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // Quartier (dépend de la zone)
                      const Text(
                        'Quartier',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedQuartier,
                        decoration: InputDecoration(
                          hintText: 'Sélectionner un quartier',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tous les quartiers'),
                          ),
                          ...(_selectedZone != null
                              ? AppConstants.dakarZones[_selectedZone]!
                              : AppConstants.dakarQuartiers)
                              .map(
                                (q) => DropdownMenuItem(
                              value: q,
                              child: Text(q),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => _selectedQuartier = value);
                        },
                      ),

                      const SizedBox(height: 30),

                      // Options
                      const Text(
                        'Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      SwitchListTile(
                        title: const Text('Ouvert maintenant'),
                        subtitle: const Text('Afficher uniquement les barbershops ouverts'),
                        value: _onlyOpen,
                        onChanged: (value) {
                          setSheetState(() => _onlyOpen = value);
                        },
                        activeColor: AppTheme.primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),

                      SwitchListTile(
                        title: const Text('Paiement mobile'),
                        subtitle: const Text('Wave, Orange Money, etc.'),
                        value: _onlyWithOnlinePayment,
                        onChanged: (value) {
                          setSheetState(() => _onlyWithOnlinePayment = value);
                        },
                        activeColor: AppTheme.primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              // Boutons d'action
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedZone = null;
                          _selectedQuartier = null;
                          _onlyOpen = false;
                          _onlyWithOnlinePayment = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trier par',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Popularité'),
              onTap: () {
                // Implémenter le tri
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Prix croissant'),
              onTap: () {
                // Implémenter le tri
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Prix décroissant'),
              onTap: () {
                // Implémenter le tri
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Distance'),
              subtitle: const Text('Disponible prochainement'),
              enabled: false,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getFilteredResults(BarbershopProvider provider) {
    var results = provider.barbershops;

    if (_selectedQuartier != null) {
      results = results.where((b) => b.quartier == _selectedQuartier).toList();
    } else if (_selectedZone != null) {
      final quartiersInZone = AppConstants.dakarZones[_selectedZone] ?? [];
      results = results.where((b) => quartiersInZone.contains(b.quartier)).toList();
    }

    if (_onlyOpen) {
      results = results.where((b) => b.isOpenNow).toList();
    }

    if (_onlyWithOnlinePayment) {
      results = results.where((b) => b.acceptsOnlinePayment).toList();
    }

    return results;
  }

  void _applyFilters() {
    setState(() {});
    // Appliquer les filtres au provider si nécessaire
    if (_selectedQuartier != null) {
      context.read<BarbershopProvider>().filterByQuartier(_selectedQuartier);
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedZone = null;
      _selectedQuartier = null;
      _onlyOpen = false;
      _onlyWithOnlinePayment = false;
    });
    context.read<BarbershopProvider>().filterByQuartier(null);
    context.read<BarbershopProvider>().searchBarbershops('');
  }

  bool _hasActiveFilters() {
    return _selectedZone != null ||
        _selectedQuartier != null ||
        _onlyOpen ||
        _onlyWithOnlinePayment;
  }

  int _countActiveFilters() {
    int count = 0;
    if (_selectedZone != null) count++;
    if (_selectedQuartier != null) count++;
    if (_onlyOpen) count++;
    if (_onlyWithOnlinePayment) count++;
    return count;
  }
}
