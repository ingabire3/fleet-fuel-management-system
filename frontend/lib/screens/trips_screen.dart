import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/trip_service.dart';
import '../models/gps_trip.dart';
import '../utils/constants.dart';
import '../utils/anomaly_detector.dart';
import '../widgets/shimmer_loader_widget.dart';
import 'trip_map_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await context.read<TripService>().fetchTrips();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripService>().trips;

    return Scaffold(
      appBar: AppBar(
        title: Text('GPS Trips',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const ShimmerLoader(count: 6)
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: trips.isEmpty
                  ? _empty()
                  : ListView.builder(
                      itemCount: trips.length,
                      itemBuilder: (_, i) => _TripCard(
                        trip: trips[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripMapScreen(trip: trips[i]),
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _empty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 56, color: AppConstants.mediumText),
            SizedBox(height: 12),
            Text('No trips recorded',
                style: TextStyle(color: AppConstants.mediumText)),
          ],
        ),
      );
}

class _TripCard extends StatelessWidget {
  final GpsTrip trip;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.onTap});

  Color _efficiencyColor(double? kmL) {
    if (kmL == null) return AppConstants.mediumText;
    if (kmL >= 6) return AppConstants.fuelGood;
    if (kmL >= 4) return AppConstants.fuelWarning;
    return AppConstants.fuelCritical;
  }

  @override
  Widget build(BuildContext context) {
    final efficiency = trip.fuelEfficiency;
    final effLabel = efficiency != null
        ? AnomalyDetector.getEfficiencyRating(efficiency, 'car')
        : null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            trip.displayOrigin,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppConstants.darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward,
                              size: 16, color: AppConstants.primaryOrange),
                        ),
                        Flexible(
                          child: Text(
                            trip.displayDestination,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppConstants.darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: trip.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (trip.distanceKm != null)
                    _Badge(
                      label: '${trip.distanceKm!.toStringAsFixed(1)} km',
                      icon: Icons.route_outlined,
                      color: AppConstants.primaryOrange,
                    ),
                  if (efficiency != null) ...[
                    const SizedBox(width: 8),
                    _Badge(
                      label: '${efficiency.toStringAsFixed(1)} km/L',
                      icon: Icons.local_gas_station_outlined,
                      color: _efficiencyColor(efficiency),
                    ),
                  ],
                  if (effLabel != null) ...[
                    const SizedBox(width: 8),
                    _Badge(
                      label: effLabel,
                      icon: Icons.star_outline,
                      color: _efficiencyColor(efficiency),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (trip.driverName != null) ...[
                    const Icon(Icons.person_outline,
                        size: 12, color: AppConstants.mediumText),
                    const SizedBox(width: 4),
                    Text(trip.driverName!,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppConstants.mediumText)),
                    const SizedBox(width: 12),
                  ],
                  if (trip.startedAt != null)
                    Text(
                      AppConstants.formatDate(trip.startedAt!),
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppConstants.mediumText),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'active':
      case 'in_progress':
        c = AppConstants.fuelGood;
        break;
      case 'completed':
        c = AppConstants.severityLow;
        break;
      default:
        c = AppConstants.mediumText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
