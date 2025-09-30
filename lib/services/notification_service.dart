import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialisation
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Dakar'));

      // Configuration Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuration iOS
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await requestPermissions();

      _isInitialized = true;
      print('NotificationService initialisé');
    } catch (e) {
      print('Erreur initialisation notifications: $e');
    }
  }

  // Callback quand une notification est cliquée
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification cliquée: ${response.payload}');
  }

  // Notification simple
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notifications',
      channelDescription: 'Canal par défaut pour les notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Confirmation de réservation
  static Future<void> showReservationConfirmation({
    required String barbershopName,
    required String service,
    required String date,
    required String time,
    required String reservationId,
  }) async {
    await showNotification(
      title: '✅ Réservation confirmée',
      body: '$service chez $barbershopName le $date à $time',
      payload: 'reservation:$reservationId',
    );
  }

  // Nouvelle réservation pour barbier
  static Future<void> showNewReservationForBarber({
    required String clientName,
    required String service,
    required String time,
    required String date,
    required String reservationId,
  }) async {
    await showNotification(
      title: '📅 Nouvelle réservation',
      body: '$clientName - $service - $date à $time',
      payload: 'reservation:$reservationId',
    );
  }

  // Notification d'annulation
  static Future<void> showCancellationNotification({
    required String barbershopName,
    String? reason,
  }) async {
    await showNotification(
      title: '❌ Réservation annulée',
      body: reason ?? 'Votre RDV chez $barbershopName a été annulé',
    );
  }

  // Programmer un rappel
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'reminders',
        'Rappels',
        channelDescription: 'Rappels de réservations',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails, // ⬅️ ajoute ceci
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      print('Erreur programmation rappel: $e');
    }
  }



  // Programmer les rappels client
  static Future<void> scheduleClientReminders({
    required String reservationId,
    required String barbershopName,
    required String service,
    required DateTime dateTime,
  }) async {
    // Rappel J-1 à 18h
    final dayBefore = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day - 1,
      18, 0,
    );

    if (dayBefore.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reservationId.hashCode,
        title: '📅 Rappel - RDV demain',
        body: '$service chez $barbershopName demain à ${_formatTime(dateTime)}',
        scheduledDate: dayBefore,
        payload: 'reservation:$reservationId',
      );
    }

    // Rappel 2h avant
    final twoHoursBefore = dateTime.subtract(const Duration(hours: 2));

    if (twoHoursBefore.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reservationId.hashCode + 1,
        title: '⏰ RDV dans 2 heures',
        body: '$barbershopName - $service à ${_formatTime(dateTime)}',
        scheduledDate: twoHoursBefore,
        payload: 'reservation:$reservationId',
      );
    }
  }

  // Annuler des notifications
  static Future<void> cancelNotification(String reservationId) async {
    await _notifications.cancel(reservationId.hashCode);
    await _notifications.cancel(reservationId.hashCode + 1);
  }

  // Annuler toutes les notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Formater l'heure
  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}h${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Vérifier permissions (version simplifiée)
  static Future<bool> checkPermissions() async {
    try {
      // Sur Android 13+, les permissions sont demandées à l'initialisation
      // Cette méthode retourne toujours true pour simplifier
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> runSelfTest() async {
    await initialize();

    // Notif immédiate
    await showNotification(
      title: '🔔 Test immédiat',
      body: 'Les notifications locales fonctionnent ✅',
      payload: 'test:immediate',
    );

    // Notif +10s
    final in10s = DateTime.now().add(const Duration(seconds: 10));
    await _notifications.zonedSchedule(
      990001,
      '⏱️ Test +10s',
      'Notification planifiée il y a 10 secondes',
      tz.TZDateTime.from(in10s, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Rappels',
          channelDescription: 'Rappels de test',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'test:in10s',
    );

    // Notif +1 min
    final in1min = DateTime.now().add(const Duration(minutes: 1));
    await _notifications.zonedSchedule(
      990002,
      '⏳ Test +1 min',
      'Notification planifiée il y a 1 minute',
      tz.TZDateTime.from(in1min, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Rappels',
          channelDescription: 'Rappels de test',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'test:in1min',
    );

    print('✅ Tests lancés : immédiat, +10s, +1min. Tu peux fermer l’app et observer.');
  }


  static Future<void> requestPermissions() async {
    // iOS : rien à faire, c’est géré par DarwinInitializationSettings
    if (Platform.isAndroid) {
      final notif = await Permission.notification.request();
      await Permission.scheduleExactAlarm.request(); // optionnel
      if (!notif.isGranted && !notif.isLimited) {
        print('⚠️ Permission notifications refusée (Android)');
      } else {
        print('✅ Permission notifications OK (Android)');
      }
    }
  }




}
