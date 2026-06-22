import 'package:flutter/material.dart';
import '../utils/constants.dart';

class Vehicle {
  final String id;
  final String plateNumber;
  final String make;
  final String model;
  final int year;
  final String vehicleType;
  final String fuelType;
  final double tankCapacityL;
  final double currentFuelL;
  final double odometerKm;
  final String status;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? color;
  final String? notes;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleType,
    required this.fuelType,
    required this.tankCapacityL,
    required this.currentFuelL,
    required this.odometerKm,
    required this.status,
    this.assignedDriverId,
    this.assignedDriverName,
    this.color,
    this.notes,
  });

  @override
  bool operator ==(Object other) => other is Vehicle && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        plateNumber: json['plateNumber'] as String? ?? json['plate_number'] as String? ?? '',
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        year: (json['year'] as num?)?.toInt() ?? 2020,
        vehicleType: (json['vehicleType'] as String? ?? json['vehicle_type'] as String? ?? 'CAR').toLowerCase(),
        fuelType: (json['fuelType'] as String? ?? json['fuel_type'] as String? ?? 'PETROL').toLowerCase(),
        tankCapacityL: _parseNum(json['tankCapacityL'] ?? json['tank_capacity_l']) ?? 60.0,
        currentFuelL: _parseNum(json['currentFuelL'] ?? json['current_fuel_l']) ?? 0.0,
        odometerKm: _parseNum(json['odometerKm'] ?? json['odometer_km']) ?? 0.0,
        status: (json['status'] as String? ?? 'ACTIVE').toLowerCase(),
        assignedDriverId: json['assignedDriverId'] as String? ?? json['assigned_driver_id'] as String?,
        assignedDriverName: json['assignedDriver'] != null
            ? (json['assignedDriver'] as Map<String, dynamic>)['fullName'] as String?
            : json['profiles'] != null
            ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : json['assigned_driver_name'] as String?,
        color: json['color'] as String?,
        notes: json['notes'] as String?,
      );

  static double? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plate_number': plateNumber,
        'make': make,
        'model': model,
        'year': year,
        'vehicle_type': vehicleType,
        'fuel_type': fuelType,
        'tank_capacity_l': tankCapacityL,
        'current_fuel_l': currentFuelL,
        'odometer_km': odometerKm,
        'status': status,
        'assigned_driver_id': assignedDriverId,
        'color': color,
        'notes': notes,
      };

  double get fuelPercent =>
      tankCapacityL > 0 ? (currentFuelL / tankCapacityL).clamp(0.0, 1.0) : 0;

  Color get fuelColor {
    if (fuelPercent > 0.5) return AppConstants.fuelGood;
    if (fuelPercent > 0.2) return AppConstants.fuelWarning;
    return AppConstants.fuelCritical;
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return AppConstants.fuelGood;
      case 'maintenance':
        return AppConstants.severityMedium;
      default:
        return AppConstants.bottomBarUnselected;
    }
  }
}
