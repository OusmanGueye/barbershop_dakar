import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../providers/barber_provider.dart';

class BarberScheduleScreen extends StatefulWidget {
  const BarberScheduleScreen({super.key});

  @override
  State<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<BarberScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final provider = context.read<BarberProvider>();

    // Charger les données d'aujourd'hui
    await provider.loadReservationsByDate(DateTime.now());

    // Précharger les données du mois
    _preloadMonthData();
  }

  Future<void> _preloadMonthData() async {
    setState(() => _isPreloading = true);

    final provider = context.read<BarberProvider>();
    final now = DateTime.now();
    final daysToPreload = <DateTime>[];

    // Précharger 15 jours autour d'aujourd'hui
    for (int i = -7; i <= 7; i++) {
      final date = now.add(Duration(days: i));
      daysToPreload.add(date);
    }

    await provider.preloadDays(daysToPreload);

    if (mounted) {
      setState(() => _isPreloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barberProvider = context.watch<BarberProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mon Planning'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (_isPreloading)
            Container(
              margin: const EdgeInsets.all(8),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(_calendarFormat == CalendarFormat.week
                ? Icons.calendar_view_month
                : Icons.calendar_view_week),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.week
                    ? CalendarFormat.month
                    : CalendarFormat.week;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshCurrentDay(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendrier amélioré
          Container(
            color: Colors.white,
            child: TableCalendar<String>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              locale: 'fr_FR',
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
// Dans barber_schedule_screen.dart, remplacez eventLoader par :
              eventLoader: (day) {
                // Version sécurisée temporaire
                try {
                  return barberProvider.getReservationsCountForDay(day);
                } catch (e) {
                  print('Erreur eventLoader: $e');
                  return [];
                }
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                // AJOUT : Style pour les jours avec événements
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primaryColor),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                barberProvider.loadReservationsByDate(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                // Précharger les données du nouveau mois
                _preloadMonthData();
              },
            ),
          ),

          const SizedBox(height: 10),

          // En-tête de la journée amélioré
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE d MMMM', 'fr').format(_selectedDay ?? DateTime.now()),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedDay != null && !isSameDay(_selectedDay, DateTime.now()))
                        Text(
                          _getDateDescription(_selectedDay!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${barberProvider.selectedDateReservations.length} RDV',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_calculateDayRevenue(barberProvider.selectedDateReservations)} FCFA',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Timeline des réservations améliorée
          Expanded(
            child: barberProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : barberProvider.selectedDateReservations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () => _refreshCurrentDay(),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: barberProvider.selectedDateReservations.length,
                itemBuilder: (context, index) {
                  final reservation = barberProvider.selectedDateReservations[index];
                  final isLast = index == barberProvider.selectedDateReservations.length - 1;
                  return _buildTimelineCard(reservation, barberProvider, isLast);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateDescription(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (difference == 0) return "Aujourd'hui";
    if (difference == 1) return "Demain";
    if (difference == -1) return "Hier";
    if (difference > 0) return "Dans $difference jours";
    return "Il y a ${difference.abs()} jours";
  }

  int _calculateDayRevenue(List<Map<String, dynamic>> reservations) {
    return reservations
        .where((r) => ['completed', 'confirmed', 'in_progress'].contains(r['status']))
        .fold(0, (sum, r) => sum + ((r['total_amount'] as num?) ?? 0).toInt());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'Aucune réservation',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSameDay(_selectedDay, DateTime.now())
                ? 'Vous n\'avez aucun rendez-vous aujourd\'hui'
                : 'Aucun rendez-vous prévu ce jour',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> reservation, BarberProvider provider, bool isLast) {
    final status = reservation['status'] ?? 'confirmed';
    final timeSlot = reservation['time_slot'] as String?;
    final formattedTime = timeSlot?.substring(0, 5) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline améliorée
          Column(
            children: [
              Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  formattedTime,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: Colors.grey[300],
                ),
            ],
          ),

          const SizedBox(width: 15),

          // Card améliorée
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border(
                  left: BorderSide(
                    color: _getStatusColor(status),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reservation['client']?['full_name'] ?? 'Client',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Informations du service
                  _buildInfoRow(Icons.content_cut, reservation['service']?['name'] ?? 'Service'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.timer, '${reservation['service']?['duration'] ?? 30} min'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.phone, reservation['client']?['phone'] ?? ''),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.attach_money, '${reservation['total_amount'] ?? 0} FCFA',
                      color: AppTheme.primaryColor),

                  if (reservation['notes'] != null && reservation['notes'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation['notes'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Actions selon le statut
                  _buildActionButtons(status, reservation['id'], provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? Colors.grey[600],
              fontSize: 13,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String status, String reservationId, BarberProvider provider) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Commencer', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green),
                  ),
                  onPressed: () => _handleAction('start', reservationId, provider),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Absent', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                  ),
                  onPressed: () => _handleAction('no_show', reservationId, provider),
                ),
              ),
            ],
          ),
        );

      case 'in_progress':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Terminer le service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _handleAction('complete', reservationId, provider),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleAction(String action, String reservationId, BarberProvider provider) async {
    bool success = false;
    String message = '';

    switch (action) {
      case 'start':
        success = await provider.startService(reservationId);
        message = success ? 'Service démarré' : 'Erreur lors du démarrage';
        break;
      case 'complete':
        success = await provider.completeReservation(reservationId);
        message = success ? 'Service terminé' : 'Erreur lors de la finalisation';
        break;
      case 'no_show':
        success = await provider.markNoShow(reservationId);
        message = success ? 'Client marqué absent' : 'Erreur lors de la mise à jour';
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _refreshCurrentDay() async {
    final provider = context.read<BarberProvider>();
    await provider.loadReservationsByDate(_selectedDay ?? DateTime.now());
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

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    String label;

    switch (status) {
      case 'completed':
        label = 'Terminé';
        break;
      case 'in_progress':
        label = 'En cours';
        break;
      case 'confirmed':
        label = 'Confirmé';
        break;
      case 'pending':
        label = 'En attente';
        break;
      case 'no_show':
        label = 'Absent';
        break;
      case 'cancelled':
        label = 'Annulé';
        break;
      default:
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
}