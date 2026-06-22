import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/gps_trip.dart';
import '../models/waypoint.dart';
import '../services/trip_service.dart';
import '../utils/constants.dart';
import '../widgets/shimmer_loader_widget.dart';

class TripMapScreen extends StatefulWidget {
  final GpsTrip trip;

  const TripMapScreen({super.key, required this.trip});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  List<Waypoint> _waypoints = [];
  bool _loading = true;

  // Replay state
  final MapController _mapController = MapController();
  Timer? _replayTimer;
  int _replayIndex = 0;
  bool _isPlaying = false;
  bool _replayStarted = false;

  static const _replayInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wps =
        await context.read<TripService>().fetchWaypoints(widget.trip.id);
    if (mounted) {
      setState(() {
        _waypoints = wps;
        _loading = false;
        _replayIndex = 0;
      });
    }
  }

  void _startReplay() {
    if (_waypoints.length < 2) return;
    setState(() {
      _isPlaying = true;
      _replayStarted = true;
      if (_replayIndex >= _waypoints.length - 1) _replayIndex = 0;
    });
    _replayTimer = Timer.periodic(_replayInterval, (_) {
      if (!mounted) {
        _replayTimer?.cancel();
        return;
      }
      setState(() {
        if (_replayIndex < _waypoints.length - 1) {
          _replayIndex++;
          final current = _waypoints[_replayIndex];
          _mapController.move(
            LatLng(current.latitude, current.longitude),
            _mapController.camera.zoom,
          );
        } else {
          _replayTimer?.cancel();
          _isPlaying = false;
        }
      });
    });
  }

  void _pauseReplay() {
    _replayTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _resetReplay() {
    _replayTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _replayStarted = false;
      _replayIndex = 0;
    });
    if (_waypoints.isNotEmpty) {
      _mapController.move(_center, _mapController.camera.zoom);
    }
  }

  void _seekTo(int index) {
    _replayTimer?.cancel();
    setState(() {
      _replayIndex = index;
      _isPlaying = false;
    });
    if (_waypoints.isNotEmpty) {
      final wp = _waypoints[index];
      _mapController.move(
          LatLng(wp.latitude, wp.longitude), _mapController.camera.zoom);
    }
  }

  LatLng get _center {
    if (_waypoints.isNotEmpty) {
      final mid = _waypoints[_waypoints.length ~/ 2];
      return LatLng(mid.latitude, mid.longitude);
    }
    if (widget.trip.originLat != null && widget.trip.originLng != null) {
      return LatLng(widget.trip.originLat!, widget.trip.originLng!);
    }
    return const LatLng(-1.9441, 30.0619);
  }

  LatLng? get _replayPosition {
    if (!_replayStarted || _waypoints.isEmpty) return null;
    final wp = _waypoints[_replayIndex];
    return LatLng(wp.latitude, wp.longitude);
  }

  double get _replayProgress =>
      _waypoints.isEmpty ? 0 : _replayIndex / (_waypoints.length - 1);

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final points =
        _waypoints.map((w) => LatLng(w.latitude, w.longitude)).toList();
    final replayPos = _replayPosition;
    final currentWp =
        _replayStarted && _waypoints.isNotEmpty ? _waypoints[_replayIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${trip.displayOrigin} → ${trip.displayDestination}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_loading && _waypoints.length >= 2)
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: 'Reset replay',
              onPressed: _resetReplay,
            ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader(count: 1, height: 400)
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: points.length > 1 ? 12 : 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'rw.npd.npd_fuel_monitor',
                    ),
                    if (points.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 4,
                            color: AppConstants.primaryOrange
                                .withValues(alpha: 0.5),
                          ),
                          // Replayed portion highlighted
                          if (_replayStarted && _replayIndex > 0)
                            Polyline(
                              points: points.take(_replayIndex + 1).toList(),
                              strokeWidth: 4,
                              color: AppConstants.primaryOrange,
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (points.isNotEmpty) ...[
                          Marker(
                            point: points.first,
                            width: 36,
                            height: 36,
                            child: const _MapPin(
                                color: AppConstants.fuelGood,
                                icon: Icons.trip_origin),
                          ),
                          if (points.length > 1)
                            Marker(
                              point: points.last,
                              width: 36,
                              height: 36,
                              child: const _MapPin(
                                  color: AppConstants.severityCritical,
                                  icon: Icons.place),
                            ),
                        ],
                        if (replayPos != null)
                          Marker(
                            point: replayPos,
                            width: 44,
                            height: 44,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.7, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (_, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppConstants.primaryOrange,
                                      width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black38, blurRadius: 8)
                                  ],
                                ),
                                child: const Icon(Icons.directions_car,
                                    color: AppConstants.primaryOrange,
                                    size: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Replay control panel
                if (_waypoints.length >= 2)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 240,
                    child: _ReplayControls(
                      isPlaying: _isPlaying,
                      progress: _replayProgress,
                      replayIndex: _replayIndex,
                      totalWaypoints: _waypoints.length,
                      currentSpeed: currentWp?.speedKmh,
                      currentFuel: currentWp?.fuelLevelL,
                      onPlay: _startReplay,
                      onPause: _pauseReplay,
                      onSeek: (v) =>
                          _seekTo((v * (_waypoints.length - 1)).round()),
                    ),
                  ),
                DraggableScrollableSheet(
                  initialChildSize: 0.28,
                  minChildSize: 0.14,
                  maxChildSize: 0.5,
                  builder: (_, controller) => Container(
                    decoration: const BoxDecoration(
                      color: AppConstants.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, -2))
                      ],
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          '${trip.displayOrigin} → ${trip.displayDestination}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatChip(
                              label: 'Distance',
                              value: trip.distanceKm != null
                                  ? '${trip.distanceKm!.toStringAsFixed(1)} km'
                                  : '—',
                              icon: Icons.route_outlined,
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              label: 'Fuel Used',
                              value: trip.fuelConsumedL != null
                                  ? '${trip.fuelConsumedL!.toStringAsFixed(1)} L'
                                  : '—',
                              icon: Icons.local_gas_station_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatChip(
                              label: 'Efficiency',
                              value: trip.fuelEfficiency != null
                                  ? '${trip.fuelEfficiency!.toStringAsFixed(1)} km/L'
                                  : '—',
                              icon: Icons.speed_outlined,
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              label: 'Duration',
                              value: trip.durationMinutes != null
                                  ? '${trip.durationMinutes!} min'
                                  : '—',
                              icon: Icons.timer_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppConstants.mediumText),
                            const SizedBox(width: 4),
                            Text(
                              '${_waypoints.length} waypoints recorded',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppConstants.mediumText),
                            ),
                          ],
                        ),
                        if (trip.driverName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 14, color: AppConstants.mediumText),
                              const SizedBox(width: 4),
                              Text(
                                trip.driverName!,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppConstants.mediumText),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReplayControls extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final int replayIndex;
  final int totalWaypoints;
  final double? currentSpeed;
  final double? currentFuel;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<double> onSeek;

  const _ReplayControls({
    required this.isPlaying,
    required this.progress,
    required this.replayIndex,
    required this.totalWaypoints,
    this.currentSpeed,
    this.currentFuel,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isPlaying ? onPause : onPlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppConstants.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: onSeek,
                  activeColor: AppConstants.primaryOrange,
                  inactiveColor: Colors.grey.shade300,
                ),
              ),
              Text(
                '$replayIndex/$totalWaypoints',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppConstants.mediumText),
              ),
            ],
          ),
          if (currentSpeed != null || currentFuel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (currentSpeed != null)
                    _LiveStat(
                        label: 'Speed',
                        value: '${currentSpeed!.toStringAsFixed(0)} km/h',
                        icon: Icons.speed),
                  if (currentFuel != null)
                    _LiveStat(
                        label: 'Fuel',
                        value: '${currentFuel!.toStringAsFixed(0)}%',
                        icon: Icons.local_gas_station_outlined),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _LiveStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppConstants.primaryOrange),
        const SizedBox(width: 4),
        Text('$label: ',
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppConstants.mediumText)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppConstants.darkText)),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.lightOrangeBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppConstants.orangeBorder.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: AppConstants.primaryOrange),
                const SizedBox(width: 4),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppConstants.mediumText)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppConstants.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
