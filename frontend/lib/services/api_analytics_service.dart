import 'package:flutter/foundation.dart';
import '../models/fuel_allocation.dart';
import 'api_client.dart';

class FleetDriverBreakdown {
  final String driverId;
  final String driverName;
  final String? vehiclePlate;
  final double monthlyBudgetRwf;
  final double distanceKm;
  final int workingDays;
  final double baseRequirementL;
  final double bufferL;
  final double bufferPercent;
  final double extraFuelGrantedL;
  final double totalAvailableL;
  final double projectedCostRwf;
  final double consumedL;
  final double consumedCostRwf;
  final double percentConsumed;

  const FleetDriverBreakdown({
    required this.driverId,
    required this.driverName,
    this.vehiclePlate,
    required this.monthlyBudgetRwf,
    required this.distanceKm,
    required this.workingDays,
    required this.baseRequirementL,
    required this.bufferL,
    required this.bufferPercent,
    required this.extraFuelGrantedL,
    required this.totalAvailableL,
    required this.projectedCostRwf,
    required this.consumedL,
    required this.consumedCostRwf,
    required this.percentConsumed,
  });

  double get remainingL => (totalAvailableL - consumedL).clamp(0, double.infinity);
  double get consumedFraction => totalAvailableL > 0 ? (consumedL / totalAvailableL).clamp(0, 1) : 0;

  factory FleetDriverBreakdown.fromJson(Map<String, dynamic> json) {
    final alloc = json['allocation'] as Map<String, dynamic>?;
    return FleetDriverBreakdown(
      driverId: json['driverId'] as String,
      driverName: json['driverName'] as String,
      vehiclePlate: json['vehiclePlate'] as String?,
      monthlyBudgetRwf: (json['monthlyBudgetRwf'] as num?)?.toDouble() ?? 0,
      distanceKm: (alloc?['distanceKm'] as num?)?.toDouble() ?? 0,
      workingDays: (alloc?['workingDays'] as num?)?.toInt() ?? 0,
      baseRequirementL: (alloc?['baseRequirementL'] as num?)?.toDouble() ?? 0,
      bufferL: (alloc?['bufferL'] as num?)?.toDouble() ?? 0,
      bufferPercent: (alloc?['bufferPercent'] as num?)?.toDouble() ?? 20,
      extraFuelGrantedL: (alloc?['extraFuelGrantedL'] as num?)?.toDouble() ?? 0,
      totalAvailableL: (alloc?['totalAvailableL'] as num?)?.toDouble() ?? 0,
      projectedCostRwf: (alloc?['projectedCostRwf'] as num?)?.toDouble() ?? 0,
      consumedL: (json['consumedL'] as num?)?.toDouble() ?? 0,
      consumedCostRwf: (json['consumedCostRwf'] as num?)?.toDouble() ?? 0,
      percentConsumed: (json['percentConsumed'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FleetMonthlyTrend {
  final int year;
  final int month;
  final double totalQuantityL;
  final double totalCostRwf;

  const FleetMonthlyTrend({
    required this.year,
    required this.month,
    required this.totalQuantityL,
    required this.totalCostRwf,
  });

  static const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String get label => _months[month];

  factory FleetMonthlyTrend.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? {};
    return FleetMonthlyTrend(
      year: (period['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (period['month'] as num?)?.toInt() ?? DateTime.now().month,
      totalQuantityL: (json['totalQuantityL'] as num?)?.toDouble() ?? 0,
      totalCostRwf: (json['totalCostRwf'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FleetDeptBreakdown {
  final String departmentName;
  final double totalQuantityL;
  final double totalCostRwf;

  const FleetDeptBreakdown({
    required this.departmentName,
    required this.totalQuantityL,
    required this.totalCostRwf,
  });

  factory FleetDeptBreakdown.fromJson(Map<String, dynamic> json) => FleetDeptBreakdown(
        departmentName: json['departmentName'] as String? ?? 'Unknown',
        totalQuantityL: (json['totalQuantityL'] as num?)?.toDouble() ?? 0,
        totalCostRwf: (json['totalCostRwf'] as num?)?.toDouble() ?? 0,
      );
}

class FleetSummaryData {
  final int year;
  final int month;
  final int driverCount;
  final double totalAvailableL;
  final double totalProjectedCostRwf;
  final List<FleetMonthlyTrend> monthlyTrends;
  final List<FleetDeptBreakdown> fuelUsageByDepartment;
  final List<FleetDriverBreakdown> driverBreakdown;

  const FleetSummaryData({
    required this.year,
    required this.month,
    required this.driverCount,
    required this.totalAvailableL,
    required this.totalProjectedCostRwf,
    required this.monthlyTrends,
    required this.fuelUsageByDepartment,
    required this.driverBreakdown,
  });

  double get totalConsumedL => driverBreakdown.fold(0.0, (s, d) => s + d.consumedL);
  double get totalConsumedCostRwf => driverBreakdown.fold(0.0, (s, d) => s + d.consumedCostRwf);
  double get fleetPercentConsumed => totalAvailableL > 0 ? (totalConsumedL / totalAvailableL) * 100 : 0;

  factory FleetSummaryData.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? {};
    final alloc = json['allocationTotals'] as Map<String, dynamic>? ?? {};
    return FleetSummaryData(
      year: (period['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (period['month'] as num?)?.toInt() ?? DateTime.now().month,
      driverCount: (json['driverCount'] as num?)?.toInt() ?? 0,
      totalAvailableL: (alloc['totalAvailableL'] as num?)?.toDouble() ?? 0,
      totalProjectedCostRwf: (alloc['projectedCostRwf'] as num?)?.toDouble() ?? 0,
      monthlyTrends: ((json['monthlyTrends'] as List?) ?? [])
          .map((e) => FleetMonthlyTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      fuelUsageByDepartment: ((json['fuelUsageByDepartment'] as List?) ?? [])
          .map((e) => FleetDeptBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      driverBreakdown: ((json['driverBreakdown'] as List?) ?? [])
          .map((e) => FleetDriverBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiAnalyticsService extends ChangeNotifier {
  FuelAllocationData? _myAllocation;
  double _myConsumedL = 0;
  double _myConsumedCostRwf = 0;
  FleetSummaryData? _fleetSummary;
  bool _loading = false;

  FuelAllocationData? get myAllocation => _myAllocation;
  double get myConsumedL => _myConsumedL;
  double get myConsumedCostRwf => _myConsumedCostRwf;
  FleetSummaryData? get fleetSummary => _fleetSummary;
  bool get loading => _loading;

  double get myPercentConsumed {
    final total = _myAllocation?.totalAvailableL ?? 0;
    return total > 0 ? (_myConsumedL / total) * 100 : 0;
  }

  double get myRemainingL {
    final total = _myAllocation?.totalAvailableL ?? 0;
    return (total - _myConsumedL).clamp(0, double.infinity);
  }

  Future<void> fetchMyData({int? year, int? month}) async {
    final query = <String, String>{};
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString();

    await Future.wait([
      ApiClient.instance.get('/allocations/me/current').then((r) {
        final data = r['data'];
        if (data != null) {
          _myAllocation = FuelAllocationData.fromJson(data as Map<String, dynamic>);
        }
      }).catchError((_) {}),
      ApiClient.instance.get('/analytics/drivers/me/summary', query: query).then((r) {
        final data = r['data'] as Map<String, dynamic>?;
        if (data != null) {
          final txns = (data['fuelTransactions'] as List?) ?? [];
          double consumed = 0;
          double cost = 0;
          for (final t in txns) {
            consumed += (t['totalQuantityL'] as num?)?.toDouble() ?? 0;
            cost += (t['totalCostRwf'] as num?)?.toDouble() ?? 0;
          }
          _myConsumedL = consumed;
          _myConsumedCostRwf = cost;
        }
      }).catchError((_) {}),
    ]);

    notifyListeners();
  }

  Future<void> fetchFleetSummary({int? year, int? month}) async {
    _loading = true;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (year != null) query['year'] = year.toString();
      if (month != null) query['month'] = month.toString();
      final r = await ApiClient.instance.get('/analytics/fleet/summary', query: query);
      final data = r['data'] as Map<String, dynamic>? ?? {};
      _fleetSummary = FleetSummaryData.fromJson(data);
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
