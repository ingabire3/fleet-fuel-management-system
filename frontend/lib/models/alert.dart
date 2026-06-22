import 'package:flutter/material.dart';
import '../utils/constants.dart';

class Alert {
  final String id;
  final String? vehicleId;
  final String? driverId;
  final String? tripId;
  final String? transactionId;
  final String alertType;
  final String severity;
  final String status;
  final String title;
  final String description;
  final double? aiConfidence;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  Alert({
    required this.id,
    this.vehicleId,
    this.driverId,
    this.tripId,
    this.transactionId,
    required this.alertType,
    required this.severity,
    required this.status,
    required this.title,
    required this.description,
    this.aiConfidence,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        vehicleId: json['vehicle_id'] as String?,
        driverId: json['driver_id'] as String?,
        tripId: json['trip_id'] as String?,
        transactionId: json['transaction_id'] as String?,
        alertType: json['alert_type'] as String? ?? 'unknown',
        severity: json['severity'] as String? ?? 'low',
        status: json['status'] as String? ?? 'open',
        title: json['title'] as String? ?? 'Alert',
        description: json['description'] as String? ?? '',
        aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
        resolvedBy: json['resolved_by'] as String?,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'trip_id': tripId,
        'transaction_id': transactionId,
        'alert_type': alertType,
        'severity': severity,
        'status': status,
        'title': title,
        'description': description,
        'ai_confidence': aiConfidence,
      };

  Color get severityColor {
    switch (severity) {
      case 'critical':
        return AppConstants.severityCritical;
      case 'high':
        return AppConstants.severityHigh;
      case 'medium':
        return AppConstants.severityMedium;
      case 'low':
        return AppConstants.severityLow;
      default:
        return AppConstants.severityResolved;
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case 'critical':
        return Icons.warning_rounded;
      case 'high':
        return Icons.error_outline_rounded;
      case 'medium':
        return Icons.info_outline_rounded;
      case 'low':
        return Icons.notifications_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get severityLabel {
    return severity[0].toUpperCase() + severity.substring(1);
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Open';
      case 'acknowledged':
        return 'Acknowledged';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }
}
