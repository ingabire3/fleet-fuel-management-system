import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../models/gps_trip.dart';
import '../models/profile.dart';
import '../models/vehicle.dart';
import '../utils/driver_analytics.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Budget-usage thresholds (% of monthly budget) that generate a one-time
/// notification per driver per month.
const List<int> _kBudgetThresholds = [50, 75, 90, 100];

/// Fleet-wide and per-driver AI fuel/budget analytics, computed from
/// `gps_trips` + `profiles` + `vehicles` (no DB-side aggregation needed).
class AnalyticsService extends ChangeNotifier {
  DriverInsights? _myInsights;
  List<GpsTrip> _myTripsThisMonth = [];

  List<DriverInsights> _fleetInsights = [];
  List<MonthlyTotal> _monthlyTotals = [];
  List<LocationFrequency> _locationFrequency = [];
  bool _loading = false;

  DriverInsights? get myInsights => _myInsights;
  List<GpsTrip> get myTripsThisMonth => _myTripsThisMonth;
  List<DriverInsights> get fleetInsights => _fleetInsights;
  List<MonthlyTotal> get monthlyTotals => _monthlyTotals;
  List<LocationFrequency> get locationFrequency => _locationFrequency;
  bool get loading => _loading;

  /// Single driver's budget/AI summary for the current month.
  Future<DriverInsights?> fetchMyInsights(
    String driverId, {
    required double Function(String fuelType) priceForFuelType,
    NotificationService? notificationService,
  }) async {
    if (DemoMode.active) return null;
    final client = SupabaseService.instance.client;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final profileData =
        await client.from('profiles').select().eq('id', driverId).maybeSingle();
    if (profileData == null) return null;
    final profile = Profile.fromJson(profileData);

    final vehicleData = await client
        .from('vehicles')
        .select()
        .eq('assigned_driver_id', driverId)
        .maybeSingle();
    final vehicle = vehicleData != null ? Vehicle.fromJson(vehicleData) : null;

    final tripsData = await client
        .from('gps_trips')
        .select()
        .eq('driver_id', driverId)
        .gte('started_at', monthStart.toIso8601String())
        .lte('started_at', now.toIso8601String())
        .order('started_at');
    final trips = (tripsData as List).map((e) => GpsTrip.fromJson(e)).toList();
    _myTripsThisMonth = trips;

    _myInsights = DriverAnalytics.compute(
      driverId: driverId,
      driverName: profile.fullName,
      budgetRwf: profile.monthlyBudgetRwf,
      vehicle: vehicle,
      tripsThisMonth: trips,
      priceForFuelType: priceForFuelType,
    );

    if (notificationService != null) {
      await _checkBudgetThresholds(
        notificationService: notificationService,
        recipientId: driverId,
        insights: _myInsights!,
        forSelf: true,
      );
    }

    notifyListeners();
    return _myInsights;
  }

  /// All drivers' summaries plus fleet-wide trend/route data, for the
  /// management dashboard.
  Future<void> fetchFleetInsights({
    required double Function(String fuelType) priceForFuelType,
    NotificationService? notificationService,
  }) async {
    if (DemoMode.active) return;
    _loading = true;
    notifyListeners();

    final client = SupabaseService.instance.client;
    final now = DateTime.now();

    final profilesData = await client
        .from('profiles')
        .select()
        .eq('role', 'driver')
        .order('full_name');
    final drivers =
        (profilesData as List).map((e) => Profile.fromJson(e)).toList();

    final vehiclesData = await client.from('vehicles').select();
    final vehicles =
        (vehiclesData as List).map((e) => Vehicle.fromJson(e)).toList();
    final vehicleByDriver = {
      for (final v in vehicles)
        if (v.assignedDriverId != null) v.assignedDriverId!: v
    };
    final vehiclesById = {for (final v in vehicles) v.id: v};

    // Paginate through all 2026 trips up to "now" — fleet history can exceed
    // PostgREST's default row cap.
    final allTrips = <GpsTrip>[];
    const pageSize = 1000;
    var start = 0;
    while (true) {
      final data = await client
          .from('gps_trips')
          .select()
          .gte('started_at', '2026-01-01T00:00:00Z')
          .lte('started_at', now.toIso8601String())
          .order('started_at')
          .range(start, start + pageSize - 1);
      final rows = data as List;
      allTrips.addAll(rows.map((e) => GpsTrip.fromJson(e)));
      if (rows.length < pageSize) break;
      start += pageSize;
    }

    final tripsThisMonthByDriver = <String, List<GpsTrip>>{};
    final tripsThisMonth = <GpsTrip>[];
    for (final t in allTrips) {
      final d = t.startedAt;
      if (d == null || d.year != now.year || d.month != now.month) continue;
      tripsThisMonth.add(t);
      final driverId = t.driverId;
      if (driverId == null) continue;
      tripsThisMonthByDriver.putIfAbsent(driverId, () => []).add(t);
    }

    _fleetInsights = drivers.map((profile) {
      final vehicle = vehicleByDriver[profile.id];
      final trips = tripsThisMonthByDriver[profile.id] ?? const <GpsTrip>[];
      return DriverAnalytics.compute(
        driverId: profile.id,
        driverName: profile.fullName,
        budgetRwf: profile.monthlyBudgetRwf,
        vehicle: vehicle,
        tripsThisMonth: trips,
        priceForFuelType: priceForFuelType,
      );
    }).toList();

    _monthlyTotals = DriverAnalytics.monthlyTotals(
      trips: allTrips,
      vehiclesById: vehiclesById,
      priceForFuelType: priceForFuelType,
    );

    _locationFrequency = DriverAnalytics.locationFrequency(tripsThisMonth);

    if (notificationService != null) {
      final managersData = await client
          .from('profiles')
          .select()
          .inFilter('role', ['fleet_manager', 'admin', 'super_admin']);
      final managers =
          (managersData as List).map((e) => Profile.fromJson(e)).toList();
      for (final insights in _fleetInsights) {
        for (final manager in managers) {
          await _checkBudgetThresholds(
            notificationService: notificationService,
            recipientId: manager.id,
            insights: insights,
            forSelf: false,
          );
        }
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// Inserts (at most once per driver/threshold/month) a budget-usage
  /// notification once `insights.percentUsed` crosses 50/75/90/100%.
  Future<void> _checkBudgetThresholds({
    required NotificationService notificationService,
    required String recipientId,
    required DriverInsights insights,
    required bool forSelf,
  }) async {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final pct = insights.percentUsed;

    for (final threshold in _kBudgetThresholds) {
      if (pct < threshold) continue;
      final exceeded = threshold == 100;
      final type = exceeded ? 'budget_exceeded' : 'budget_${threshold}_used';
      final priority = exceeded ? 'critical' : (threshold >= 90 ? 'high' : 'medium');
      final title = exceeded ? 'Budget Exceeded' : '$threshold% Budget Used';
      final message = forSelf
          ? (exceeded
              ? 'You have exceeded your monthly fuel budget (${pct.toStringAsFixed(0)}% used).'
              : 'You have used ${pct.toStringAsFixed(0)}% of your monthly fuel budget.')
          : (exceeded
              ? '${insights.driverName} has exceeded their monthly fuel budget (${pct.toStringAsFixed(0)}% used).'
              : '${insights.driverName} has used ${pct.toStringAsFixed(0)}% of their monthly fuel budget.');
      final dedupeKey = forSelf
          ? 'budget_${threshold}_$period'
          : 'budget_mgr_${insights.driverId}_${threshold}_$period';

      await notificationService.notifyOnce(
        userId: recipientId,
        title: title,
        message: message,
        type: type,
        category: 'budget',
        priority: priority,
        dedupeKey: dedupeKey,
      );
    }
  }
}
