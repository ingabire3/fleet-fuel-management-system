import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:printing/printing.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../services/alert_service.dart';
import '../../services/trip_service.dart';
import '../../services/notification_service.dart';
import '../../services/fuel_request_service.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card_widget.dart';
import '../../widgets/alert_card_widget.dart';
import '../../widgets/vehicle_card_widget.dart';
import '../../widgets/shimmer_loader_widget.dart';
import '../../widgets/sign_out_button.dart';
import '../alerts_screen.dart';
import '../notifications_screen.dart';
import '../vehicles_screen.dart';
import 'user_approval_screen.dart';
import 'management_dashboard.dart';
import 'permissions_screen.dart';
import 'working_days_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  int _pendingDrivers = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final fuelSvc = context.read<FuelService>();
    final tripSvc = context.read<TripService>();
    final alertSvc = context.read<AlertService>();
    final authSvc = context.read<AuthService>();
    final notifSvc = context.read<NotificationService>();
    try {
      await Future.wait([
        fuelSvc.fetchVehicles(),
        fuelSvc.fetchFuelTransactions(),
        tripSvc.fetchTrips(),
        alertSvc.fetchAlerts(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
    try {
      final pending = await authSvc.fetchPendingDrivers();
      _pendingDrivers = pending.length;
    } catch (_) {}
    try {
      final uid = authSvc.currentUserId;
      if (uid != null) {
        await notifSvc.fetch(uid, seeAll: true);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportReport(_ReportAction action) async {
    final fuelSvc = context.read<FuelService>();
    final alertSvc = context.read<AlertService>();
    final reqSvc = context.read<FuelRequestService>();
    final auth = context.read<AuthService>();
    const fileName = 'NPD_Fleet_Report.pdf';
    try {
      final requests = await reqSvc.fetchAll();
      final bytes = await ReportService.generateFleetReport(
        generatedBy: auth.currentProfile?.fullName ?? 'Admin',
        vehicles: fuelSvc.vehicles,
        transactions: fuelSvc.transactions,
        requests: requests,
        alerts: alertSvc.alerts,
      );
      if (action == _ReportAction.share) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error generating report: $e')));
      }
    }
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
    context.watch<TripService>();
    final alertSvc = context.watch<AlertService>();
    final notifSvc = context.watch<NotificationService>();

    final openAlerts = alertSvc.openAlertCount;
    final unreadNotifs = notifSvc.unreadCount;
    final recentAlerts = alertSvc.alerts.take(5).toList();
    final needsAttention = fuel.vehicles
        .where((v) => v.fuelPercent < 0.2 || v.status == 'maintenance')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_gas_station,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('NPD Admin',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        actions: [
          badges.Badge(
            showBadge: unreadNotifs > 0,
            badgeContent: Text('$unreadNotifs',
                style:
                    const TextStyle(color: Colors.white, fontSize: 10)),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
          ),
          PopupMenuButton<_ReportAction>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Fleet Report (PDF)',
            onSelected: _exportReport,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ReportAction.preview,
                child: Row(children: [
                  Icon(Icons.visibility_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Preview / Save'),
                ]),
              ),
              PopupMenuItem(
                value: _ReportAction.share,
                child: Row(children: [
                  Icon(Icons.share_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Share Report'),
                ]),
              ),
            ],
          ),
          const SignOutButton(),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, ${auth.currentProfile?.fullName.split(' ').first ?? 'Admin'}',
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.darkText),
                        ),
                        Text(AppConstants.formatDate(DateTime.now()),
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppConstants.mediumText)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        StatCard(
                          value: '${fuel.vehicles.length}',
                          label: 'Total Vehicles',
                          icon: Icons.directions_car_outlined,
                        ),
                        StatCard(
                          value: '$_pendingDrivers',
                          label: 'Pending Approvals',
                          icon: Icons.person_add_outlined,
                          valueColor: _pendingDrivers > 0
                              ? AppConstants.severityHigh
                              : AppConstants.fuelGood,
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
                          value: fuel.totalMonthlyCost > 0
                              ? AppConstants.formatRWF(fuel.totalMonthlyCost)
                              : 'RWF 0',
                          label: 'Monthly Cost',
                          icon: Icons.attach_money,
                        ),
                      ],
                    ),
                  ),
                  _SectionHeader(title: 'Quick Actions'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(children: [
                      _QuickAction(
                        icon: Icons.directions_car_outlined,
                        label: 'Vehicles',
                        badge: 0,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const VehiclesScreen())),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.person_add_outlined,
                        label: 'Approvals',
                        badge: _pendingDrivers,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const UserApprovalScreen())),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.notifications_outlined,
                        label: 'Alerts',
                        badge: openAlerts,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AlertsScreen())),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.insights_outlined,
                        label: 'Analytics',
                        badge: 0,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ManagementDashboard())),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(children: [
                      _QuickAction(
                        icon: Icons.security_outlined,
                        label: 'Permissions',
                        badge: 0,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const PermissionsScreen())),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.calendar_month_outlined,
                        label: 'Working Days',
                        badge: 0,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const WorkingDaysScreen())),
                      ),
                    ]),
                  ),
                  if (needsAttention.isNotEmpty) ...[
                    _SectionHeader(title: 'Vehicles Needing Attention'),
                    ...needsAttention.map((v) => VehicleCard(vehicle: v)),
                  ],
                  _SectionHeader(
                    title: 'Recent Alerts',
                    action: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AlertsScreen())),
                      child: const Text('View All'),
                    ),
                  ),
                  if (recentAlerts.isEmpty)
                    const _EmptyState(
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
                                final svc = context.read<AlertService>();
                                await svc.acknowledgeAlert(alert.id);
                              }
                            : null,
                        onResolve: alert.status == 'acknowledged'
                            ? () async {
                                final svc = context.read<AlertService>();
                                await svc.resolveAlert(alert.id);
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.darkText)),
          ?action,
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.badge,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppConstants.lightOrangeBg,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppConstants.orangeBorder.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              badges.Badge(
                showBadge: badge > 0,
                badgeContent: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
                child: Icon(icon,
                    color: AppConstants.primaryOrange, size: 26),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.darkText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(children: [
            Icon(icon, size: 40, color: AppConstants.mediumText),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppConstants.mediumText)),
          ]),
        ),
      );
}

enum _ReportAction { preview, share }
