class GpsTrip {
  final String id;
  final String vehicleId;
  final String? driverId;
  final String? driverName;
  final String status;
  final String? originName;
  final String? destinationName;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? distanceKm;
  final double? fuelConsumedL;
  final double? fuelEfficiency;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;

  GpsTrip({
    required this.id,
    required this.vehicleId,
    this.driverId,
    this.driverName,
    required this.status,
    this.originName,
    this.destinationName,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.distanceKm,
    this.fuelConsumedL,
    this.fuelEfficiency,
    this.startedAt,
    this.endedAt,
    this.durationMinutes,
  });

  factory GpsTrip.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return GpsTrip(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String? ?? json['vehicle_id'] as String? ?? '',
      driverId: json['driverId'] as String? ?? json['driver_id'] as String?,
      driverName: driver?['fullName'] as String? ?? profiles?['full_name'] as String?,
      status: (json['status'] as String? ?? 'COMPLETED').toLowerCase(),
      originName: json['originName'] as String? ?? json['origin_name'] as String?,
      destinationName: json['destinationName'] as String? ?? json['destination_name'] as String?,
      originLat: _parseNum(json['originLat'] ?? json['origin_lat']),
      originLng: _parseNum(json['originLng'] ?? json['origin_lng']),
      destinationLat: _parseNum(json['destinationLat'] ?? json['destination_lat']),
      destinationLng: _parseNum(json['destinationLng'] ?? json['destination_lng']),
      distanceKm: _parseNum(json['distanceKm'] ?? json['distance_km']),
      fuelConsumedL: _parseNum(json['fuelConsumedL'] ?? json['fuel_consumed_l']),
      fuelEfficiency: _parseNum(json['fuelEfficiency'] ?? json['fuel_efficiency']),
      startedAt: (json['startedAt'] ?? json['started_at']) != null
          ? DateTime.parse((json['startedAt'] ?? json['started_at']) as String)
          : null,
      endedAt: (json['endedAt'] ?? json['ended_at']) != null
          ? DateTime.parse((json['endedAt'] ?? json['ended_at']) as String)
          : null,
      durationMinutes: (json['durationMinutes'] ?? json['duration_minutes'] as num?)?.toInt(),
    );
  }

  static double? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'status': status,
        'origin_name': originName,
        'destination_name': destinationName,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'distance_km': distanceKm,
        'fuel_consumed_l': fuelConsumedL,
        'fuel_efficiency': fuelEfficiency,
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_minutes': durationMinutes,
      };

  String get displayOrigin => originName ?? 'Unknown Origin';
  String get displayDestination => destinationName ?? 'Unknown Destination';
}
