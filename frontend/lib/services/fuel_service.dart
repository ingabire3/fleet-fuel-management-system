import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../demo/demo_data.dart';
import '../models/vehicle.dart';
import '../models/fuel_transaction.dart';
import 'api_client.dart';

class FuelService extends ChangeNotifier {
  List<Vehicle> _vehicles = [];
  List<FuelTransaction> _transactions = [];

  List<Vehicle> get vehicles => _vehicles;
  List<FuelTransaction> get transactions => _transactions;

  Future<List<Vehicle>> fetchVehicles() async {
    if (DemoMode.active) {
      _vehicles = List.from(DemoData.vehicles);
      notifyListeners();
      return _vehicles;
    }
    final response = await ApiClient.instance.get('/vehicles');
    final list = response['data'] as List;
    _vehicles = list.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
    return _vehicles;
  }

  Future<void> addVehicle({
    required String plateNumber,
    required String make,
    required String model,
    required int year,
    required String vehicleType,
    required String fuelType,
    required double tankCapacityL,
  }) async {
    if (DemoMode.active) {
      _vehicles.insert(
        0,
        Vehicle(
          id: 'vehicle-${DateTime.now().millisecondsSinceEpoch}',
          plateNumber: plateNumber,
          make: make,
          model: model,
          year: year,
          vehicleType: vehicleType,
          fuelType: fuelType,
          tankCapacityL: tankCapacityL,
          currentFuelL: tankCapacityL,
          odometerKm: 0,
          status: 'active',
        ),
      );
      notifyListeners();
      return;
    }
    await ApiClient.instance.post('/vehicles', body: {
      'plateNumber': plateNumber,
      'make': make,
      'model': model,
      'year': year,
      'vehicleType': vehicleType.toUpperCase(),
      'fuelType': fuelType.toUpperCase(),
      'tankCapacityL': tankCapacityL,
      'currentFuelL': tankCapacityL,
    });
    await fetchVehicles();
  }

  Future<void> assignDriver(String vehicleId, String? driverId) async {
    if (DemoMode.active) {
      final idx = _vehicles.indexWhere((v) => v.id == vehicleId);
      if (idx != -1) {
        final v = _vehicles[idx];
        _vehicles[idx] = Vehicle(
          id: v.id, plateNumber: v.plateNumber, make: v.make, model: v.model,
          year: v.year, vehicleType: v.vehicleType, fuelType: v.fuelType,
          tankCapacityL: v.tankCapacityL, currentFuelL: v.currentFuelL,
          odometerKm: v.odometerKm, status: v.status,
          assignedDriverId: driverId,
        );
        notifyListeners();
      }
      return;
    }
    await ApiClient.instance.patch('/vehicles/$vehicleId/assign-driver', body: {
      'driverId': driverId,
    });
    await fetchVehicles();
  }

  Future<List<FuelTransaction>> fetchFuelTransactions({String? vehicleId}) async {
    if (DemoMode.active) {
      _transactions = vehicleId != null
          ? DemoData.transactions.where((t) => t.vehicleId == vehicleId).toList()
          : List.from(DemoData.transactions);
      notifyListeners();
      return _transactions;
    }
    final query = <String, dynamic>{'pageSize': '50'};
    if (vehicleId != null) query['vehicleId'] = vehicleId;
    final response = await ApiClient.instance.get('/fuel-transactions', query: query);
    final list = response['data'] as List? ?? [];
    _transactions = list.map((e) => FuelTransaction.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
    return _transactions;
  }

  Future<void> insertFuelTransaction(Map<String, dynamic> data) async {
    if (DemoMode.active) {
      notifyListeners();
      return;
    }
    await ApiClient.instance.post('/fuel-transactions', body: data);
    notifyListeners();
  }

  Future<void> updateVehicleFuelLevel(String vehicleId, double newLevel) async {
    if (DemoMode.active) {
      _updateLocalFuelLevel(vehicleId, newLevel);
      return;
    }
    await ApiClient.instance.patch('/vehicles/$vehicleId', body: {'currentFuelL': newLevel});
    _updateLocalFuelLevel(vehicleId, newLevel);
  }

  void _updateLocalFuelLevel(String vehicleId, double newLevel) {
    final idx = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (idx != -1) {
      final v = _vehicles[idx];
      _vehicles[idx] = Vehicle(
        id: v.id, plateNumber: v.plateNumber, make: v.make, model: v.model,
        year: v.year, vehicleType: v.vehicleType, fuelType: v.fuelType,
        tankCapacityL: v.tankCapacityL, currentFuelL: newLevel,
        odometerKm: v.odometerKm, status: v.status,
        assignedDriverId: v.assignedDriverId,
        assignedDriverName: v.assignedDriverName,
        color: v.color, notes: v.notes,
      );
      notifyListeners();
    }
  }

  double get totalMonthlyCost {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    return _transactions
        .where((t) =>
            t.recordedAt.isAfter(firstOfMonth) &&
            t.transactionType == 'refill' &&
            t.totalCostRwf != null)
        .fold(0.0, (sum, t) => sum + (t.totalCostRwf ?? 0));
  }
}
