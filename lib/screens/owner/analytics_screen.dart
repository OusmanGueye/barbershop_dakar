import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = '7j'; // cohérent avec 7J / 30J / 3M / 1A

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<OwnerProvider>();
    await Future.wait([
      provider.loadAnalytics(),
      provider.loadDashboardStats(),
      provider.loadBarbers(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();
    final stats = ownerProvider.dashboardStats;
    final analytics = ownerProvider.analytics;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Aperçu'),
              Tab(text: 'Revenus'),
              Tab(text: 'Performance'),
            ],
          ),
        ),
        body: ownerProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildOverviewTab(ownerProvider, stats, analytics),
            _buildRevenueTab(ownerProvider, stats, analytics),
            _buildPerformanceTab(ownerProvider, stats),
          ],
        ),
      ),
    );
  }

  // TAB 1: APERÇU
  Widget _buildOverviewTab(OwnerProvider provider, Map<String, dynamic> stats, Map<String, dynamic> analytics) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé du mois
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé du mois',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${NumberFormat('#,###').format(stats['monthRevenue'] ?? 0)} FCFA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat('Clients', '${stats['monthClients'] ?? 0}', Icons.people),
                      _buildMiniStat('Ticket moyen', '${NumberFormat('#,###').format(stats['averageTicket'] ?? 0)} F', Icons.receipt),
                      _buildMiniStat('Taux occupation', '${stats['occupancyRate'] ?? 0}%', Icons.event_seat),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // KPIs rapides
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildKpiCard(
                  'Aujourd\'hui',
                  '${NumberFormat('#,###').format(stats['todayRevenue'] ?? 0)} F',
                  '${stats['todayClients'] ?? 0} clients',
                  Icons.today,
                  Colors.blue,
                ),
                _buildKpiCard(
                  'Cette semaine',
                  '${NumberFormat('#,###').format(_calculateWeekRevenue(analytics))} F',
                  '${_calculateWeekClients(provider)} clients',
                  Icons.date_range,
                  Colors.green,
                ),
                _buildKpiCard(
                  'Barbiers actifs',
                  '${stats['activeBarbers'] ?? 0}/${stats['totalBarbers'] ?? 0}',
                  'En service',
                  Icons.group,
                  Colors.orange,
                ),
                _buildKpiCard(
                  'Note moyenne',
                  '${provider.barbershopInfo?['rating'] ?? 0}/5',
                  '${provider.barbershopInfo?['total_reviews'] ?? 0} avis',
                  Icons.star,
                  Colors.amber,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Services populaires
            _buildServicesSection(analytics),
          ],
        ),
      ),
    );
  }

  // TAB 2: REVENUS
  Widget _buildRevenueTab(OwnerProvider provider, Map<String, dynamic> stats, Map<String, dynamic> analytics) {
    // Filtrage période + total période
    final filteredMap = _filterRevenueByPeriod(analytics['revenueByDay'] ?? {});
    final periodTotal = filteredMap.values.fold<num>(0, (s, n) => s + n);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sélecteur de période
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildPeriodSelector('7J', _selectedPeriod == '7j'),
                _buildPeriodSelector('30J', _selectedPeriod == '30j'),
                _buildPeriodSelector('3M', _selectedPeriod == '3m'),
                _buildPeriodSelector('1A', _selectedPeriod == '1a'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Graphique des revenus
          Container(
            height: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
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
                      'Évolution des revenus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getPeriodLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Total période: ${NumberFormat('#,###').format(periodTotal)} F',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _buildRevenueChart(filteredMap),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Comparaison avec période précédente
          _buildComparisonCard(stats, analytics),

          const SizedBox(height: 20),

          // Répartition par service (camembert)
          _buildRevenueByService(provider, analytics),
        ],
      ),
    );
  }

  // TAB 3: PERFORMANCE
  Widget _buildPerformanceTab(OwnerProvider provider, Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance globale
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance globale',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircularIndicator(
                      'Occupation',
                      (stats['occupancyRate']?.toDouble() ?? 0),
                      100,
                      Colors.blue,
                    ),
                    _buildCircularIndicator(
                      'Satisfaction',
                      ((provider.barbershopInfo?['rating'] ?? 0) * 20).toDouble(),
                      100,
                      Colors.green,
                    ),
                    _buildCircularIndicator(
                      'Fidélité',
                      _calculateLoyaltyRate(provider),
                      100,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Performance par barbier
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Performance barbiers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ce mois',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // En-tête du tableau
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Barbier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(child: Text('Clients', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(child: Text('Revenus', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(child: Text('Moy/jour', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),

                // Données
                ...provider.barbers.map((barber) {
                  final barberStats = barber['stats'] ?? {};
                  return _buildBarberPerformanceRow(
                    barber['display_name'] ?? 'Barbier',
                    barberStats['monthClients'] ?? 0,
                    barberStats['monthRevenue'] ?? 0,
                    barber['is_available'] ?? false,
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Recommandations
          _buildRecommendations(stats, provider),
        ],
      ),
    );
  }

  // -------------------------
  // Helpers de période (NOUVEAU)
  // -------------------------
  /// Retourne la date de début selon la période sélectionnée
  DateTime _periodStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case '7j':
        return now.subtract(const Duration(days: 7));
      case '30j':
        return now.subtract(const Duration(days: 30));
      case '3m':
        return now.subtract(const Duration(days: 90)); // ~3 mois
      case '1a':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  /// Filtre revenueByDay (Map<String, num>) selon la période sélectionnée.
  /// Clés attendues: "YYYY-MM-DD" (ou ISO parseable).
  Map<String, num> _filterRevenueByPeriod(Map<String, dynamic> revenueByDayRaw) {
    final start = _periodStartDate();
    final filtered = <String, num>{};

    revenueByDayRaw.forEach((key, value) {
      if (value is num) {
        try {
          final d = DateTime.parse(key);
          if (!d.isBefore(start)) {
            filtered[key] = value;
          }
        } catch (_) {/* ignore */}
      } else if (value is int) {
        try {
          final d = DateTime.parse(key);
          if (!d.isBefore(start)) {
            filtered[key] = value.toDouble();
          }
        } catch (_) {/* ignore */}
      }
    });

    // Si vide après filtrage, renvoyer original (évite un graph vide si les données sont anciennes)
    if (filtered.isEmpty && revenueByDayRaw.isNotEmpty) {
      return revenueByDayRaw.map((k, v) => MapEntry(k, (v as num)));
    }
    return filtered;
  }

  // -------------------------
  // WIDGETS HELPERS
  // -------------------------
  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String mainValue, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mainValue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = label.toLowerCase()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> revenueData) {
    if (revenueData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text('Pas de données disponibles', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Tri des dates ASC pour l’affichage correct
    final entries = revenueData.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final spots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < entries.length; i++) {
      final value = (entries[i].value as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= entries.length) return const SizedBox.shrink();
                final date = DateTime.parse(entries[value.toInt()].key);
                return Text(
                  DateFormat('d/M').format(date),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppTheme.primaryColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.primaryColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(Map<String, dynamic> analytics) {
    final topServices = analytics['topServices'] as List? ?? [];

    if (topServices.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = topServices.fold<int>(0, (sum, s) => sum + ((s['count'] ?? 0) as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services les plus demandés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...topServices.take(5).map((service) {
            final count = (service['count'] ?? 0) as int;
            final percentage = total > 0 ? ((count / total) * 100).round() : 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${service['name']}', style: const TextStyle(fontSize: 13)),
                      Text(
                        '$count ($percentage%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 6,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(Map<String, dynamic> stats, Map<String, dynamic> analytics) {
    final currentMonth = (stats['monthRevenue'] ?? 0) as int;
    final previousMonth = (stats['previousMonthRevenue'] ?? (currentMonth * 0.8).round()) as int;
    final difference = currentMonth - previousMonth;
    final percentChange = previousMonth > 0 ? ((difference / previousMonth) * 100).round() : 0;
    final isPositive = difference >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparaison avec le mois dernier',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ce mois', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    '${NumberFormat('#,###').format(currentMonth)} F',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isPositive ? '+' : ''}$percentChange%',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Mois dernier', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    '${NumberFormat('#,###').format(previousMonth)} F',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====== PIE "Revenus par service" ======
  Widget _buildRevenueByService(OwnerProvider provider, Map<String, dynamic> analytics) {
    // On accepte plusieurs structures possibles :
    // - analytics['revenueByService'] : List<Map>{name, revenue} ou Map<String, num>
    // - fallback : analytics['topServices'] avec 'revenue' ou sinon 'count'
    final Map<String, num> revenueMap = {};

    final raw = analytics['revenueByService'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final name = (e['name'] ?? 'Service').toString();
          final value = (e['revenue'] ?? e['amount'] ?? e['total'] ?? e['sum'] ?? 0);
          if (value is num) {
            revenueMap[name] = (revenueMap[name] ?? 0) + value;
          }
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) revenueMap[k.toString()] = v;
      });
    }

    // Fallback si vide : utiliser topServices (en supposant 'revenue' sinon 'count')
    if (revenueMap.isEmpty && analytics['topServices'] is List) {
      for (final e in (analytics['topServices'] as List)) {
        if (e is Map) {
          final name = (e['name'] ?? 'Service').toString();
          final value = (e['revenue'] ?? e['count'] ?? 0);
          if (value is num) {
            revenueMap[name] = (revenueMap[name] ?? 0) + value;
          }
        }
      }
    }

    final total = revenueMap.values.fold<num>(0, (s, n) => s + n);
    final entries = revenueMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // top first

    if (entries.isEmpty || total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: const Center(child: Text('Aucune donnée de revenus par service')),
      );
    }

    final sections = _buildPieSections(entries, total);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenus par service',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 48,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Légende
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              final e = entries[i];
              final percent = (e.value / total * 100).round();
              return _legendDot(
                color: sections[i].color,
                label: '${e.key} — ${NumberFormat('#,###').format(e.value)} F ($percent%)',
              );
            }),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<MapEntry<String, num>> entries, num total) {
    final palette = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
      Colors.pink,
    ];
    final sections = <PieChartSectionData>[];

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final percent = total > 0 ? (e.value / total * 100) : 0.0;

      sections.add(
        PieChartSectionData(
          color: palette[i % palette.length],
          value: e.value.toDouble(),
          title: '${percent.toStringAsFixed(0)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  Widget _legendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
      ],
    );
  }
  // ====== FIN PIE ======

  Widget _buildCircularIndicator(String label, double value, double total, Color color) {
    final ratio = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final percentage = (ratio * 100).round();

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: ratio,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 8,
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBarberPerformanceRow(String name, int clients, int revenue, bool isActive) {
    final avgPerDay = revenue ~/ 30;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '$clients',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              NumberFormat('#,###').format(revenue),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              NumberFormat('#,###').format(avgPerDay),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(Map<String, dynamic> stats, OwnerProvider provider) {
    final recommendations = <Widget>[];

    if ((stats['occupancyRate'] ?? 0) < 50) {
      recommendations.add(_buildRecommendationCard(
        'Augmenter l\'occupation',
        'Votre taux d\'occupation est faible. Proposez des promos heures creuses ou des remises aux clients fidèles.',
        Icons.event_seat,
        Colors.orange,
      ));
    }

    if ((stats['cancelledToday'] ?? 0) > 2) {
      recommendations.add(_buildRecommendationCard(
        'Réduire les annulations',
        'Plusieurs annulations aujourd\'hui. Activez des rappels SMS/WhatsApp et une politique d’acompte.',
        Icons.cancel,
        Colors.red,
      ));
    }

    if (recommendations.isEmpty) {
      recommendations.add(_buildRecommendationCard(
        'Excellente performance',
        'Votre barbershop performe bien. Continuez ainsi !',
        Icons.thumb_up,
        Colors.green,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommandations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ...recommendations,
        ],
      ),
    );
  }

  // <<< Méthode manquante réintégrée >>>
  Widget _buildRecommendationCard(String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case '7j':
        return '7 derniers jours';
      case '30j':
        return '30 derniers jours';
      case '3m':
        return '3 derniers mois';
      case '1a':
        return 'Cette année';
      default:
        return 'Période';
    }
  }

  int _calculateWeekRevenue(Map<String, dynamic> analytics) {
    final revenueByDay = analytics['revenueByDay'] as Map? ?? {};
    if (revenueByDay.isEmpty) return 0;

    final entries = revenueByDay.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final last7 = entries.length <= 7 ? entries : entries.sublist(entries.length - 7);
    return last7.fold<int>(0, (sum, e) => sum + ((e.value ?? 0) as int));
  }

  int _calculateWeekClients(OwnerProvider provider) {
    // À implémenter avec vraie logique : approximation simple
    return (provider.dashboardStats['monthClients'] ?? 0) ~/ 4;
  }

  double _calculateLoyaltyRate(OwnerProvider provider) {
    // Placeholder : à remplacer par une vraie logique (ex: clients récurrents / total)
    return 65.0;
  }
}
