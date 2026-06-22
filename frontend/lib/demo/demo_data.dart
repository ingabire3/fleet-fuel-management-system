import '../models/profile.dart';
import '../models/vehicle.dart';
import '../models/gps_trip.dart';
import '../models/fuel_transaction.dart';
import '../models/alert.dart';
import '../models/fuel_request.dart';

class DemoData {
  // IDs match supabase_seed.sql exactly — same UUIDs in both demo and live mode.
  static const String kAdmin = 'a1111111-0000-0000-0000-000000000001';
  static const String kMgr   = 'a1111111-0000-0000-0000-000000000002';
  static const String kD1    = 'a1111111-0000-0000-0000-000000000011';
  static const String kD2    = 'a1111111-0000-0000-0000-000000000012';
  static const String kD3    = 'a1111111-0000-0000-0000-000000000013';
  static const String kV1    = 'b1111111-0000-0000-0000-000000000001';
  static const String kV2    = 'b1111111-0000-0000-0000-000000000002';
  static const String kV3    = 'b1111111-0000-0000-0000-000000000003';

  // ── Profiles ────────────────────────────────────────────────────────────────
  static final Map<String, Profile> profiles = {
    kAdmin: Profile(
      id: kAdmin,
      fullName: 'Celestin Hakizimana',
      phone: '+250788000001',
      role: 'admin',
      isApproved: true,
    ),
    kMgr: Profile(
      id: kMgr,
      fullName: 'Eric Mugisha',
      phone: '+250788000002',
      role: 'fleet_manager',
      isApproved: true,
    ),
    kD1: Profile(
      id: kD1,
      fullName: 'Jean Baptiste Niyonzima',
      phone: '+250788111001',
      role: 'driver',
      isApproved: true,
    ),
    kD2: Profile(
      id: kD2,
      fullName: 'Marie Claire Uwimana',
      phone: '+250788111002',
      role: 'driver',
      isApproved: true,
    ),
    kD3: Profile(
      id: kD3,
      fullName: 'Patrick Habimana',
      phone: '+250788111003',
      role: 'driver',
      isApproved: true,
    ),
  };

  // ── Vehicles ─────────────────────────────────────────────────────────────────
  // Driver1 → v1 (petrol, 85 km/day, 8.5 L/day)
  // Driver2 → v2 (diesel, 120 km/day, 12.0 L/day) — low fuel
  // Driver3 → v3 (diesel, 65 km/day, 6.5 L/day)
  static final List<Vehicle> vehicles = [
    Vehicle(
      id: kV1,
      plateNumber: 'RAE 001 A',
      make: 'Toyota',
      model: 'Land Cruiser',
      year: 2022,
      vehicleType: 'SUV',
      fuelType: 'petrol',
      tankCapacityL: 90,
      currentFuelL: 52,
      odometerKm: 24350,
      status: 'active',
      assignedDriverId: kD1,
      assignedDriverName: 'Jean Baptiste Niyonzima',
      color: 'White',
    ),
    Vehicle(
      id: kV2,
      plateNumber: 'RAE 002 B',
      make: 'Toyota',
      model: 'Hilux',
      year: 2021,
      vehicleType: 'Pickup',
      fuelType: 'diesel',
      tankCapacityL: 80,
      currentFuelL: 14,
      odometerKm: 31200,
      status: 'active',
      assignedDriverId: kD2,
      assignedDriverName: 'Marie Claire Uwimana',
      color: 'Silver',
    ),
    Vehicle(
      id: kV3,
      plateNumber: 'RAE 003 C',
      make: 'Isuzu',
      model: 'D-Max',
      year: 2023,
      vehicleType: 'Pickup',
      fuelType: 'diesel',
      tankCapacityL: 75,
      currentFuelL: 61,
      odometerKm: 18900,
      status: 'active',
      assignedDriverId: kD3,
      assignedDriverName: 'Patrick Habimana',
      color: 'Black',
    ),
  ];

  // ── Trips — 30 days × 3 drivers = 90 trips (June 2026) ───────────────────
  static final List<GpsTrip> trips = _buildTrips();

  static List<GpsTrip> _buildTrips() {
    final result = <GpsTrip>[];
    const y = 2026;
    const m = 6;

    for (int day = 1; day <= 30; day++) {
      // Driver 1: Kigali HQ → Musanze (85 km | 8.5 L)
      result.add(GpsTrip(
        id: 'trip-d1-$day',
        vehicleId: kV1,
        driverId: kD1,
        driverName: 'Jean Baptiste Niyonzima',
        status: 'completed',
        originName: 'NPD Kigali HQ',
        destinationName: 'Musanze Branch',
        originLat: -1.9441,
        originLng: 30.0619,
        destinationLat: -1.4994,
        destinationLng: 29.6347,
        distanceKm: 85.0,
        fuelConsumedL: 8.5,
        fuelEfficiency: 10.0,
        startedAt: DateTime(y, m, day, 7, 30),
        endedAt: DateTime(y, m, day, 9, 45),
        durationMinutes: 135,
      ));

      // Driver 2: Kigali HQ → Huye (120 km | 12.0 L)
      result.add(GpsTrip(
        id: 'trip-d2-$day',
        vehicleId: kV2,
        driverId: kD2,
        driverName: 'Marie Claire Uwimana',
        status: 'completed',
        originName: 'NPD Kigali HQ',
        destinationName: 'Huye Depot',
        originLat: -1.9441,
        originLng: 30.0619,
        destinationLat: -2.5970,
        destinationLng: 29.7392,
        distanceKm: 120.0,
        fuelConsumedL: 12.0,
        fuelEfficiency: 10.0,
        startedAt: DateTime(y, m, day, 6, 45),
        endedAt: DateTime(y, m, day, 10, 15),
        durationMinutes: 210,
      ));

      // Driver 3: Kigali HQ → Rwamagana (65 km | 6.5 L)
      result.add(GpsTrip(
        id: 'trip-d3-$day',
        vehicleId: kV3,
        driverId: kD3,
        driverName: 'Patrick Habimana',
        status: 'completed',
        originName: 'NPD Kigali HQ',
        destinationName: 'Rwamagana Station',
        originLat: -1.9441,
        originLng: 30.0619,
        destinationLat: -1.9480,
        destinationLng: 30.4346,
        distanceKm: 65.0,
        fuelConsumedL: 6.5,
        fuelEfficiency: 10.0,
        startedAt: DateTime(y, m, day, 8, 0),
        endedAt: DateTime(y, m, day, 10, 0),
        durationMinutes: 120,
      ));
    }
    return result;
  }

  // ── Transactions — 4 weekly refills per driver (June 2026) ───────────────
  static final List<FuelTransaction> transactions = _buildTransactions();

  static List<FuelTransaction> _buildTransactions() {
    final result = <FuelTransaction>[];
    const y = 2026;
    const m = 6;
    const refillDays = [1, 8, 15, 22];

    for (final day in refillDays) {
      // v1 petrol 60 L @ 1520 RWF
      result.add(FuelTransaction(
        id: 'tx-v1-$day',
        vehicleId: kV1,
        driverId: kD1,
        transactionType: 'refill',
        quantityL: 60.0,
        unitPriceRwf: 1520.0,
        totalCostRwf: 91200.0,
        odometerKm: 24350.0 + (day - 1) * 85.0,
        recordedAt: DateTime(y, m, day, 12, 0),
        notes: 'Weekly refill — Musanze route',
      ));
      // v2 diesel 80 L @ 1450 RWF
      result.add(FuelTransaction(
        id: 'tx-v2-$day',
        vehicleId: kV2,
        driverId: kD2,
        transactionType: 'refill',
        quantityL: 80.0,
        unitPriceRwf: 1450.0,
        totalCostRwf: 116000.0,
        odometerKm: 31200.0 + (day - 1) * 120.0,
        recordedAt: DateTime(y, m, day, 11, 30),
        notes: 'Weekly refill — Huye route',
      ));
      // v3 diesel 50 L @ 1450 RWF
      result.add(FuelTransaction(
        id: 'tx-v3-$day',
        vehicleId: kV3,
        driverId: kD3,
        transactionType: 'refill',
        quantityL: 50.0,
        unitPriceRwf: 1450.0,
        totalCostRwf: 72500.0,
        odometerKm: 18900.0 + (day - 1) * 65.0,
        recordedAt: DateTime(y, m, day, 13, 0),
        notes: 'Weekly refill — Rwamagana route',
      ));
    }
    return result;
  }

  // ── Fuel Requests (mutable — approve/reject/submit update this list) ──────
  static List<FuelRequest> fuelRequests = _buildFuelRequests();

  static List<FuelRequest> _buildFuelRequests() {
    final now = DateTime.now();
    return [
      FuelRequest(
        id: 'req-1',
        vehicleId: kV1,
        driverId: kD1,
        driverName: 'Jean Baptiste Niyonzima',
        vehiclePlate: 'RAE 001 A',
        requestedQuantityL: 60.0,
        purpose: 'Weekly refill — Musanze route',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      FuelRequest(
        id: 'req-2',
        vehicleId: kV2,
        driverId: kD2,
        driverName: 'Marie Claire Uwimana',
        vehiclePlate: 'RAE 002 B',
        requestedQuantityL: 80.0,
        purpose: 'Weekly refill — Huye route',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      FuelRequest(
        id: 'req-3',
        vehicleId: kV3,
        driverId: kD3,
        driverName: 'Patrick Habimana',
        vehiclePlate: 'RAE 003 C',
        requestedQuantityL: 50.0,
        purpose: 'Refill — Rwamagana route',
        status: 'approved',
        approvedBy: kMgr,
        approvedAt: now.subtract(const Duration(days: 3)),
        unitPriceRwf: 1450.0,
        createdAt: now.subtract(const Duration(days: 3, hours: 2)),
      ),
      FuelRequest(
        id: 'req-4',
        vehicleId: kV1,
        driverId: kD1,
        driverName: 'Jean Baptiste Niyonzima',
        vehiclePlate: 'RAE 001 A',
        requestedQuantityL: 60.0,
        purpose: 'Refill — Musanze route',
        status: 'approved',
        approvedBy: kMgr,
        approvedAt: now.subtract(const Duration(days: 5)),
        unitPriceRwf: 1520.0,
        createdAt: now.subtract(const Duration(days: 5, hours: 4)),
      ),
      FuelRequest(
        id: 'req-5',
        vehicleId: kV3,
        driverId: kD3,
        driverName: 'Patrick Habimana',
        vehiclePlate: 'RAE 003 C',
        requestedQuantityL: 50.0,
        purpose: null,
        status: 'rejected',
        rejectionReason: 'Missing trip log for previous week',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }

  // ── Alerts (mutable — acknowledge/resolve update this list) ──────────────
  static List<Alert> alerts = _buildAlerts();

  static List<Alert> _buildAlerts() {
    final now = DateTime.now();
    return [
      Alert(
        id: 'alert-1',
        vehicleId: kV2,
        driverId: kD2,
        alertType: 'low_fuel',
        severity: 'critical',
        status: 'open',
        title: 'Low Fuel Alert',
        description:
            'RAE 002 B fuel level at 17.5% (14 L / 80 L). Immediate refill required.',
        aiConfidence: 0.98,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      Alert(
        id: 'alert-2',
        vehicleId: kV1,
        driverId: kD1,
        alertType: 'overspeed',
        severity: 'high',
        status: 'open',
        title: 'Overspeed Detected',
        description:
            'RAE 001 A recorded 143 km/h on Kigali–Musanze highway (limit: 80 km/h).',
        aiConfidence: 0.95,
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
      ),
      Alert(
        id: 'alert-3',
        vehicleId: kV3,
        alertType: 'maintenance',
        severity: 'medium',
        status: 'acknowledged',
        title: 'Scheduled Maintenance Due',
        description:
            'RAE 003 C is due for 20,000 km service. Current odometer: 18,900 km.',
        aiConfidence: 0.88,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      Alert(
        id: 'alert-4',
        vehicleId: kV1,
        alertType: 'fuel_anomaly',
        severity: 'medium',
        status: 'resolved',
        title: 'Unusual Fuel Consumption',
        description:
            'RAE 001 A consumed 15% more fuel than expected on June 3 trip.',
        aiConfidence: 0.79,
        resolvedBy: kAdmin,
        resolvedAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  // ── Pending users (mutable — admin approve/add updates this list) ─────────
  static List<Map<String, dynamic>> pendingUsers = [
    {
      'id': 'pending-1',
      'full_name': 'Alice Mukamana',
      'email': 'alice.mukamana@gmail.com',
      'phone': '+250788123456',
      'role': 'driver',
      'is_approved': false,
    },
    {
      'id': 'pending-2',
      'full_name': 'David Nkurunziza',
      'email': 'david.nkurunziza@gmail.com',
      'phone': '+250721654321',
      'role': 'driver',
      'is_approved': false,
    },
  ];
}
