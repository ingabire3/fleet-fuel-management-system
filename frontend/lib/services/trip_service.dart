import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../demo/demo_data.dart';
import '../models/gps_trip.dart';
import '../models/waypoint.dart';
import 'api_client.dart';

class TripService extends ChangeNotifier {
  List<GpsTrip> _trips = [];
  List<GpsTrip> get trips => _trips;

  Future<List<GpsTrip>> fetchTrips() async {
    if (DemoMode.active) {
      _trips = List.from(DemoData.trips);
      notifyListeners();
      return _trips;
    }
    final response = await ApiClient.instance.get('/gps');
    final list = response['data'] as List;
    _trips = list.map((e) => GpsTrip.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
    return _trips;
  }

  Future<List<Waypoint>> fetchWaypoints(String tripId) async {
    if (DemoMode.active) {
      final trip = _trips.firstWhere(
        (t) => t.id == tripId,
        orElse: () => _trips.first,
      );
      if (trip.originLat == null || trip.destinationLat == null) return [];
      return _interpolateWaypoints(trip);
    }
    final response = await ApiClient.instance.get('/gps/$tripId');
    final trip = response['data'] as Map<String, dynamic>;
    final waypoints = trip['waypoints'] as List? ?? [];
    return waypoints.map((e) => Waypoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<Waypoint> _interpolateWaypoints(GpsTrip trip) {
    const steps = 20;
    final lat0 = trip.originLat!;
    final lng0 = trip.originLng!;
    final lat1 = trip.destinationLat!;
    final lng1 = trip.destinationLng!;
    final startTime = trip.startedAt ?? DateTime.now();
    final durationMin = trip.durationMinutes ?? 120;
    final fuelStart = 50.0;
    final fuelDrop = (trip.fuelConsumedL ?? 8.0) / steps;

    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return Waypoint(
        id: '${trip.id}-wp-$i',
        tripId: trip.id,
        sequenceNo: i,
        latitude: lat0 + (lat1 - lat0) * t,
        longitude: lng0 + (lng1 - lng0) * t,
        speedKmh: i == 0 || i == steps ? 0.0 : 80.0 + (i % 3) * 10.0,
        fuelLevelL: fuelStart - fuelDrop * i,
        recordedAt: startTime.add(Duration(minutes: (durationMin * t).round())),
      );
    });
  }

  Future<GpsTrip> fetchTripById(String tripId) async {
    if (DemoMode.active) {
      return _trips.firstWhere(
        (t) => t.id == tripId,
        orElse: () => _trips.first,
      );
    }
    final response = await ApiClient.instance.get('/gps/$tripId');
    return GpsTrip.fromJson(response['data'] as Map<String, dynamic>);
  }

  int get activeTripsCount =>
      _trips.where((t) => t.status == 'in_progress' || t.status == 'active').length;
}
