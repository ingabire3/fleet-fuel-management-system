import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/fuel_price_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class PriceSettingScreen extends StatefulWidget {
  const PriceSettingScreen({super.key});

  @override
  State<PriceSettingScreen> createState() => _PriceSettingScreenState();
}

class _PriceSettingScreenState extends State<PriceSettingScreen> {
  late TextEditingController _petrolCtrl;
  late TextEditingController _dieselCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final svc = context.read<FuelPriceService>();
    _petrolCtrl =
        TextEditingController(text: svc.petrolPrice.toStringAsFixed(0));
    _dieselCtrl =
        TextEditingController(text: svc.dieselPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _petrolCtrl.dispose();
    _dieselCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final petrol = double.tryParse(_petrolCtrl.text);
    final diesel = double.tryParse(_dieselCtrl.text);
    if (petrol == null || diesel == null || petrol <= 0 || diesel <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid prices')));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = context.read<AuthService>().getCurrentUser()!.id;
      final svc = context.read<FuelPriceService>();
      await Future.wait([
        svc.setPrice(fuelType: 'petrol', priceRwf: petrol, setBy: uid),
        svc.setPrice(fuelType: 'diesel', priceRwf: diesel, setBy: uid),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fuel prices updated'),
          backgroundColor: AppConstants.fuelGood,
        ));
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Fuel Prices",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
                const Icon(Icons.info_outline,
                    color: AppConstants.primaryOrange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Set today\'s fuel prices in RWF per litre. These prices apply to all fuel approvals today.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppConstants.mediumText),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Petrol Price (RWF/L)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _petrolCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.local_gas_station_outlined),
                prefixText: 'RWF ',
                suffixText: '/L',
              ),
            ),
            const SizedBox(height: 16),
            Text('Diesel Price (RWF/L)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _dieselCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.local_gas_station_outlined),
                prefixText: 'RWF ',
                suffixText: '/L',
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_loading ? 'Saving...' : 'Save Prices'),
            ),
          ],
        ),
      ),
    );
  }
}
