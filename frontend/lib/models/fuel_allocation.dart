class FuelAllocationData {
  final String id;
  final String driverId;
  final int periodYear;
  final int periodMonth;
  final double distanceKm;
  final int workingDays;
  final double vehicleEfficiency;
  final double fuelPriceRwf;
  final double bufferPercent;
  final double baseRequirementL;
  final double bufferL;
  final double finalAllocationL;
  final double extraFuelGrantedL;
  final double totalAvailableL;
  final double projectedCostRwf;

  const FuelAllocationData({
    required this.id,
    required this.driverId,
    required this.periodYear,
    required this.periodMonth,
    required this.distanceKm,
    required this.workingDays,
    required this.vehicleEfficiency,
    required this.fuelPriceRwf,
    required this.bufferPercent,
    required this.baseRequirementL,
    required this.bufferL,
    required this.finalAllocationL,
    required this.extraFuelGrantedL,
    required this.totalAvailableL,
    required this.projectedCostRwf,
  });

  double get oneWayKm => distanceKm / 2;

  static double _n(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory FuelAllocationData.fromJson(Map<String, dynamic> json) => FuelAllocationData(
        id: json['id'] as String,
        driverId: json['driverId'] as String,
        periodYear: json['periodYear'] as int,
        periodMonth: json['periodMonth'] as int,
        distanceKm: _n(json['distanceKm']),
        workingDays: json['workingDays'] as int,
        vehicleEfficiency: _n(json['vehicleEfficiency']),
        fuelPriceRwf: _n(json['fuelPriceRwf']),
        bufferPercent: _n(json['bufferPercent']),
        baseRequirementL: _n(json['baseRequirementL']),
        bufferL: _n(json['bufferL']),
        finalAllocationL: _n(json['finalAllocationL']),
        extraFuelGrantedL: _n(json['extraFuelGrantedL']),
        totalAvailableL: _n(json['totalAvailableL']),
        projectedCostRwf: _n(json['projectedCostRwf']),
      );
}
