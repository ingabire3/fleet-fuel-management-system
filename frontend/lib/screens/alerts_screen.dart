import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/alert_service.dart';
import '../services/fuel_service.dart';
import '../models/alert.dart';
import '../utils/constants.dart';
import '../widgets/alert_card_widget.dart';
import '../widgets/shimmer_loader_widget.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  String _filter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('critical', 'Critical'),
    ('high', 'High'),
    ('medium', 'Medium'),
    ('low', 'Low'),
    ('resolved', 'Resolved'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      context.read<AlertService>().fetchAlerts(),
      context.read<FuelService>().fetchVehicles(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  List<Alert> get _filtered {
    final alerts = context.read<AlertService>().alerts;
    if (_filter == 'all') return alerts;
    if (_filter == 'resolved') {
      return alerts.where((a) => a.status == 'resolved').toList();
    }
    return alerts.where((a) => a.severity == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final alertSvc = context.watch<AlertService>();
    final fuelSvc = context.watch<FuelService>();
    final alerts = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text('Alerts',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _filters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          onSelected: (_) => setState(() => _filter = f.$1),
                          selectedColor: AppConstants.primaryOrange,
                          checkmarkColor: Colors.white,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _filter == f.$1
                                ? Colors.white
                                : AppConstants.darkText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerLoader(count: 5)
                : RefreshIndicator(
                    color: AppConstants.primaryOrange,
                    onRefresh: _load,
                    child: alerts.isEmpty
                        ? _empty()
                        : ListView.builder(
                            itemCount: alerts.length,
                            itemBuilder: (_, i) {
                              final alert = alerts[i];
                              final vehicle = fuelSvc.vehicles
                                  .where((v) => v.id == alert.vehicleId)
                                  .firstOrNull;
                              return AlertCard(
                                alert: alert,
                                vehiclePlate: vehicle?.plateNumber,
                                onAcknowledge: alert.status == 'open'
                                    ? () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        await alertSvc
                                            .acknowledgeAlert(alert.id);
                                        messenger.showSnackBar(const SnackBar(
                                            content:
                                                Text('Alert acknowledged')));
                                      }
                                    : null,
                                onResolve: alert.status == 'acknowledged'
                                    ? () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        await alertSvc.resolveAlert(alert.id);
                                        messenger.showSnackBar(const SnackBar(
                                            content: Text('Alert resolved')));
                                      }
                                    : null,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: AppConstants.fuelGood),
            const SizedBox(height: 12),
            Text(
              _filter == 'all' ? 'No alerts — all clear' : 'No $_filter alerts',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppConstants.mediumText),
            ),
          ],
        ),
      );
}
