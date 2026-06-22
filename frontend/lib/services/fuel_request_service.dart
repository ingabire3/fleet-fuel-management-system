import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../demo/demo_data.dart';
import '../models/fuel_request.dart';
import 'api_client.dart';

class FuelRequestService extends ChangeNotifier {
  List<FuelRequest> _requests = [];
  List<FuelRequest> get requests => _requests;

  int get pendingCount =>
      _requests.where((r) => r.status == 'pending' || r.status == 'fm_approved').length;

  Future<List<FuelRequest>> fetchAll() async {
    if (DemoMode.active) {
      _requests = List.from(DemoData.fuelRequests);
      notifyListeners();
      return _requests;
    }
    final response = await ApiClient.instance.get('/fuel-requests');
    final list = response['data'] as List;
    _requests = list.map((e) => FuelRequest.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
    return _requests;
  }

  Future<List<FuelRequest>> fetchByDriver(String driverId) async {
    if (DemoMode.active) {
      _requests = DemoData.fuelRequests
          .where((r) => r.driverId == driverId)
          .toList();
      notifyListeners();
      return _requests;
    }
    final response = await ApiClient.instance.get('/fuel-requests');
    final list = response['data'] as List;
    _requests = list.map((e) => FuelRequest.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
    return _requests;
  }

  Future<List<FuelRequest>> fetchPending() async {
    if (DemoMode.active) {
      _requests = DemoData.fuelRequests
          .where((r) => r.status == 'pending')
          .toList();
      notifyListeners();
      return _requests;
    }
    final r1 = await ApiClient.instance.get('/fuel-requests', query: {'status': 'PENDING'});
    final r2 = await ApiClient.instance.get('/fuel-requests', query: {'status': 'FLEET_MANAGER_APPROVED'});
    final list1 = (r1['data'] as List).map((e) => FuelRequest.fromJson(e as Map<String, dynamic>));
    final list2 = (r2['data'] as List).map((e) => FuelRequest.fromJson(e as Map<String, dynamic>));
    _requests = [...list1, ...list2];
    notifyListeners();
    return _requests;
  }

  Future<void> submitRequest({
    required String vehicleId,
    required String driverId,
    required double quantityL,
    String? purpose,
  }) async {
    if (DemoMode.active) {
      final vehicle = DemoData.vehicles.firstWhere(
        (v) => v.id == vehicleId,
        orElse: () => DemoData.vehicles.first,
      );
      final driver = DemoData.profiles[driverId];
      final newReq = FuelRequest(
        id: 'req-${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: vehicleId,
        driverId: driverId,
        driverName: driver?.fullName,
        vehiclePlate: vehicle.plateNumber,
        requestedQuantityL: quantityL,
        purpose: purpose,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      DemoData.fuelRequests.insert(0, newReq);
      _requests = DemoData.fuelRequests
          .where((r) => r.driverId == driverId)
          .toList();
      notifyListeners();
      return;
    }
    await ApiClient.instance.post('/fuel-requests', body: {
      'requestedQuantityL': quantityL,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
    });
    notifyListeners();
  }

  Future<void> approve({
    required String requestId,
    required String status,
    required String approvedBy,
    required double unitPriceRwf,
  }) async {
    if (DemoMode.active) {
      _mutateRequest(requestId, (old) => FuelRequest(
        id: old.id,
        vehicleId: old.vehicleId,
        driverId: old.driverId,
        driverName: old.driverName,
        vehiclePlate: old.vehiclePlate,
        requestedQuantityL: old.requestedQuantityL,
        purpose: old.purpose,
        status: 'approved',
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        unitPriceRwf: unitPriceRwf,
        createdAt: old.createdAt,
      ));
      return;
    }
    final endpoint = status == 'fm_approved'
        ? '/fuel-requests/$requestId/finance-decision'
        : '/fuel-requests/$requestId/fleet-manager-decision';
    await ApiClient.instance.patch(endpoint, body: {'approve': true});
    notifyListeners();
  }

  Future<void> reject({
    required String requestId,
    required String status,
    required String reason,
  }) async {
    if (DemoMode.active) {
      _mutateRequest(requestId, (old) => FuelRequest(
        id: old.id,
        vehicleId: old.vehicleId,
        driverId: old.driverId,
        driverName: old.driverName,
        vehiclePlate: old.vehiclePlate,
        requestedQuantityL: old.requestedQuantityL,
        purpose: old.purpose,
        status: 'rejected',
        rejectionReason: reason,
        createdAt: old.createdAt,
      ));
      return;
    }
    final endpoint = status == 'fm_approved'
        ? '/fuel-requests/$requestId/finance-decision'
        : '/fuel-requests/$requestId/fleet-manager-decision';
    await ApiClient.instance.patch(endpoint, body: {
      'approve': false,
      'rejectionReason': reason.isNotEmpty ? reason : 'Rejected',
    });
    notifyListeners();
  }

  void _mutateRequest(String id, FuelRequest Function(FuelRequest) update) {
    final idx = DemoData.fuelRequests.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    DemoData.fuelRequests[idx] = update(DemoData.fuelRequests[idx]);
    _requests = DemoData.fuelRequests
        .where((r) => r.status == 'pending')
        .toList();
    notifyListeners();
  }
}
