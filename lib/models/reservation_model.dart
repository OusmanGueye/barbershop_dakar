import 'barbershop_model.dart';
import 'service_model.dart';
import 'user_model.dart';

class ReservationModel {
  final String id;
  final String clientId;
  final String barbershopId;
  final String? barberId;
  final String serviceId;
  final DateTime date;
  final String timeSlot;
  final String? endTime;
  final String status;
  final String? paymentMethod;
  final String paymentStatus;
  final int? totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optionnel, pour affichage)
  final BarbershopModel? barbershop;
  final ServiceModel? service;
  final UserModel? client;

  ReservationModel({
    required this.id,
    required this.clientId,
    required this.barbershopId,
    this.barberId,
    required this.serviceId,
    required this.date,
    required this.timeSlot,
    this.endTime,
    this.status = 'pending',
    this.paymentMethod,
    this.paymentStatus = 'pending',
    this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.barbershop,
    this.service,
    this.client,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'],
      clientId: json['client_id'],
      barbershopId: json['barbershop_id'],
      barberId: json['barber_id'],
      serviceId: json['service_id'],
      date: DateTime.parse(json['date']),
      timeSlot: json['time_slot'],
      endTime: json['end_time'],
      status: json['status'] ?? 'pending',
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'] ?? 'pending',
      totalAmount: json['total_amount'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      barbershop: json['barbershop'] != null
          ? BarbershopModel.fromJson(json['barbershop'])
          : null,
      service: json['service'] != null
          ? ServiceModel.fromJson(json['service'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'barbershop_id': barbershopId,
      'barber_id': barberId,
      'service_id': serviceId,
      'date': date.toIso8601String(),
      'time_slot': timeSlot,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'total_amount': totalAmount,
      'notes': notes,
    };
  }

  bool get isUpcoming {
    try {
      // Créer la DateTime complète avec date + heure
      final timeParts = timeSlot.split(':');
      final reservationDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]), // heure
        int.parse(timeParts[1]), // minutes
      );

      return reservationDateTime.isAfter(DateTime.now());
    } catch (e) {
      // Fallback en cas d'erreur de parsing
      print('Erreur parsing timeSlot: $timeSlot - $e');
      return date.isAfter(DateTime.now().subtract(Duration(days: 1)));
    }
  }

  bool get isPast {
    return !isUpcoming;
  }

  bool get canCancel {
    // Peut annuler si c'est à venir et le statut le permet
    return isUpcoming && (status == 'pending' || status == 'confirmed');
  }

}