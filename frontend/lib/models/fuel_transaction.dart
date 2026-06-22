class FuelTransaction {
  final String id;
  final String vehicleId;
  final String? driverId;
  final String? stationId;
  final String transactionType;
  final double quantityL;
  final double? unitPriceRwf;
  final double? totalCostRwf;
  final double? odometerKm;
  final double? fuelLevelBefore;
  final double? fuelLevelAfter;
  final String? receiptNumber;
  final String? notes;
  final DateTime recordedAt;

  FuelTransaction({
    required this.id,
    required this.vehicleId,
    this.driverId,
    this.stationId,
    required this.transactionType,
    required this.quantityL,
    this.unitPriceRwf,
    this.totalCostRwf,
    this.odometerKm,
    this.fuelLevelBefore,
    this.fuelLevelAfter,
    this.receiptNumber,
    this.notes,
    required this.recordedAt,
  });

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory FuelTransaction.fromJson(Map<String, dynamic> json) =>
      FuelTransaction(
        id: json['id'] as String,
        vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
        driverId: (json['driverId'] ?? json['driver_id']) as String?,
        stationId: (json['stationId'] ?? json['station_id']) as String?,
        transactionType: (json['transactionType'] ?? json['transaction_type']) as String? ?? 'refill',
        quantityL: _num(json['quantityL'] ?? json['quantity_l']) ?? 0.0,
        unitPriceRwf: _num(json['unitPriceRwf'] ?? json['unit_price_rwf']),
        totalCostRwf: _num(json['totalCostRwf'] ?? json['total_cost_rwf']),
        odometerKm: _num(json['odometerKm'] ?? json['odometer_km']),
        fuelLevelBefore: _num(json['fuelLevelBefore'] ?? json['fuel_level_before']),
        fuelLevelAfter: _num(json['fuelLevelAfter'] ?? json['fuel_level_after']),
        receiptNumber: (json['receiptNumber'] ?? json['receipt_number']) as String?,
        notes: json['notes'] as String?,
        recordedAt: DateTime.parse(
            (json['recordedAt'] ?? json['recorded_at']) as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'station_id': stationId,
        'transaction_type': transactionType,
        'quantity_l': quantityL,
        'unit_price_rwf': unitPriceRwf,
        'total_cost_rwf': totalCostRwf,
        'odometer_km': odometerKm,
        'fuel_level_before': fuelLevelBefore,
        'fuel_level_after': fuelLevelAfter,
        'receipt_number': receiptNumber,
        'notes': notes,
        'recorded_at': recordedAt.toIso8601String(),
      };
}
