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
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _onlyOpen = false;
  bool _onlyWithOnlinePayment = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarbershopProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recherche'),
        backgroundColor: Colors.white,
        elevation: 0,
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
                    hintText: 'Rechercher un barbershop...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showFilterSheet,
                    ),
                  ),
                  onChanged: (value) {
                    provider.searchBarbershops(value);
                  },
                ),

                const SizedBox(height: 15),

                // Chips de filtres actifs
                Wrap(
                  spacing: 8,
                  children: [
                    if (_selectedQuartier != null)
                      Chip(
                        label: Text(_selectedQuartier!),
                        onDeleted: () {
                          setState(() => _selectedQuartier = null);
                        },
                      ),
                    if (_onlyOpen)
                      Chip(
                        label: const Text('Ouvert maintenant'),
                        onDeleted: () {
                          setState(() => _onlyOpen = false);
                        },
                      ),
                    if (_onlyWithOnlinePayment)
                      Chip(
                        label: const Text('Paiement mobile'),
                        onDeleted: () {
                          setState(() => _onlyWithOnlinePayment = false);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Résultats
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.barbershops.isEmpty
                ? Center(
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
                    'Aucun résultat trouvé',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: provider.barbershops.length,
              itemBuilder: (context, index) {
                final barbershop = provider.barbershops[index];

                // Appliquer les filtres
                if (_onlyOpen && !barbershop.isOpenNow) {
                  return const SizedBox.shrink();
                }
                if (_onlyWithOnlinePayment && !barbershop.acceptsOnlinePayment) {
                  return const SizedBox.shrink();
                }

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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Quartier
              const Text('Quartier'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedQuartier,
                decoration: const InputDecoration(
                  hintText: 'Sélectionner un quartier',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  ...AppConstants.dakarQuartiers.map(
                        (q) => DropdownMenuItem(value: q, child: Text(q)),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedQuartier = value);
                },
              ),

              const SizedBox(height: 20),

              // Options
              SwitchListTile(
                title: const Text('Ouvert maintenant'),
                value: _onlyOpen,
                onChanged: (value) {
                  setState(() => _onlyOpen = value);
                },
              ),
              SwitchListTile(
                title: const Text('Paiement mobile'),
                value: _onlyWithOnlinePayment,
                onChanged: (value) {
                  setState(() => _onlyWithOnlinePayment = value);
                },
              ),

              const SizedBox(height: 20),

              // Bouton appliquer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Appliquer les filtres
                    this.setState(() {});
                  },
                  child: const Text('Appliquer les filtres'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}