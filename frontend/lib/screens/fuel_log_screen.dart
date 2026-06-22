import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/fuel_service.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../models/vehicle.dart';
import '../models/fuel_transaction.dart';
import '../utils/constants.dart';
import '../utils/anomaly_detector.dart';

class FuelLogScreen extends StatefulWidget {
  const FuelLogScreen({super.key});

  @override
  State<FuelLogScreen> createState() => _FuelLogScreenState();
}

class _FuelLogScreenState extends State<FuelLogScreen> {
  final _quantityCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fuelBeforeCtrl = TextEditingController();

  Vehicle? _selectedVehicle;
  String _type = 'refill';
  bool _loading = false;
  double _totalCost = 0;

  @override
  void initState() {
    super.initState();
    _quantityCtrl.addListener(_recalcTotal);
    _unitPriceCtrl.addListener(_recalcTotal);
  }

  void _recalcTotal() {
    final qty = double.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_unitPriceCtrl.text) ?? 0;
    setState(() => _totalCost = qty * price);
  }

  Future<void> _submit() async {
    if (_selectedVehicle == null) {
      _snack('Select a vehicle first');
      return;
    }
    final qty = double.tryParse(_quantityCtrl.text);
    if (qty == null || qty <= 0) {
      _snack('Enter a valid quantity');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final fuelSvc = context.read<FuelService>();
      final alertSvc = context.read<AlertService>();
      final tripSvc = context.read<TripService>();

      final fuelBefore =
          double.tryParse(_fuelBeforeCtrl.text) ?? _selectedVehicle!.currentFuelL;
      final fuelAfter = _type == 'refill'
          ? (fuelBefore + qty).clamp(0, _selectedVehicle!.tankCapacityL)
          : (fuelBefore - qty).clamp(0.0, _selectedVehicle!.tankCapacityL);

      final txData = {
        'vehicle_id': _selectedVehicle!.id,
        'driver_id': auth.getCurrentUser()?.id,
        'transaction_type': _type,
        'quantity_l': qty,
        'unit_price_rwf':
            _type == 'refill' ? double.tryParse(_unitPriceCtrl.text) : null,
        'total_cost_rwf': _type == 'refill' ? _totalCost : null,
        'odometer_km': double.tryParse(_odometerCtrl.text),
        'fuel_level_before': fuelBefore,
        'fuel_level_after': fuelAfter,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'recorded_at': DateTime.now().toIso8601String(),
      };

      await fuelSvc.insertFuelTransaction(txData);
      await fuelSvc.updateVehicleFuelLevel(_selectedVehicle!.id, fuelAfter.toDouble());

      final tx = FuelTransaction(
        id: '',
        vehicleId: _selectedVehicle!.id,
        driverId: auth.getCurrentUser()?.id,
        transactionType: _type,
        quantityL: qty,
        unitPriceRwf: double.tryParse(_unitPriceCtrl.text),
        totalCostRwf: _totalCost,
        fuelLevelBefore: fuelBefore,
        fuelLevelAfter: fuelAfter.toDouble(),
        recordedAt: DateTime.now(),
      );

      final fourHoursAgo = DateTime.now().subtract(const Duration(hours: 4));
      final recentTrips = tripSvc.trips
          .where((t) =>
              t.vehicleId == _selectedVehicle!.id &&
              t.startedAt != null &&
              t.startedAt!.isAfter(fourHoursAgo))
          .toList();

      final anomalies = AnomalyDetector.checkFuelTransaction(
        transaction: tx,
        vehicle: _selectedVehicle!,
        recentTrips: recentTrips,
      );

      for (final a in anomalies) {
        await alertSvc.insertAlert({
          ...a,
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;

      if (anomalies.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppConstants.severityHigh),
                const SizedBox(width: 8),
                Text('Anomalies Detected',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: anomalies
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle, size: 8,
                                color: AppConstants.severityHigh),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a['title'] as String,
                                  style: GoogleFonts.poppins(fontSize: 13)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      _snack('Fuel entry logged successfully', success: true);
      _reset();
    } catch (e) {
      _snack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? AppConstants.fuelGood : AppConstants.severityCritical,
    ));
  }

  void _reset() {
    _quantityCtrl.clear();
    _unitPriceCtrl.clear();
    _odometerCtrl.clear();
    _notesCtrl.clear();
    _fuelBeforeCtrl.clear();
    setState(() {
      _selectedVehicle = null;
      _type = 'refill';
      _totalCost = 0;
    });
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _unitPriceCtrl.dispose();
    _odometerCtrl.dispose();
    _notesCtrl.dispose();
    _fuelBeforeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<FuelService>().vehicles;

    return Scaffold(
      appBar: AppBar(
        title: Text('Log Fuel Entry',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Vehicle'),
            DropdownButtonFormField<Vehicle>(
              initialValue: _selectedVehicle,
              decoration: const InputDecoration(
                hintText: 'Select vehicle',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              items: vehicles
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          '${v.plateNumber} — ${v.make} ${v.model}',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVehicle = v),
            ),
            const SizedBox(height: 16),
            _label('Transaction Type'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'refill',
                  label: Text('Refill'),
                  icon: Icon(Icons.local_gas_station),
                ),
                ButtonSegment(
                  value: 'usage',
                  label: Text('Usage'),
                  icon: Icon(Icons.speed),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppConstants.primaryOrange
                        : null),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : AppConstants.primaryOrange),
              ),
            ),
            const SizedBox(height: 16),
            _label('Current Fuel Level (L)'),
            TextField(
              controller: _fuelBeforeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: _selectedVehicle != null
                    ? '${_selectedVehicle!.currentFuelL.toStringAsFixed(1)} L (current)'
                    : 'Fuel before transaction (L)',
                prefixIcon: const Icon(Icons.water_drop_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _label('Quantity (Litres)'),
            TextField(
              controller: _quantityCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.0',
                prefixIcon: Icon(Icons.opacity),
                suffixText: 'L',
              ),
            ),
            if (_type == 'refill') ...[
              const SizedBox(height: 16),
              _label('Unit Price (RWF)'),
              TextField(
                controller: _unitPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: 'RWF ',
                ),
              ),
              if (_totalCost > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.lightOrangeBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppConstants.orangeBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Cost',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppConstants.mediumText)),
                      Text(
                        AppConstants.formatRWF(_totalCost),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            _label('Odometer (km)'),
            TextField(
              controller: _odometerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.speed_outlined),
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 16),
            _label('Notes (optional)'),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Additional notes...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_loading ? 'Saving...' : 'Log Fuel Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppConstants.darkText,
          ),
        ),
      );
}
