class FuelPrice {
  final String id;
  final String fuelType;
  final double priceRwf;
  final DateTime effectiveDate;
  final String? setBy;
  final DateTime createdAt;

  FuelPrice({
    required this.id,
    required this.fuelType,
    required this.priceRwf,
    required this.effectiveDate,
    this.setBy,
    required this.createdAt,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) => FuelPrice(
        id: json['id'] as String,
        fuelType: json['fuel_type'] as String? ?? 'petrol',
        priceRwf: (json['price_rwf'] as num?)?.toDouble() ?? 0,
        effectiveDate: json['effective_date'] != null
            ? DateTime.parse(json['effective_date'] as String)
            : DateTime.now(),
        setBy: json['set_by'] as String?,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'fuel_type': fuelType,
        'price_rwf': priceRwf,
        'effective_date': effectiveDate.toIso8601String().split('T')[0],
      };
}
