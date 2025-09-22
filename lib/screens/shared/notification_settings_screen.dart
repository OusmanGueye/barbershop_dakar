import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _reservationReminders = true;
  bool _dayBeforeReminder = true;
  bool _twoHoursReminder = true;
  bool _thirtyMinReminder = true;
  bool _promotions = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await NotificationService.checkPermissions();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          if (!_hasPermission)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  const Icon(Icons.notifications_off, color: Colors.orange, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'Les notifications sont désactivées',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Activez les notifications pour ne pas manquer vos rendez-vous',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () async {
                      //await NotificationService.requestPermissions();
                      //_checkPermissions();
                    },
                    child: const Text('Activer les notifications'),
                  ),
                ],
              ),
            ),

          // Rappels de réservation
          SwitchListTile(
            title: const Text('Rappels de réservation'),
            subtitle: const Text('Recevoir des rappels pour vos rendez-vous'),
            value: _reservationReminders,
            onChanged: (value) {
              setState(() => _reservationReminders = value);
            },
          ),

          if (_reservationReminders) ...[
            CheckboxListTile(
              title: const Text('Rappel la veille'),
              subtitle: const Text('Notification à 18h la veille'),
              value: _dayBeforeReminder,
              onChanged: (value) {
                setState(() => _dayBeforeReminder = value!);
              },
              contentPadding: const EdgeInsets.only(left: 50, right: 20),
            ),
            CheckboxListTile(
              title: const Text('Rappel 2h avant'),
              subtitle: const Text('Notification 2 heures avant le RDV'),
              value: _twoHoursReminder,
              onChanged: (value) {
                setState(() => _twoHoursReminder = value!);
              },
              contentPadding: const EdgeInsets.only(left: 50, right: 20),
            ),
            CheckboxListTile(
              title: const Text('Rappel 30 min avant'),
              subtitle: const Text('Dernière notification avant le RDV'),
              value: _thirtyMinReminder,
              onChanged: (value) {
                setState(() => _thirtyMinReminder = value!);
              },
              contentPadding: const EdgeInsets.only(left: 50, right: 20),
            ),
          ],

          const Divider(),

          // Promotions
          SwitchListTile(
            title: const Text('Promotions et offres'),
            subtitle: const Text('Recevoir les offres spéciales'),
            value: _promotions,
            onChanged: (value) {
              setState(() => _promotions = value);
            },
          ),
        ],
      ),
    );
  }
}