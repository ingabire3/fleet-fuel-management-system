import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../services/auth_service.dart';
import '../services/fuel_service.dart';
import '../services/trip_service.dart';
import '../services/alert_service.dart';
import '../utils/constants.dart';
import '../widgets/stat_card_widget.dart';
import '../widgets/vehicle_card_widget.dart';
import '../widgets/alert_card_widget.dart';
import '../widgets/shimmer_loader_widget.dart';
import 'alerts_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      context.read<FuelService>().fetchVehicles(),
      context.read<FuelService>().fetchFuelTransactions(),
      context.read<TripService>().fetchTrips(),
      context.read<AlertService>().fetchAlerts(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fuel = context.watch<FuelService>();
    final trips = context.watch<TripService>();
    final alertSvc = context.watch<AlertService>();

    final openAlerts = alertSvc.openAlertCount;
    final recentAlerts = alertSvc.alerts.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppConstants.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_gas_station,
                  color: AppConstants.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text('NPD Fleet Monitor',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          badges.Badge(
            showBadge: openAlerts > 0,
            badgeContent: Text(
              '$openAlerts',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppConstants.primaryOrange,
        onRefresh: _loadAll,
        child: _loading
            ? const ShimmerLoader(count: 5, height: 90)
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _GreetingSection(
                    greeting: _greeting(),
                    name: auth.currentProfile?.fullName ?? 'User',
                  ),
                  _StatsGrid(
                    vehicleCount: fuel.vehicles.length,
                    activeTrips: trips.activeTripsCount,
                    openAlerts: openAlerts,
                    monthlyCost: fuel.totalMonthlyCost,
                  ),
                  _SectionHeader(title: 'Fleet Fuel Status'),
                  if (fuel.vehicles.isEmpty)
                    _EmptyState(
                        icon: Icons.directions_car_outlined,
                        message: 'No vehicles found')
                  else
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: fuel.vehicles.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: VehicleCardCompact(
                              vehicle: fuel.vehicles[i]),
                        ),
                      ),
                    ),
                  _SectionHeader(
                    title: 'Recent Alerts',
                    action: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AlertsScreen()),
                      ),
                      child: const Text('View All'),
                    ),
                  ),
                  if (recentAlerts.isEmpty)
                    _EmptyState(
                        icon: Icons.check_circle_outline,
                        message: 'No alerts — all clear')
                  else
                    ...recentAlerts.map((alert) {
                      final vehicle = fuel.vehicles
                          .where((v) => v.id == alert.vehicleId)
                          .firstOrNull;
                      return AlertCard(
                        alert: alert,
                        vehiclePlate: vehicle?.plateNumber,
                        onAcknowledge: alert.status == 'open'
                            ? () async {
                                await context
                                    .read<AlertService>()
                                    .acknowledgeAlert(alert.id);
                              }
                            : null,
                        onResolve: alert.status == 'acknowledged'
                            ? () async {
                                await context
                                    .read<AlertService>()
                                    .resolveAlert(alert.id);
                              }
                            : null,
                      );
                    }),
                ],
              ),
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  final String greeting;
  final String name;

  const _GreetingSection({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${name.split(' ').first}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppConstants.darkText,
            ),
          ),
          Text(
            AppConstants.formatDate(DateTime.now()),
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppConstants.mediumText),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int vehicleCount;
  final int activeTrips;
  final int openAlerts;
  final double monthlyCost;

  const _StatsGrid({
    required this.vehicleCount,
    required this.activeTrips,
    required this.openAlerts,
    required this.monthlyCost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          StatCard(
            value: '$vehicleCount',
            label: 'Total Vehicles',
            icon: Icons.directions_car_outlined,
          ),
          StatCard(
            value: '$activeTrips',
            label: 'Active Trips',
            icon: Icons.map_outlined,
            valueColor: activeTrips > 0
                ? AppConstants.fuelGood
                : AppConstants.primaryOrange,
          ),
          StatCard(
            value: '$openAlerts',
            label: 'Open Alerts',
            icon: Icons.warning_amber_outlined,
            valueColor: openAlerts > 0
                ? AppConstants.severityCritical
                : AppConstants.fuelGood,
          ),
          StatCard(
            value: monthlyCost > 0
                ? AppConstants.formatRWF(monthlyCost)
                : 'RWF 0',
            label: 'Monthly Cost',
            icon: Icons.attach_money,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppConstants.darkText,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppConstants.mediumText),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppConstants.mediumText)),
          ],
        ),
      ),
    );
  }
}
