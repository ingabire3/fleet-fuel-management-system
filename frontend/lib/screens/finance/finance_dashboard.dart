import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:printing/printing.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_request_service.dart';
import '../../services/fuel_price_service.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card_widget.dart';
import '../../widgets/shimmer_loader_widget.dart';
import '../../widgets/sign_out_button.dart';
import '../notifications_screen.dart';
import 'fuel_approval_screen.dart';
import 'price_setting_screen.dart';

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
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
    final uid = context.read<AuthService>().currentUserId;
    final notifSvc = context.read<NotificationService>();
    try {
      await Future.wait([
        context.read<FuelService>().fetchVehicles(),
        context.read<FuelService>().fetchFuelTransactions(),
        context.read<FuelRequestService>().fetchPending(),
        context.read<FuelPriceService>().fetchCurrentPrices(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
    try {
      if (uid != null) {
        await notifSvc.fetch(uid);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportReport(_ReportAction action) async {
    final fuelSvc = context.read<FuelService>();
    final reqSvc = context.read<FuelRequestService>();
    final priceSvc = context.read<FuelPriceService>();
    final auth = context.read<AuthService>();
    const fileName = 'NPD_Finance_Report.pdf';
    try {
      final bytes = await ReportService.generateFinanceReport(
        generatedBy: auth.currentProfile?.fullName ?? 'Finance',
        vehicles: fuelSvc.vehicles,
        transactions: fuelSvc.transactions,
        requests: reqSvc.requests,
        petrolPrice: priceSvc.petrolPrice,
        dieselPrice: priceSvc.dieselPrice,
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fuel = context.watch<FuelService>();
    final reqSvc = context.watch<FuelRequestService>();
    final priceSvc = context.watch<FuelPriceService>();
    final unreadNotifs = context.watch<NotificationService>().unreadCount;

    final name = auth.currentProfile?.fullName.split(' ').first ?? 'Finance';
    final pending = reqSvc.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Finance Dashboard',
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
          PopupMenuButton<_ReportAction>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Finance Report (PDF)',
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PriceSettingScreen())),
            tooltip: 'Set Fuel Price',
          ),
          const SignOutButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppConstants.primaryOrange,
        onRefresh: _load,
        child: _loading
            ? const ShimmerLoader(count: 4, height: 90)
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, $name',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.darkText)),
                        Text(AppConstants.formatDate(DateTime.now()),
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppConstants.mediumText)),
                      ],
                    ),
                  ),
                  _TodayPriceCard(
                    petrolPrice: priceSvc.petrolPrice,
                    dieselPrice: priceSvc.dieselPrice,
                    onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PriceSettingScreen())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        StatCard(
                          value: '$pending',
                          label: 'Pending Approvals',
                          icon: Icons.pending_actions_outlined,
                          valueColor: pending > 0
                              ? AppConstants.severityHigh
                              : AppConstants.fuelGood,
                        ),
                        StatCard(
                          value: fuel.totalMonthlyCost > 0
                              ? AppConstants.formatRWF(fuel.totalMonthlyCost)
                              : 'RWF 0',
                          label: 'Monthly Spend',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        StatCard(
                          value: '${fuel.vehicles.length}',
                          label: 'Fleet Vehicles',
                          icon: Icons.directions_car_outlined,
                        ),
                        StatCard(
                          value:
                              '${fuel.transactions.where((t) => t.transactionType == 'refill' && t.recordedAt.isAfter(DateTime.now().subtract(const Duration(days: 30)))).length}',
                          label: 'Refills This Month',
                          icon: Icons.local_gas_station_outlined,
                        ),
                      ],
                    ),
                  ),
                  _SectionHeader(
                    title: 'Pending Fuel Requests',
                    action: pending > 0
                        ? TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const FuelApprovalScreen())),
                            child: Text('View All ($pending)',
                                style: const TextStyle(
                                    color: AppConstants.primaryOrange)),
                          )
                        : null,
                  ),
                  if (pending == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.check_circle_outline,
                              size: 40, color: AppConstants.fuelGood),
                          SizedBox(height: 8),
                          Text('No pending requests',
                              style:
                                  TextStyle(color: AppConstants.mediumText)),
                        ]),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FuelApprovalScreen())),
                        icon: const Icon(Icons.approval_outlined),
                        label: Text('Review $pending Pending Request${pending > 1 ? 's' : ''}'),
                      ),
                    ),
                  _SectionHeader(title: 'Monthly Spend by Vehicle'),
                  ...fuel.vehicles.take(5).map((v) {
                    final spent = fuel.transactions
                        .where((t) =>
                            t.vehicleId == v.id &&
                            t.transactionType == 'refill' &&
                            t.totalCostRwf != null &&
                            t.recordedAt.isAfter(DateTime(
                                DateTime.now().year, DateTime.now().month, 1)))
                        .fold(0.0, (sum, t) => sum + (t.totalCostRwf ?? 0));
                    const budget = 500000.0;
                    final progress = (spent / budget).clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(v.plateNumber,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppConstants.primaryOrange)),
                              Text(AppConstants.formatRWF(spent),
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppConstants.darkText)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                progress > 0.9
                                    ? AppConstants.severityCritical
                                    : progress > 0.7
                                        ? AppConstants.severityHigh
                                        : AppConstants.primaryOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                              '${(progress * 100).toStringAsFixed(0)}% of ${AppConstants.formatRWF(budget)} budget',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppConstants.mediumText)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

class _TodayPriceCard extends StatelessWidget {
  final double petrolPrice;
  final double dieselPrice;
  final VoidCallback onEdit;

  const _TodayPriceCard(
      {required this.petrolPrice,
      required this.dieselPrice,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryOrange, AppConstants.primaryDarkOrange],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Fuel Prices",
                    style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text('Petrol: ${AppConstants.formatRWF(petrolPrice)}/L',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('Diesel: ${AppConstants.formatRWF(dieselPrice)}/L',
                        style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            onPressed: onEdit,
            tooltip: 'Update price',
          ),
        ],
      ),
    );
  }
}

enum _ReportAction { preview, share }

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
