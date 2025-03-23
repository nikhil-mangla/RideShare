import 'package:corider/models/types/requested_offer_status.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

class RideOfferModel {
  String id;
  String driverId;
  String vehicleId;
  TimeOfDay? proposedLeaveTime;
  TimeOfDay? proposedBackTime;
  Map<String, RequestedOfferStatus> requestedUserIds;
  List<int> proposedWeekdays;
  String driverLocationName;
  LatLng driverLocation;
  final LatLng destinationLocation;
  final String? destinationLocationName;
  double price;
  String additionalDetails;
  final DateTime? createdAt;

  RideOfferModel({
    String? id,
    required this.createdAt,
    required this.driverId,
    required this.vehicleId,
    required this.proposedLeaveTime,
    required this.proposedBackTime,
    this.requestedUserIds = const {},
    required this.proposedWeekdays,
    required this.driverLocationName,
    required this.driverLocation,
    required this.destinationLocation,
    this.destinationLocationName,
    required this.price,
    required this.additionalDetails,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverId': driverId,
        'vehicleId': vehicleId,
        'proposedLeaveTime': proposedLeaveTime != null
            ? '${proposedLeaveTime!.hour}:${proposedLeaveTime!.minute}'
            : null,
        'requestedUserIds': requestedUserIds.map((key, value) => MapEntry(key, value.index)),
        'proposedBackTime': proposedBackTime != null
            ? '${proposedBackTime!.hour}:${proposedBackTime!.minute}'
            : null,
        'proposedWeekdays': proposedWeekdays,
        'driverLocationName': driverLocationName,
        'driverLocation': {
          'latitude': driverLocation.latitude,
          'longitude': driverLocation.longitude,
        },
        'destinationLocation': {
          'latitude': destinationLocation.latitude,
          'longitude': destinationLocation.longitude,
        },
        'destinationLocationName': destinationLocationName,
        'price': price,
        'additionalDetails': additionalDetails,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory RideOfferModel.generateUnknown() {
    return RideOfferModel(
      createdAt: null,
      driverId: '',
      vehicleId: '',
      proposedLeaveTime: null,
      proposedBackTime: null,
      requestedUserIds: {},
      proposedWeekdays: [],
      driverLocationName: '',
      driverLocation: const LatLng(0, 0),
      destinationLocation: const LatLng(0, 0),
      price: 0,
      additionalDetails: '',
    );
  }

  factory RideOfferModel.fromJson(Map<String, dynamic> json) {
    // Helper function to parse LatLng with defaults
    LatLng parseLatLng(Map<String, dynamic>? locationData, {double defaultLat = 0.0, double defaultLng = 0.0}) {
      if (locationData == null) {
        return LatLng(defaultLat, defaultLng);
      }
      return LatLng(
        (locationData['latitude'] as num?)?.toDouble() ?? defaultLat,
        (locationData['longitude'] as num?)?.toDouble() ?? defaultLng,
      );
    }

    return RideOfferModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      driverId: json['driverId'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      proposedLeaveTime: json['proposedLeaveTime'] != null
          ? TimeOfDay(
              hour: int.tryParse((json['proposedLeaveTime'] as String).split(':')[0]) ?? 0,
              minute: int.tryParse((json['proposedLeaveTime'] as String).split(':')[1]) ?? 0,
            )
          : null,
      proposedBackTime: json['proposedBackTime'] != null
          ? TimeOfDay(
              hour: int.tryParse((json['proposedBackTime'] as String).split(':')[0]) ?? 0,
              minute: int.tryParse((json['proposedBackTime'] as String).split(':')[1]) ?? 0,
            )
          : null,
      requestedUserIds: json['requestedUserIds'] != null
          ? (json['requestedUserIds'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, RequestedOfferStatus.values[value as int]),
            )
          : {},
      proposedWeekdays: json['proposedWeekdays'] != null
          ? List<int>.from(json['proposedWeekdays'] as List<dynamic>)
          : [],
      driverLocationName: json['driverLocationName'] as String? ?? '',
      driverLocation: parseLatLng(json['driverLocation'] as Map<String, dynamic>?),
      destinationLocation: parseLatLng(json['destinationLocation'] as Map<String, dynamic>?),
      destinationLocationName: json['destinationLocationName'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      additionalDetails: json['additionalDetails'] as String? ?? '',
    );
  }
}