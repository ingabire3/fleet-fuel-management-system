import 'package:flutter/material.dart';
import '../models/gps_trip.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';

/// Working days assumed per month for end-of-month projections (matches the
/// fleet's Mon-Sat schedule).
const int kWorkingDaysPerMonth = 22;

enum DriverCategory { efficient, normal, highConsumption, suspicious }

extension DriverCategoryX on DriverCategory {
  String get label {
    switch (this) {
      case DriverCategory.efficient:
        return 'Efficient User';
      case DriverCategory.normal:
        return 'Normal User';
      case DriverCategory.highConsumption:
        return 'High Consumption';
      case DriverCategory.suspicious:
        return 'Suspicious User';
    }
  }

  Color get color {
    switch (this) {
      case DriverCategory.efficient:
        return AppConstants.fuelGood;
      case DriverCategory.normal:
        return AppConstants.severityLow;
      case DriverCategory.highConsumption:
        return AppConstants.severityMedium;
      case DriverCategory.suspicious:
        return AppConstants.severityCritical;
    }
  }

  String get recommendation {
    switch (this) {
      case DriverCategory.efficient:
        return 'Great fuel discipline — keep using these routes.';
      case DriverCategory.normal:
        return 'Usage is within expected range. No action needed.';
      case DriverCategory.highConsumption:
        return 'Above-average consumption. Review route choices and idle time.';
      case DriverCategory.suspicious:
        return 'Investigate route deviations and fuel requests for this driver.';
    }
  }
}

/// Per-driver fuel/budget/AI summary for the current month.
class DriverInsights {
  final String driverId;
  final String driverName;
  final Vehicle? vehicle;

  final double budgetRwf;
  final double spentMonthToDate;
  final double remainingBudget;
  final double percentUsed;

  final int workingDaysCompleted;
  final double avgDailySpend;
  final double projectedMonthEndSpend;
  final double projectedBudgetPercent;

  final double totalDistanceMonth;
  final double totalFuelMonth;
  final double ratedEfficiency;
  final double actualEfficiency;
  final double efficiencyScore;
  final double riskScore;
  final DriverCategory category;

  DriverInsights({
    required this.driverId,
    required this.driverName,
    required this.vehicle,
    required this.budgetRwf,
    required this.spentMonthToDate,
    required this.remainingBudget,
    required this.percentUsed,
    required this.workingDaysCompleted,
    required this.avgDailySpend,
    required this.projectedMonthEndSpend,
    required this.projectedBudgetPercent,
    required this.totalDistanceMonth,
    required this.totalFuelMonth,
    required this.ratedEfficiency,
    required this.actualEfficiency,
    required this.efficiencyScore,
    required this.riskScore,
    required this.category,
  });

  String get recommendation => category.recommendation;
}

/// One fleet-wide month of trip activity (for trend charts).
class MonthlyTotal {
  final int month; // 1-12
  final double distanceKm;
  final double fuelL;
  final double costRwf;

  MonthlyTotal({
    required this.month,
    required this.distanceKm,
    required this.fuelL,
    required this.costRwf,
  });

  static const monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String get label => monthNames[month];
}

/// How often a named location appears as a trip origin/destination.
class LocationFrequency {
  final String name;
  final int count;
  LocationFrequency({required this.name, required this.count});
}

class DriverAnalytics {
  /// Builds the AI summary for one driver from their trips this month.
  static DriverInsights compute({
    required String driverId,
    required String driverName,
    required double budgetRwf,
    required Vehicle? vehicle,
    required List<GpsTrip> tripsThisMonth,
    required double Function(String fuelType) priceForFuelType,
  }) {
    double totalDistance = 0;
    double totalFuel = 0;
    final daysSeen = <String>{};

    for (final t in tripsThisMonth) {
      totalDistance += t.distanceKm ?? 0;
      totalFuel += t.fuelConsumedL ?? 0;
      final d = t.startedAt;
      if (d != null) {
        daysSeen.add('${d.year}-${d.month}-${d.day}');
      }
    }

    final fuelType = vehicle?.fuelType ?? 'petrol';
    final price = priceForFuelType(fuelType);
    final spent = totalFuel * price;
    final workingDays = daysSeen.length;
    final avgDaily = workingDays > 0 ? spent / workingDays : 0.0;
    final projected = avgDaily * kWorkingDaysPerMonth;
    final percentUsed = budgetRwf > 0 ? (spent / budgetRwf) * 100 : 0.0;
    final projectedPercent =
        budgetRwf > 0 ? (projected / budgetRwf) * 100 : 0.0;

    final ratedEff = vehicle != null && tripsThisMonth.isNotEmpty
        ? (tripsThisMonth.first.fuelEfficiency ?? 8.0)
        : (tripsThisMonth.isNotEmpty
            ? (tripsThisMonth.first.fuelEfficiency ?? 8.0)
            : 8.0);
    final actualEff = totalFuel > 0 ? totalDistance / totalFuel : ratedEff;
    final efficiencyScore =
        ratedEff > 0 ? ((actualEff / ratedEff) * 100).clamp(0, 150) : 100.0;

    final riskBase = (projectedPercent / 2).clamp(0, 100);
    final effPenalty =
        efficiencyScore < 100 ? (100 - efficiencyScore) * 0.5 : 0.0;
    final riskScore = (riskBase + effPenalty).clamp(0, 100).toDouble();

    DriverCategory category;
    if (projectedPercent > 130 || efficiencyScore < 60) {
      category = DriverCategory.suspicious;
    } else if (projectedPercent > 100 || efficiencyScore < 85) {
      category = DriverCategory.highConsumption;
    } else if (projectedPercent <= 75 && efficiencyScore >= 105) {
      category = DriverCategory.efficient;
    } else {
      category = DriverCategory.normal;
    }

    return DriverInsights(
      driverId: driverId,
      driverName: driverName,
      vehicle: vehicle,
      budgetRwf: budgetRwf,
      spentMonthToDate: spent,
      remainingBudget: budgetRwf - spent,
      percentUsed: percentUsed,
      workingDaysCompleted: workingDays,
      avgDailySpend: avgDaily,
      projectedMonthEndSpend: projected,
      projectedBudgetPercent: projectedPercent,
      totalDistanceMonth: totalDistance,
      totalFuelMonth: totalFuel,
      ratedEfficiency: ratedEff,
      actualEfficiency: actualEff,
      efficiencyScore: efficiencyScore.toDouble(),
      riskScore: riskScore,
      category: category,
    );
  }

  /// Fleet-wide Jan-Jun totals for the spending-trend chart.
  static List<MonthlyTotal> monthlyTotals({
    required List<GpsTrip> trips,
    required Map<String, Vehicle> vehiclesById,
    required double Function(String fuelType) priceForFuelType,
  }) {
    final byMonth = <int, MonthlyTotal>{};
    for (var m = 1; m <= 6; m++) {
      byMonth[m] = MonthlyTotal(month: m, distanceKm: 0, fuelL: 0, costRwf: 0);
    }
    for (final t in trips) {
      final started = t.startedAt;
      if (started == null || started.year != 2026) continue;
      final m = started.month;
      if (m < 1 || m > 6) continue;
      final vehicle = vehiclesById[t.vehicleId];
      final price = priceForFuelType(vehicle?.fuelType ?? 'petrol');
      final fuel = t.fuelConsumedL ?? 0;
      final existing = byMonth[m]!;
      byMonth[m] = MonthlyTotal(
        month: m,
        distanceKm: existing.distanceKm + (t.distanceKm ?? 0),
        fuelL: existing.fuelL + fuel,
        costRwf: existing.costRwf + fuel * price,
      );
    }
    return [for (var m = 1; m <= 6; m++) byMonth[m]!];
  }

  /// Most-visited named locations across the given trips (origin + destination).
  static List<LocationFrequency> locationFrequency(
    List<GpsTrip> trips, {
    int top = 8,
  }) {
    final counts = <String, int>{};
    for (final t in trips) {
      for (final name in [t.originName, t.destinationName]) {
        if (name == null || name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(top)
        .map((e) => LocationFrequency(name: e.key, count: e.value))
        .toList();
  }
}
