class Waypoint {
  final String id;
  final String tripId;
  final int sequenceNo;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? fuelLevelL;
  final DateTime recordedAt;

  Waypoint({
    required this.id,
    required this.tripId,
    required this.sequenceNo,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.fuelLevelL,
    required this.recordedAt,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        id: json['id'] as String,
        tripId: json['tripId'] as String? ?? json['trip_id'] as String? ?? '',
        sequenceNo: (json['sequenceNo'] ?? json['sequence_no'] as num?)?.toInt() ?? 0,
        latitude: _parseNum(json['latitude']) ?? 0.0,
        longitude: _parseNum(json['longitude']) ?? 0.0,
        speedKmh: _parseNum(json['speedKmh'] ?? json['speed_kmh']),
        fuelLevelL: _parseNum(json['fuelLevelL'] ?? json['fuel_level_l']),
        recordedAt: DateTime.parse(
            json['recordedAt'] as String? ?? json['recorded_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  static double? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'sequence_no': sequenceNo,
        'latitude': latitude,
        'longitude': longitude,
        'speed_kmh': speedKmh,
        'fuel_level_l': fuelLevelL,
        'recorded_at': recordedAt.toIso8601String(),
      };
}
