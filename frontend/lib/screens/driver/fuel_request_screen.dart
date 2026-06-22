import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_request_service.dart';
import '../../services/fuel_price_service.dart';
import '../../utils/constants.dart';

class FuelRequestScreen extends StatefulWidget {
  const FuelRequestScreen({super.key});

  @override
  State<FuelRequestScreen> createState() => _FuelRequestScreenState();
}

class _FuelRequestScreenState extends State<FuelRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  String? _selectedVehicleId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fuelSvc = context.read<FuelService>();
      final priceSvc = context.read<FuelPriceService>();
      final vehicles = await fuelSvc.fetchVehicles();
      await priceSvc.fetchCurrentPrices();
      if (mounted && vehicles.length == 1) {
        setState(() => _selectedVehicleId = vehicles.first.id);
      }
    });
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a vehicle')));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final reqSvc = context.read<FuelRequestService>();
      final uid = auth.currentUserId ?? '';

      await reqSvc.submitRequest(
        vehicleId: _selectedVehicleId!,
        driverId: uid,
        quantityL: double.parse(_quantityCtrl.text),
        purpose: _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.check_circle,
                  color: AppConstants.fuelGood, size: 28),
              const SizedBox(width: 8),
              Text('Request Submitted',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Your fuel request for ${_quantityCtrl.text}L has been submitted.',
                    style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 8),
                Text('Finance team will review and approve shortly.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppConstants.mediumText)),
              ],
            ),
            actions: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
        if (mounted) {
          _formKey.currentState!.reset();
          _quantityCtrl.clear();
          _purposeCtrl.clear();
          setState(() => _selectedVehicleId = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fuel = context.watch<FuelService>();
    final priceSvc = context.watch<FuelPriceService>();
    final qty = double.tryParse(_quantityCtrl.text) ?? 0;
    final estimatedCost = qty * priceSvc.petrolPrice;

    return Scaffold(
      appBar: AppBar(
        title: Text('Request Fuel',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.lightOrangeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.orangeBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.local_gas_station,
                      color: AppConstants.primaryOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Current rate: Petrol ${AppConstants.formatRWF(priceSvc.petrolPrice)}/L • Diesel ${AppConstants.formatRWF(priceSvc.dieselPrice)}/L',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppConstants.darkText),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('Vehicle',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(
                    hintText: 'Select your vehicle',
                    prefixIcon: Icon(Icons.directions_car_outlined)),
                items: fuel.vehicles
                    .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.plateNumber} — ${v.make} ${v.model}')))
                    .toList(),
                onChanged: (val) => setState(() => _selectedVehicleId = val),
                validator: (v) => v == null ? 'Select a vehicle' : null,
              ),
              const SizedBox(height: 16),
              Text('Quantity (Litres)',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _quantityCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    hintText: 'e.g. 30',
                    prefixIcon: Icon(Icons.opacity_outlined),
                    suffixText: 'L'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter quantity';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'Enter valid quantity';
                  if (d > 200) return 'Max 200L per request';
                  return null;
                },
              ),
              if (qty > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Cost:',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppConstants.mediumText)),
                      Text(AppConstants.formatRWF(estimatedCost),
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryOrange)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Purpose (Optional)',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _purposeCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'e.g. Delivery to Kigali, Field visit...',
                    prefixIcon: Icon(Icons.notes_outlined)),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: Text(_loading ? 'Submitting...' : 'Submit Request'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
