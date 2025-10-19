import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../config/supabase_config.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../providers/reservation_provider.dart';

class BookingScreen extends StatefulWidget {
  final BarbershopModel barbershop;
  final ServiceModel service;

  const BookingScreen({
    super.key,
    required this.barbershop,
    required this.service,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  String? _selectedBarberId;
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _barbers = [];
  Map<String, List<String>> _occupiedByBarber = {};
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadBarbers();
  }

  // Charger les barbiers du barbershop
  Future<void> _loadBarbers() async {
    try {
      // Charger les barbiers
      final response = await SupabaseConfig.client
          .from('barbers')
          .select()
          .eq('barbershop_id', widget.barbershop.id)
          .eq('invite_status', 'accepted')
          .eq('is_available', true);

      // Charger les avatars séparément pour chaque barbier
      final barbersWithAvatars = <Map<String, dynamic>>[];

      for (var barber in response) {
        final barberData = Map<String, dynamic>.from(barber);
        final userId = barber['user_id'];

        if (userId != null) {
          try {
            final userResponse = await SupabaseConfig.client
                .from('users')
                .select('avatar_url')
                .eq('id', userId)
                .maybeSingle();

            barberData['avatar_url'] = userResponse?['avatar_url'];
          } catch (e) {
            print('Erreur chargement avatar pour $userId: $e');
          }
        }

        barbersWithAvatars.add(barberData);
      }

      setState(() {
        _barbers = barbersWithAvatars;
        _selectedBarberId = 'any';
      });

      _loadAllOccupiedSlots();
    } catch (e) {
      print('Erreur chargement barbiers: $e');
    }
  }

  // Charger TOUS les créneaux occupés avec leurs plages complètes
  Future<void> _loadAllOccupiedSlots() async {
    setState(() => _isLoadingSlots = true);

    try {
      _occupiedByBarber = {};

      // Récupérer les réservations avec time_slot et end_time
      final response = await SupabaseConfig.client
          .from('reservations')
          .select('barber_id, time_slot, end_time')
          .eq('barbershop_id', widget.barbershop.id)
          .eq('date', _selectedDate.toIso8601String().split('T')[0])
          .inFilter('status', ['pending', 'confirmed', 'in_progress']);

      for (var reservation in response) {
        final barberId = reservation['barber_id'] as String;
        final startTime = reservation['time_slot'] as String;
        final endTime = reservation['end_time'] as String?;

        // Générer tous les créneaux occupés dans cette plage
        final occupiedSlots = _generateOccupiedSlotsInRange(startTime, endTime);

        if (!_occupiedByBarber.containsKey(barberId)) {
          _occupiedByBarber[barberId] = [];
        }
        _occupiedByBarber[barberId]!.addAll(occupiedSlots);
      }

      print('Créneaux occupés par barbier: $_occupiedByBarber');

    } catch (e) {
      print('Erreur chargement créneaux: $e');
    } finally {
      setState(() => _isLoadingSlots = false);
    }
  }

  // Générer tous les créneaux occupés dans une plage
  List<String> _generateOccupiedSlotsInRange(String startTime, String? endTime) {
    final slots = <String>[];

    try {
      final start = DateTime.parse('2024-01-01 $startTime');
      final end = endTime != null
          ? DateTime.parse('2024-01-01 $endTime')
          : start.add(Duration(minutes: widget.service.duration));

      var current = start;
      // CORRECTION : Utiliser isBefore au lieu de isAtOrBefore
      while (current.isBefore(end)) {
        final timeStr = '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}:00';
        slots.add(timeStr);
        current = current.add(const Duration(minutes: 30));
      }

      print('DEBUG: Service de ${widget.service.duration}min à $startTime occupe: $slots');

    } catch (e) {
      print('Erreur génération créneaux: $e');
      slots.add(startTime.length == 5 ? '$startTime:00' : startTime);
    }

    return slots;
  }

  // Vérifier si un créneau est disponible (vérifie toute la durée du service)
  bool _isSlotAvailable(String timeSlot) {
    if (_selectedBarberId == null) return false;

    // Calculer tous les créneaux que ce service occuperait
    final requiredSlots = _generateSlotsForService(timeSlot);

    if (_selectedBarberId == 'any') {
      // Pour "Premier disponible", vérifier qu'au moins un barbier est libre sur TOUTE la durée
      for (var barber in _barbers) {
        final barberId = barber['id'] as String;
        final occupied = _occupiedByBarber[barberId] ?? [];

        bool canAccommodateService = true;
        for (var requiredSlot in requiredSlots) {
          if (occupied.any((occupiedSlot) => _normalizeTime(occupiedSlot) == _normalizeTime(requiredSlot))) {
            canAccommodateService = false;
            break;
          }
        }

        if (canAccommodateService) return true;
      }
      return false;
    } else {
      // Pour un barbier spécifique, vérifier toute la durée
      final occupied = _occupiedByBarber[_selectedBarberId] ?? [];

      for (var requiredSlot in requiredSlots) {
        if (occupied.any((occupiedSlot) => _normalizeTime(occupiedSlot) == _normalizeTime(requiredSlot))) {
          return false;
        }
      }
      return true;
    }
  }

  // Générer tous les créneaux que ce service occuperait
  List<String> _generateSlotsForService(String startTime) {
    final slots = <String>[];
    final start = DateTime.parse('2024-01-01 $startTime:00');

    var current = start;
    final endTime = start.add(Duration(minutes: widget.service.duration));

    while (current.isBefore(endTime)) {
      slots.add('${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}:00');
      current = current.add(const Duration(minutes: 30));
    }

    return slots;
  }

  String _normalizeTime(String time) {
    return time.length == 5 ? '$time:00' : time;
  }

  // Trouver un barbier disponible pour un créneau
  Future<String?> _findAvailableBarber(String timeSlot) async {
    await _loadAllOccupiedSlots();

    final requiredSlots = _generateSlotsForService(timeSlot);

    for (var barber in _barbers) {
      final barberId = barber['id'] as String;
      final occupied = _occupiedByBarber[barberId] ?? [];

      bool canAccommodateService = true;
      for (var requiredSlot in requiredSlots) {
        if (occupied.any((occupiedSlot) => _normalizeTime(occupiedSlot) == _normalizeTime(requiredSlot))) {
          canAccommodateService = false;
          break;
        }
      }

      if (canAccommodateService) return barberId;
    }
    return null;
  }

  // Vérifier si le créneau est toujours disponible (avant de confirmer)
  Future<bool> _verifySlotStillAvailable() async {
    await _loadAllOccupiedSlots();

    if (_selectedTime == null) return false;

    final requiredSlots = _generateSlotsForService(_selectedTime!);

    if (_selectedBarberId == 'any') {
      // Pour "Premier disponible", vérifier qu'au moins un barbier est libre
      for (var barber in _barbers) {
        final barberId = barber['id'] as String;
        final occupied = _occupiedByBarber[barberId] ?? [];

        bool canAccommodateService = true;
        for (var requiredSlot in requiredSlots) {
          if (occupied.any((occupiedSlot) => _normalizeTime(occupiedSlot) == _normalizeTime(requiredSlot))) {
            canAccommodateService = false;
            break;
          }
        }

        if (canAccommodateService) return true;
      }
      return false;
    } else {
      // Pour un barbier spécifique
      final occupied = _occupiedByBarber[_selectedBarberId] ?? [];

      for (var requiredSlot in requiredSlots) {
        if (occupied.any((occupiedSlot) => _normalizeTime(occupiedSlot) == _normalizeTime(requiredSlot))) {
          return false;
        }
      }
      return true;
    }
  }

  // Générer les créneaux disponibles
  List<String> _generateTimeSlots() {
    List<String> slots = [];
    final openTime = widget.barbershop.openingTime ?? '08:00';
    final closeTime = widget.barbershop.closingTime ?? '20:00';

    final openHour = int.parse(openTime.split(':')[0]);
    final closeHour = int.parse(closeTime.split(':')[0]);

    for (int hour = openHour; hour < closeHour; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      slots.add('${hour.toString().padLeft(2, '0')}:30');
    }

    return slots;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = _generateTimeSlots();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Réservation'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Récapitulatif service
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.barbershop.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.content_cut,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.service.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                    widget.service.formattedDuration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    widget.service.formattedPrice,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Étape 1: Sélection date
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Choisir une date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 30,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final isSelected = _selectedDate.day == date.day &&
                            _selectedDate.month == date.month;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              _selectedTime = null;
                            });
                            _loadAllOccupiedSlots();
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE', 'fr').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  DateFormat('MMM', 'fr').format(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Étape 2: Sélection barbier
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Choisir un barbier',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Option "Premier disponible"
                  _buildBarberOption(
                    id: 'any',
                    name: 'Premier disponible',
                    subtitle: 'Le premier barbier disponible sera assigné',
                    icon: Icons.schedule,
                    isRecommended: true,
                  ),

                  const SizedBox(height: 10),

                  // Liste des barbiers
                  if (_barbers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucun barbier disponible'),
                      ),
                    )
                  else
                    ..._barbers.map((barber) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildBarberOption(
                        id: barber['id'],
                        name: barber['display_name'] ?? 'Barbier',
                        subtitle: barber['bio'] ?? 'Barbier professionnel',
                        rating: (barber['rating'] ?? 0.0).toDouble(),
                        avatarUrl: barber['avatar_url'], // ⬅️ Direct, pas de nested
                      ),
                    )).toList(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Étape 3: Sélection heure
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _selectedBarberId != null
                              ? AppTheme.primaryColor
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Choisir un créneau',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingSlots)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  if (_selectedBarberId == null)
                    Center(
                      child: Text(
                        'Veuillez d\'abord sélectionner un barbier',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else if (_isLoadingSlots)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2,
                      ),
                      itemCount: timeSlots.length,
                      itemBuilder: (context, index) {
                        final time = timeSlots[index];
                        final isSelected = _selectedTime == time;
                        final isAvailable = _isSlotAvailable(time);

                        return GestureDetector(
                          onTap: isAvailable
                              ? () {
                            setState(() {
                              _selectedTime = isSelected ? null : time;
                            });
                          }
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : !isAvailable
                                  ? Colors.red[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : !isAvailable
                                    ? Colors.red[200]!
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : !isAvailable
                                          ? Colors.red[400]
                                          : Colors.black,
                                    ),
                                  ),
                                  if (!isAvailable)
                                    Text(
                                      'Occupé',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.red[400],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notes
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes (optionnel)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Précisions sur votre coupe, allergies, etc.',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // Bouton confirmer
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
            onPressed: _selectedTime != null && _selectedBarberId != null
                ? () => _showConfirmationDialog()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              _selectedTime != null && _selectedBarberId != null
                  ? 'Confirmer la réservation'
                  : 'Veuillez compléter tous les champs',
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

  Widget _buildBarberOption({
    required String id,
    required String name,
    required String subtitle,
    double? rating,
    IconData? icon,
    bool isRecommended = false,
    String? avatarUrl,
  }) {
    final isSelected = _selectedBarberId == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBarberId = id;
          _selectedTime = null;
        });
        _loadAllOccupiedSlots();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Photo du barbier ou icône par défaut
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      icon ?? Icons.person,
                      color: AppTheme.primaryColor,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                ),
              )
                  : Icon(
                icon ?? Icons.person,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Recommandé',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rating != null && rating > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
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
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }


  void _showConfirmationDialog() async {
    // Si "Premier disponible", trouver un barbier
    String? finalBarberId = _selectedBarberId;
    String barberName = 'Premier disponible';

    if (_selectedBarberId == 'any') {
      finalBarberId = await _findAvailableBarber(_selectedTime!);
      if (finalBarberId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun barbier disponible pour ce créneau'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // Obtenir le nom du barbier assigné
      final barber = _barbers.firstWhere((b) => b['id'] == finalBarberId);
      barberName = barber['display_name'] ?? 'Barbier assigné';
    } else {
      final barber = _barbers.firstWhere((b) => b['id'] == _selectedBarberId);
      barberName = barber['display_name'] ?? 'Barbier';
    }

    // Calculer l'heure de fin
    final endTime = DateTime.parse('${_selectedDate.toIso8601String().split('T')[0]} $_selectedTime:00')
        .add(Duration(minutes: widget.service.duration));

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Confirmer la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('Service', widget.service.name),
            _buildConfirmRow('Barbier', barberName),
            _buildConfirmRow('Date', DateFormat('EEEE d MMMM', 'fr').format(_selectedDate)),
            _buildConfirmRow('Heure', '$_selectedTime - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'),
            _buildConfirmRow('Durée', '${widget.service.duration} minutes'),
            _buildConfirmRow('Prix', widget.service.formattedPrice),
            if (_notesController.text.isNotEmpty)
              _buildConfirmRow('Notes', _notesController.text),
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

              // Afficher un loader
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loaderContext) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              // VÉRIFICATION IMPORTANTE : Le créneau est-il toujours disponible ?
              final stillAvailable = await _verifySlotStillAvailable();

              if (!stillAvailable) {
                Navigator.pop(context); // Fermer le loader
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ce créneau vient d\'être réservé par quelqu\'un d\'autre'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                _loadAllOccupiedSlots();
                return;
              }

              // Si c'est "Premier disponible", re-vérifier le barbier
              if (_selectedBarberId == 'any') {
                finalBarberId = await _findAvailableBarber(_selectedTime!);
                if (finalBarberId == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Plus aucun barbier disponible pour ce créneau'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _loadAllOccupiedSlots();
                  return;
                }
              }

              // Créer la réservation
              final reservationProvider = Provider.of<ReservationProvider>(
                  context,
                  listen: false
              );

              final success = await reservationProvider.createReservation(
                barbershopId: widget.barbershop.id,
                barberId: finalBarberId!,
                serviceId: widget.service.id,
                date: _selectedDate,
                timeSlot: _selectedTime!,
                totalAmount: widget.service.price,
                serviceDuration: widget.service.duration,
                notes: _notesController.text.isNotEmpty ? _notesController.text : null,
              );

              if (!mounted) return;

              Navigator.pop(context); // Fermer le loader

              if (success) {
                _showSuccessDialog(barberName);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        reservationProvider.errorMessage ??
                            'Erreur lors de la création de la réservation'
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                _loadAllOccupiedSlots();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String barberName) {
    final endTime = DateTime.parse('${_selectedDate.toIso8601String().split('T')[0]} $_selectedTime:00')
        .add(Duration(minutes: widget.service.duration));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Réservation confirmée !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Votre réservation avec $barberName pour le ${DateFormat('d MMMM', 'fr').format(_selectedDate)} de $_selectedTime à ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')} a été confirmée.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous recevrez un rappel avant votre rendez-vous',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialogue succès
              Navigator.pop(context); // Retour booking
              Navigator.pop(context); // Retour detail
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
