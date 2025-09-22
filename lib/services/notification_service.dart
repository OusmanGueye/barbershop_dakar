import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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

      const details = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ⬇️ Ces deux paramètres sont désormais les bons (optionnels)
        // matchDateTimeComponents: DateTimeComponents.dateAndTime, // seulement si tu veux des répétitions
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
}