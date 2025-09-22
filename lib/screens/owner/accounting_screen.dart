import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<OwnerProvider>();
    final monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);

    await provider.loadBarbers();
    await provider.loadDashboardStats();
    await provider.generateMonthlyCommissions(monthStr);
    await provider.loadCommissionPayments(monthStr);
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = context.watch<OwnerProvider>();
    final payments = ownerProvider.commissionPayments;
    final barbershopName = ownerProvider.barbershopInfo?['name'] ?? 'Barbershop';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Comptabilité ${DateFormat('MMMM yyyy', 'fr').format(_selectedMonth)}'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
            color: AppTheme.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareFullReport(payments, barbershopName),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
      body: ownerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carte résumé
              _buildSummaryCard(payments),

              const SizedBox(height: 25),

              // Actions rapides
              _buildQuickActions(payments, barbershopName),

              const SizedBox(height: 20),

              // Titre section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Détail des commissions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${payments.where((p) => p['is_paid'] == true).length}/${payments.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 15),

              if (payments.isEmpty)
                _buildEmptyState()
              else
                ...payments.map((payment) {
                  return _buildPaymentCard(payment, barbershopName);
                }).toList(),

              const SizedBox(height: 20),

              // Boutons d'action globale
              _buildGlobalActions(payments),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> payments) {
    final totalRevenue = payments.fold<int>(0, (sum, p) => sum + (p['revenue'] ?? 0) as int);
    final totalCommissions = payments.fold<int>(0, (sum, p) => sum + (p['commission_amount'] ?? 0) as int);
    final netRevenue = totalRevenue - totalCommissions;
    final paidCommissions = payments.where((p) => p['is_paid'] == true)
        .fold<int>(0, (sum, p) => sum + (p['commission_amount'] ?? 0) as int);
    final unpaidCommissions = totalCommissions - paidCommissions;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Revenus',
                '${NumberFormat('#,###').format(totalRevenue)}',
                Icons.account_balance_wallet,
                Colors.white,
              ),
              _buildStatItem(
                'Commissions',
                '${NumberFormat('#,###').format(totalCommissions)}',
                Icons.money_off,
                Colors.yellow[300]!,
              ),
              _buildStatItem(
                'Net',
                '${NumberFormat('#,###').format(netRevenue)}',
                Icons.trending_up,
                Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payé:', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                    Text(
                      '${NumberFormat('#,###').format(paidCommissions)} F',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reste à payer:', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                    Text(
                      '${NumberFormat('#,###').format(unpaidCommissions)} F',
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
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

  Widget _buildQuickActions(List<Map<String, dynamic>> payments, String barbershopName) {
    final unpaidCount = payments.where((p) => p['is_paid'] != true).length;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            Icons.send,
            'Partager',
            Colors.blue,
                () => _shareFullReport(payments, barbershopName),
          ),
          _buildActionButton(
            Icons.check_circle,
            'Tout payer',
            Colors.green,
            unpaidCount > 0 ? () => _markAllAsPaid(payments) : null,
          ),
          _buildActionButton(
            Icons.download,
            'Exporter',
            Colors.orange,
                () => _exportToCSV(payments, barbershopName),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: onTap != null ? color : Colors.grey, size: 28),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, String barbershopName) {
    final barber = payment['barber'] ?? {};
    final isPaid = payment['is_paid'] ?? false;
    final commission = payment['commission_amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isPaid ? Colors.green : AppTheme.primaryColor,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isPaid ? Colors.green : AppTheme.primaryColor,
              child: Text(
                (barber['display_name'] ?? 'B')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (isPaid)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          barber['display_name'] ?? 'Barbier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isPaid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              '${NumberFormat('#,###').format(commission)} FCFA',
              style: TextStyle(
                color: isPaid ? Colors.grey : AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPaid) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Payé',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Détails
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetailItem('Clients', '${payment['clients_count'] ?? 0}'),
                    _buildDetailItem('Revenus', '${NumberFormat('#,###').format(payment['revenue'] ?? 0)} F'),
                    _buildDetailItem('Taux', '${payment['commission_rate'] ?? 30}%'),
                  ],
                ),

                if (isPaid) ...[
                  const Divider(height: 30),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Payé le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(payment['paid_at']))}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Méthode: ${payment['payment_method'] ?? 'Cash'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (payment['payment_reference'] != null)
                          Text(
                            'Référence: ${payment['payment_reference']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 15),

                // Actions
                Row(
                  children: [
                    if (!isPaid) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Marquer payé'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () => _showPaymentDialog(payment),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                        onPressed: () => _sendWhatsAppReceipt(payment, barbershopName),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 5),
        Text(
          '$value F',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 15),
            const Text(
              'Aucune commission ce mois',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Les commissions seront générées automatiquement',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalActions(List<Map<String, dynamic>> payments) {
    final allPaid = payments.every((p) => p['is_paid'] == true);

    return Column(
      children: [
        if (!allPaid)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marquer tout comme payé'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () => _markAllAsPaid(payments),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('Voir l\'historique'),
            onPressed: _showHistoryDialog,
          ),
        ),
      ],
    );
  }

  // MÉTHODES UTILITAIRES

  void _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _loadData();
      });
    }
  }

  void _showPaymentDialog(Map<String, dynamic> payment) {
    String paymentMethod = 'cash';
    final referenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer le paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Commission: ${NumberFormat('#,###').format(payment['commission_amount'] ?? 0)} FCFA',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Méthode de paiement',
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'wave', child: Text('Wave')),
                DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
              ],
              onChanged: (val) => paymentMethod = val ?? 'cash',
            ),
            const SizedBox(height: 15),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Référence (optionnel)',
                hintText: 'Numéro de transaction',
                prefixIcon: Icon(Icons.receipt),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);
              final success = await context.read<OwnerProvider>().markCommissionAsPaid(
                payment['barber_id'],
                monthStr,
                paymentMethod,
                referenceController.text.isNotEmpty ? referenceController.text : null,
              );

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paiement enregistré avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _sendWhatsAppReceipt(Map<String, dynamic> payment, String barbershopName) {
    final barber = payment['barber'] ?? {};
    final message = '''
🧾 *REÇU DE COMMISSION*
_${barbershopName}_

📅 Mois: ${DateFormat('MMMM yyyy', 'fr').format(_selectedMonth)}

👤 Barbier: ${barber['display_name']}
👥 Clients servis: ${payment['clients_count'] ?? 0}
💰 Revenus générés: ${NumberFormat('#,###').format(payment['revenue'] ?? 0)} FCFA
📊 Taux commission: ${payment['commission_rate'] ?? 30}%

💵 *COMMISSION: ${NumberFormat('#,###').format(payment['commission_amount'] ?? 0)} FCFA*

${payment['is_paid'] == true ? '✅ STATUT: Payé' : '⏳ STATUT: En attente'}
${payment['is_paid'] == true && payment['paid_at'] != null ? '📆 Payé le: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(payment['paid_at']))}' : ''}
${payment['payment_method'] != null ? '💳 Méthode: ${payment['payment_method']}' : ''}

Merci pour votre excellent travail! 🙏
    ''';

    Share.share(message);
  }

  void _shareFullReport(List<Map<String, dynamic>> payments, String barbershopName) {
    final totalCommissions = payments.fold<int>(0, (sum, p) => sum + (p['commission_amount'] ?? 0) as int);
    final paidCount = payments.where((p) => p['is_paid'] == true).length;

    final buffer = StringBuffer();
    buffer.writeln('📊 *RAPPORT COMPTABILITÉ*');
    buffer.writeln('_${barbershopName}_');
    buffer.writeln('📅 ${DateFormat('MMMM yyyy', 'fr').format(_selectedMonth)}');
    buffer.writeln('');
    buffer.writeln('📈 *RÉSUMÉ*');
    buffer.writeln('Total commissions: ${NumberFormat('#,###').format(totalCommissions)} FCFA');
    buffer.writeln('Statut: $paidCount/${payments.length} payés');
    buffer.writeln('');
    buffer.writeln('📋 *DÉTAILS PAR BARBIER*');

    for (var payment in payments) {
      final barber = payment['barber'] ?? {};
      final isPaid = payment['is_paid'] ?? false;
      buffer.writeln('');
      buffer.writeln('${barber['display_name']}: ${NumberFormat('#,###').format(payment['commission_amount'] ?? 0)} F ${isPaid ? "✅" : "⏳"}');
      buffer.writeln('  • Clients: ${payment['clients_count'] ?? 0}');
      buffer.writeln('  • Revenus: ${NumberFormat('#,###').format(payment['revenue'] ?? 0)} F');
    }

    Share.share(buffer.toString());
  }

  void _exportToCSV(List<Map<String, dynamic>> payments, String barbershopName) {
    final buffer = StringBuffer();

    // En-têtes CSV
    buffer.writeln('Barbier,Clients,Revenus,Taux,Commission,Statut,Date Paiement,Méthode');

    // Données
    for (var payment in payments) {
      final barber = payment['barber'] ?? {};
      buffer.writeln(
          '${barber['display_name']},${payment['clients_count']},${payment['revenue']},${payment['commission_rate']}%,${payment['commission_amount']},${payment['is_paid'] ? "Payé" : "En attente"},${payment['paid_at'] ?? ""},${payment['payment_method'] ?? ""}'
      );
    }

    Share.share(
      buffer.toString(),
      subject: 'Comptabilité_${DateFormat('yyyy-MM').format(_selectedMonth)}.csv',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export CSV prêt à partager'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _markAllAsPaid(List<Map<String, dynamic>> payments) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Marquer toutes les commissions comme payées ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final provider = context.read<OwnerProvider>();
              final monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);

              for (var payment in payments.where((p) => p['is_paid'] != true)) {
                await provider.markCommissionAsPaid(
                  payment['barber_id'],
                  monthStr,
                  'cash',
                  null,
                );
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toutes les commissions marquées comme payées'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    // Pour une v2, afficher l'historique des mois précédents
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Historique disponible dans la prochaine version'),
      ),
    );
  }
}