import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../models/fuel_price.dart';
import 'supabase_service.dart';

class FuelPriceService extends ChangeNotifier {
  Map<String, double> _prices = {'petrol': 1520.0, 'diesel': 1450.0};

  double getPrice(String fuelType) => _prices[fuelType] ?? 1520.0;
  double get petrolPrice => _prices['petrol'] ?? 1520.0;
  double get dieselPrice => _prices['diesel'] ?? 1450.0;

  Future<void> fetchCurrentPrices() async {
    if (DemoMode.active) return; // Use hard-coded defaults.
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await SupabaseService.instance.client
          .from('fuel_prices')
          .select()
          .lte('effective_date', today)
          .order('effective_date', ascending: false)
          .limit(10);

      final List<FuelPrice> prices =
          (data as List).map((e) => FuelPrice.fromJson(e)).toList();

      final Map<String, double> map = {};
      for (final p in prices) {
        if (!map.containsKey(p.fuelType)) {
          map[p.fuelType] = p.priceRwf;
        }
      }
      if (map.isNotEmpty) _prices = map;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPrice({
    required String fuelType,
    required double priceRwf,
    required String setBy,
  }) async {
    if (!DemoMode.active) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await SupabaseService.instance.client.from('fuel_prices').upsert({
        'fuel_type': fuelType,
        'price_rwf': priceRwf,
        'effective_date': today,
        'set_by': setBy,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fuel_type,effective_date');
    }
    _prices[fuelType] = priceRwf;
    notifyListeners();
  }
}
