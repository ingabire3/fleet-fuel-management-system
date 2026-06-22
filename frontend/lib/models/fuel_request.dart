import 'package:flutter/material.dart';
import '../utils/constants.dart';

class FuelRequest {
  final String id;
  final String vehicleId;
  final String driverId;
  final String? driverName;
  final String? vehiclePlate;
  final double requestedQuantityL;
  final String? purpose;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final double? unitPriceRwf;
  final DateTime createdAt;

  FuelRequest({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    this.driverName,
    this.vehiclePlate,
    required this.requestedQuantityL,
    this.purpose,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.unitPriceRwf,
    required this.createdAt,
  });

  factory FuelRequest.fromJson(Map<String, dynamic> json) => FuelRequest(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String? ?? json['vehicle_id'] as String? ?? '',
        driverId: json['driverId'] as String? ?? json['driver_id'] as String? ?? '',
        driverName: json['driver'] != null
            ? (json['driver'] as Map<String, dynamic>)['fullName'] as String?
            : json['profiles'] != null
            ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
        vehiclePlate: json['vehicle'] != null
            ? (json['vehicle'] as Map<String, dynamic>)['plateNumber'] as String?
            : json['vehicles'] != null
            ? (json['vehicles'] as Map<String, dynamic>)['plate_number'] as String?
            : null,
        requestedQuantityL: _parseNum(json['requestedQuantityL'] ?? json['requested_quantity_l']) ?? 0,
        purpose: json['purpose'] as String?,
        status: _normalizeStatus(json['status'] as String? ?? 'PENDING'),
        approvedBy: json['finalDecisionById'] as String? ?? json['approved_by'] as String?,
        approvedAt: (json['finalDecisionAt'] ?? json['approved_at']) != null
            ? DateTime.parse((json['finalDecisionAt'] ?? json['approved_at']) as String)
            : null,
        rejectionReason: json['rejectionReason'] as String? ?? json['rejection_reason'] as String?,
        unitPriceRwf: _parseNum(json['unitPriceRwf'] ?? json['unit_price_rwf']),
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  static double? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static String _normalizeStatus(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return 'pending';
      case 'FLEET_MANAGER_APPROVED': return 'fm_approved';
      case 'FLEET_MANAGER_REJECTED': return 'rejected';
      case 'FINANCE_APPROVED': return 'approved';
      case 'FINANCE_REJECTED': return 'rejected';
      case 'CANCELLED': return 'cancelled';
      default: return s.toLowerCase();
    }
  }

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'requested_quantity_l': requestedQuantityL,
        'purpose': purpose,
        'status': status,
      };

  double get totalCostRwf =>
      unitPriceRwf != null ? requestedQuantityL * unitPriceRwf! : 0;

  Color get statusColor {
    switch (status) {
      case 'approved':
        return AppConstants.fuelGood;
      case 'fm_approved':
        return AppConstants.fuelGood;
      case 'rejected':
      case 'cancelled':
        return AppConstants.severityCritical;
      default:
        return AppConstants.severityMedium;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'fm_approved': return 'FM Approved';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'cancelled': return 'Cancelled';
      default: return status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status;
    }
  }
}
