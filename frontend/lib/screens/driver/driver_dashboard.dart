import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_request_service.dart';
import '../../services/fuel_price_service.dart';
import '../../services/analytics_service.dart';
import '../../services/api_analytics_service.dart';
import '../../services/notification_service.dart';
import '../../models/fuel_allocation.dart';
import '../../models/gps_trip.dart';
import '../../models/vehicle.dart';
import '../../services/trip_service.dart';
import '../../utils/constants.dart';
import '../../utils/driver_analytics.dart';
import '../../widgets/sign_out_button.dart';
import '../notifications_screen.dart';
import 'fuel_request_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = context.read<AuthService>().currentUserId ?? '';
    final fuelSvc = context.read<FuelService>();
    final reqSvc = context.read<FuelRequestService>();
    final tripSvc = context.read<TripService>();
    final priceSvc = context.read<FuelPriceService>();
    final analyticsSvc = context.read<AnalyticsService>();
    final apiAnalytics = context.read<ApiAnalyticsService>();
    final notifSvc = context.read<NotificationService>();
    try {
      await Future.wait([
        fuelSvc.fetchVehicles(),
        reqSvc.fetchByDriver(uid),
        tripSvc.fetchTrips(),
        priceSvc.fetchCurrentPrices(),
      ]);
      if (uid.isNotEmpty) {
        await Future.wait([
          analyticsSvc.fetchMyInsights(uid,
              priceForFuelType: priceSvc.getPrice, notificationService: notifSvc),
          apiAnalytics.fetchMyData(),
          notifSvc.fetch(uid),
        ]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fuel = context.watch<FuelService>();
    final reqSvc = context.watch<FuelRequestService>();
    final tripSvc = context.watch<TripService>();
    final priceSvc = context.watch<FuelPriceService>();
    final insights = context.watch<AnalyticsService>().myInsights;
    final apiAnalytics = context.watch<ApiAnalyticsService>();
    final unreadNotifs = context.watch<NotificationService>().unreadCount;

    final name = auth.currentProfile?.fullName.split(' ').first ?? 'Driver';
    final uid = auth.currentUserId;

    // Vehicle assigned to this driver.
    final Vehicle? assignedVehicle = uid != null
        ? fuel.vehicles.where((v) => v.assignedDriverId == uid).firstOrNull
            ?? (fuel.vehicles.isNotEmpty ? fuel.vehicles.first : null)
        : null;

    final recentRequests = reqSvc.requests.take(3).toList();

    final now = DateTime.now();
    final monthTrips = uid != null
        ? tripSvc.trips
            .where((t) =>
                t.driverId == uid &&
                t.startedAt != null &&
                t.startedAt!.year == now.year &&
                t.startedAt!.month == now.month)
            .toList()
        : <GpsTrip>[];

    final recentTrips = monthTrips.take(3).toList();

    final totalKm = monthTrips.fold(0.0, (s, t) => s + (t.distanceKm ?? 0));
    final totalFuelL = monthTrips.fold(0.0, (s, t) => s + (t.fuelConsumedL ?? 0));
    final fuelPrice = (assignedVehicle?.fuelType == 'diesel')
        ? priceSvc.dieselPrice
        : priceSvc.petrolPrice;
    final monthlyCost = totalFuelL * fuelPrice;
    final daysWithTrips = monthTrips.length;
    final avgDailyKm = daysWithTrips > 0 ? totalKm / daysWithTrips : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          badges.Badge(
            showBadge: unreadNotifs > 0,
            badgeContent: Text('$unreadNotifs',
                style: const TextStyle(color: Colors.white, fontSize: 10)),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
          ),
          const SignOutButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppConstants.primaryOrange,
                          radius: 24,
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome, $name',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.darkText)),
                            Text('Driver',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppConstants.mediumText)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Assigned vehicle ─────────────────────────────────────
                  if (assignedVehicle != null) ...[
                    _SectionLabel('Assigned Vehicle'),
                    _VehicleCard(vehicle: assignedVehicle),
                  ],

                  // ── Request fuel button ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FuelRequestScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('Request Fuel'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48)),
                    ),
                  ),

                  // ── Monthly fuel stats ───────────────────────────────────
                  _SectionLabel('Monthly Fuel Summary — ${_monthName(now.month)} ${now.year}'),
                  _MonthlyStatsCard(
                    totalKm: totalKm,
                    totalFuelL: totalFuelL,
                    monthlyCost: monthlyCost,
                    avgDailyKm: avgDailyKm,
                    daysRecorded: daysWithTrips,
                    fuelType: assignedVehicle?.fuelType ?? 'petrol',
                    fuelPrice: fuelPrice,
                  ),

                  // ── Backend fuel allocation breakdown ────────────────────
                  if (apiAnalytics.myAllocation != null) ...[
                    _SectionLabel('Fuel Allocation — ${_monthName(now.month)} ${now.year}'),
                    _AllocationCard(
                      allocation: apiAnalytics.myAllocation!,
                      consumedL: apiAnalytics.myConsumedL,
                      consumedCostRwf: apiAnalytics.myConsumedCostRwf,
                    ),
                  ],

                  // ── Fuel budget & AI insights ────────────────────────────
                  if (insights != null) ...[
                    _SectionLabel('Fuel Budget — ${_monthName(now.month)} ${now.year}'),
                    _BudgetCard(insights: insights),
                    _SectionLabel('AI Insights'),
                    _AIInsightsCard(insights: insights),
                  ],

                  // ── Recent requests ──────────────────────────────────────
                  if (recentRequests.isNotEmpty) ...[
                    _SectionLabel('My Recent Requests'),
                    ...recentRequests.map((req) => _RequestTile(req: req)),
                  ],

                  // ── Recent trips ─────────────────────────────────────────
                  if (recentTrips.isNotEmpty) ...[
                    _SectionLabel('Recent Trips'),
                    ...recentTrips.map((trip) => _TripTile(trip: trip)),
                  ],
                ],
              ),
            ),
    );
  }

  static String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.darkText)),
      );
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppConstants.lightOrangeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car,
                color: AppConstants.primaryOrange, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.plateNumber,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppConstants.darkText)),
                Text(
                    '${vehicle.make} ${vehicle.model} ${vehicle.year} • ${vehicle.fuelType.toUpperCase()}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppConstants.mediumText)),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: vehicle.fuelPercent,
                  strokeWidth: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(vehicle.fuelColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(vehicle.fuelPercent * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: vehicle.fuelColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyStatsCard extends StatelessWidget {
  final double totalKm;
  final double totalFuelL;
  final double monthlyCost;
  final double avgDailyKm;
  final int daysRecorded;
  final String fuelType;
  final double fuelPrice;

  const _MonthlyStatsCard({
    required this.totalKm,
    required this.totalFuelL,
    required this.monthlyCost,
    required this.avgDailyKm,
    required this.daysRecorded,
    required this.fuelType,
    required this.fuelPrice,
  });

  @override
  Widget build(BuildContext context) {
    final projectedKm = avgDailyKm * 30;
    final projectedFuel = daysRecorded > 0 ? (totalFuelL / daysRecorded) * 30 : 0.0;
    final projectedCost = projectedFuel * fuelPrice;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryOrange,
            AppConstants.primaryOrange.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppConstants.primaryOrange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_gas_station, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('$daysRecorded days recorded',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Distance',
                  value: '${totalKm.toStringAsFixed(0)} km',
                  sub: '≈ ${projectedKm.toStringAsFixed(0)} km/mo',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Fuel Used',
                  value: '${totalFuelL.toStringAsFixed(1)} L',
                  sub: '≈ ${projectedFuel.toStringAsFixed(0)} L/mo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Avg Daily',
                  value: '${avgDailyKm.toStringAsFixed(0)} km/day',
                  sub: '${(daysRecorded > 0 ? totalFuelL / daysRecorded : 0).toStringAsFixed(1)} L/day',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Est. Monthly Cost',
                  value: AppConstants.formatRWF(projectedCost),
                  sub: '@ ${AppConstants.formatRWF(fuelPrice)}/L ${fuelType.toUpperCase()}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _StatItem({required this.label, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        Text(sub,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final FuelAllocationData allocation;
  final double consumedL;
  final double consumedCostRwf;
  const _AllocationCard({
    required this.allocation,
    required this.consumedL,
    required this.consumedCostRwf,
  });

  @override
  Widget build(BuildContext context) {
    final pct = allocation.totalAvailableL > 0
        ? (consumedL / allocation.totalAvailableL).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (pct * 100).round();
    final barColor = pctInt >= 100
        ? AppConstants.fuelCritical
        : pctInt >= 75
            ? AppConstants.fuelWarning
            : AppConstants.fuelGood;
    final remaining = (allocation.totalAvailableL - consumedL).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Allocated: ${allocation.totalAvailableL.toStringAsFixed(1)} L',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.darkText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$pctInt% used',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _StatItemDark(
                label: 'One-Way Route',
                value: '${allocation.oneWayKm.toStringAsFixed(1)} km',
              ),
            ),
            Expanded(
              child: _StatItemDark(
                label: 'Working Days',
                value: '${allocation.workingDays} days/mo',
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatItemDark(
                label: 'Base Requirement',
                value: '${allocation.baseRequirementL.toStringAsFixed(1)} L',
              ),
            ),
            Expanded(
              child: _StatItemDark(
                label: 'Buffer (${allocation.bufferPercent.toStringAsFixed(0)}%)',
                value: '${allocation.bufferL.toStringAsFixed(1)} L',
              ),
            ),
          ]),
          if (allocation.extraFuelGrantedL > 0) ...[
            const SizedBox(height: 10),
            _StatItemDark(
              label: 'Extra Fuel Granted',
              value: '+ ${allocation.extraFuelGrantedL.toStringAsFixed(1)} L',
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatItemDark(
                label: 'Consumed So Far',
                value: '${consumedL.toStringAsFixed(1)} L',
              ),
            ),
            Expanded(
              child: _StatItemDark(
                label: 'Remaining',
                value: '${remaining.toStringAsFixed(1)} L',
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatItemDark(
                label: 'Cost So Far',
                value: AppConstants.formatRWF(consumedCostRwf),
              ),
            ),
            Expanded(
              child: _StatItemDark(
                label: 'Projected Total Cost',
                value: AppConstants.formatRWF(allocation.projectedCostRwf),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final DriverInsights insights;
  const _BudgetCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final pct = (insights.percentUsed / 100).clamp(0.0, 1.0);
    final barColor = insights.percentUsed >= 100
        ? AppConstants.fuelCritical
        : insights.percentUsed >= 75
            ? AppConstants.fuelWarning
            : AppConstants.fuelGood;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget: ${AppConstants.formatRWF(insights.budgetRwf)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.darkText)),
              Text('${insights.percentUsed.toStringAsFixed(0)}% used',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: barColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItemDark(
                  label: 'Spent So Far',
                  value: AppConstants.formatRWF(insights.spentMonthToDate),
                ),
              ),
              Expanded(
                child: _StatItemDark(
                  label: 'Remaining',
                  value: AppConstants.formatRWF(insights.remainingBudget),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatItemDark(
                  label: 'Projected Month-End',
                  value: AppConstants.formatRWF(insights.projectedMonthEndSpend),
                ),
              ),
              Expanded(
                child: _StatItemDark(
                  label: 'Projected % of Budget',
                  value: '${insights.projectedBudgetPercent.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItemDark extends StatelessWidget {
  final String label;
  final String value;
  const _StatItemDark({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: AppConstants.mediumText, fontSize: 10)),
        Text(value,
            style: GoogleFonts.poppins(
                color: AppConstants.darkText,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AIInsightsCard extends StatelessWidget {
  final DriverInsights insights;
  const _AIInsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final category = insights.category;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: category.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(category.label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: category.color)),
              ),
              const Spacer(),
              const Icon(Icons.smart_toy_outlined,
                  size: 18, color: AppConstants.primaryOrange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItemDark(
                  label: 'Efficiency Score',
                  value: '${insights.efficiencyScore.toStringAsFixed(0)} / 150',
                ),
              ),
              Expanded(
                child: _StatItemDark(
                  label: 'Risk Score',
                  value: '${insights.riskScore.toStringAsFixed(0)} / 100',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatItemDark(
                  label: 'Actual Efficiency',
                  value: '${insights.actualEfficiency.toStringAsFixed(1)} km/L',
                ),
              ),
              Expanded(
                child: _StatItemDark(
                  label: 'Rated Efficiency',
                  value: '${insights.ratedEfficiency.toStringAsFixed(1)} km/L',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(insights.recommendation,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppConstants.mediumText)),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final dynamic req;
  const _RequestTile({required this.req});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: req.statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: req.statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${req.requestedQuantityL}L — ${req.vehiclePlate ?? 'Unknown'}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppConstants.darkText)),
                Text(AppConstants.formatDate(req.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppConstants.mediumText)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: req.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(req.status.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: req.statusColor)),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final GpsTrip trip;
  const _TripTile({required this.trip});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.route_outlined,
              color: AppConstants.primaryOrange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trip.displayOrigin} → ${trip.displayDestination}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppConstants.darkText)),
                Text(
                    AppConstants.formatDate(trip.startedAt ?? DateTime.now()),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppConstants.mediumText)),
              ],
            ),
          ),
          if (trip.distanceKm != null)
            Text('${trip.distanceKm!.toStringAsFixed(1)} km',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryOrange)),
        ],
      ),
    );
  }
}
