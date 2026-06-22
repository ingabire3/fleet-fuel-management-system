import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum NotificationCategory { fuelRequest, aiAlert, vehicle, budget }

extension NotificationCategoryX on NotificationCategory {
  static NotificationCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fuel_request':
        return NotificationCategory.fuelRequest;
      case 'vehicle':
        return NotificationCategory.vehicle;
      case 'budget':
        return NotificationCategory.budget;
      case 'ai_alert':
      default:
        return NotificationCategory.aiAlert;
    }
  }

  String get value {
    switch (this) {
      case NotificationCategory.fuelRequest:
        return 'fuel_request';
      case NotificationCategory.aiAlert:
        return 'ai_alert';
      case NotificationCategory.vehicle:
        return 'vehicle';
      case NotificationCategory.budget:
        return 'budget';
    }
  }

  String get label {
    switch (this) {
      case NotificationCategory.fuelRequest:
        return 'Fuel Requests';
      case NotificationCategory.aiAlert:
        return 'AI Alerts';
      case NotificationCategory.vehicle:
        return 'Vehicle';
      case NotificationCategory.budget:
        return 'Budget';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.fuelRequest:
        return Icons.local_gas_station_outlined;
      case NotificationCategory.aiAlert:
        return Icons.warning_amber_rounded;
      case NotificationCategory.vehicle:
        return Icons.directions_car_outlined;
      case NotificationCategory.budget:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final NotificationCategory category;
  final String priority;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    required this.priority,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: json['type'] as String? ?? '',
        category: NotificationCategoryX.fromString(
            (json['category'] as String? ?? 'AI_ALERT').toLowerCase()),
        priority: (json['priority'] as String? ?? 'MEDIUM').toLowerCase(),
        relatedId: json['relatedId'] as String? ?? json['related_id'] as String?,
        isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Color get priorityColor {
    switch (priority) {
      case 'critical':
        return AppConstants.severityCritical;
      case 'high':
        return AppConstants.severityHigh;
      case 'medium':
        return AppConstants.severityMedium;
      default:
        return AppConstants.severityLow;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }
}
