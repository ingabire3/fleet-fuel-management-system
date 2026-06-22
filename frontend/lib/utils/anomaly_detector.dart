import '../models/fuel_transaction.dart';
import '../models/vehicle.dart';
import '../models/gps_trip.dart';

class AnomalyDetector {
  static List<Map<String, dynamic>> checkFuelTransaction({
    required FuelTransaction transaction,
    required Vehicle vehicle,
    required List<GpsTrip> recentTrips,
  }) {
    final List<Map<String, dynamic>> alerts = [];

    if (transaction.transactionType == 'usage') {
      final dropPercent = transaction.quantityL / vehicle.tankCapacityL;
      if (dropPercent > 0.5 && recentTrips.isEmpty) {
        alerts.add({
          'alert_type': 'possible_theft',
          'severity': 'critical',
          'title': 'Possible fuel theft — ${vehicle.plateNumber}',
          'description':
              'Fuel dropped ${transaction.quantityL}L (${(dropPercent * 100).toStringAsFixed(0)}% of tank) with no trip recorded in the last 4 hours.',
          'ai_confidence': 0.88,
          'vehicle_id': vehicle.id,
        });
      }
    }

    if (transaction.fuelLevelAfter != null) {
      final levelPercent = transaction.fuelLevelAfter! / vehicle.tankCapacityL;
      if (levelPercent < 0.15) {
        alerts.add({
          'alert_type': 'low_fuel',
          'severity': levelPercent < 0.08 ? 'critical' : 'high',
          'title': 'Low fuel — ${vehicle.plateNumber}',
          'description':
              '${vehicle.plateNumber} (${vehicle.make} ${vehicle.model}) has only ${transaction.fuelLevelAfter!.toStringAsFixed(1)}L remaining (${(levelPercent * 100).toStringAsFixed(0)}% of ${vehicle.tankCapacityL}L capacity).',
          'ai_confidence': 1.0,
          'vehicle_id': vehicle.id,
        });
      }
    }

    if (transaction.fuelLevelBefore != null &&
        transaction.fuelLevelAfter != null) {
      final drop = transaction.fuelLevelBefore! - transaction.fuelLevelAfter!;
      if (drop > 40 && transaction.transactionType == 'usage') {
        alerts.add({
          'alert_type': 'rapid_fuel_drop',
          'severity': 'high',
          'title': 'Rapid fuel drop — ${vehicle.plateNumber}',
          'description':
              'Fuel level dropped ${drop.toStringAsFixed(1)}L in a single usage entry. Verify with driver.',
          'ai_confidence': 0.75,
          'vehicle_id': vehicle.id,
        });
      }
    }

    return alerts;
  }

  static String getEfficiencyRating(double kmPerL, String vehicleType) {
    final threshold = vehicleType == 'truck' ? 3.0 : 4.0;
    if (kmPerL >= threshold * 1.2) return 'Excellent';
    if (kmPerL >= threshold) return 'Good';
    if (kmPerL >= threshold * 0.8) return 'Below average';
    return 'Poor — check vehicle';
  }
}
