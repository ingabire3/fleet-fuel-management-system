import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/fuel_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import '../widgets/vehicle_card_widget.dart';
import '../widgets/shimmer_loader_widget.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _query = '';

  // Must match the live DB's `vehicle_type` enum labels exactly (22P02 if not).
  static const _vehicleTypes = ['truck', 'pickup', 'suv', 'sedan', 'motorcycle', 'bus'];
  static const _fuelTypes = ['petrol', 'diesel'];

  Future<void> _showAssignDriverDialog(Vehicle vehicle) async {
    List<Map<String, dynamic>> drivers = [];
    bool loadingDrivers = true;
    String? selectedDriverId = vehicle.assignedDriverId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (loadingDrivers) {
            ApiClient.instance.get('/users', query: {
              'role': 'DRIVER',
              'isApproved': 'true',
              'pageSize': '100',
            }).then((r) {
              final list = (r['data'] as List?) ?? [];
              setS(() {
                drivers = list.cast<Map<String, dynamic>>();
                loadingDrivers = false;
              });
            }).catchError((Object _) { setS(() => loadingDrivers = false); });
          }
          return AlertDialog(
            title: Text('Assign Driver — ${vehicle.plateNumber}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            content: loadingDrivers
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : drivers.isEmpty
                    ? Text('No approved drivers found',
                        style: GoogleFonts.poppins(color: AppConstants.mediumText))
                    : SizedBox(
                        width: double.maxFinite,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (vehicle.assignedDriverId != null)
                              ListTile(
                                leading: const Icon(Icons.person_off_outlined, color: Colors.red),
                                title: Text('Unassign current driver',
                                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 13)),
                                onTap: () {
                                  setS(() => selectedDriverId = null);
                                  Navigator.pop(ctx, 'unassign');
                                },
                              ),
                            ...drivers.map((d) {
                              final name = (d['fullName'] ?? d['full_name']) as String? ?? 'Unknown';
                              final email = d['email'] as String? ?? '';
                              final isSelected = d['id'] == selectedDriverId;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppConstants.primaryOrange
                                      : AppConstants.lightOrangeBg,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: GoogleFonts.poppins(
                                        color: isSelected ? Colors.white : AppConstants.primaryOrange,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(name,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(email,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: AppConstants.mediumText)),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AppConstants.primaryOrange)
                                    : null,
                                onTap: () => Navigator.pop(ctx, d['id'] as String),
                              );
                            }),
                          ],
                        ),
                      ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
            ],
          );
        },
      ),
    ).then((result) async {
      if (result == null || !mounted) return;
      final newDriverId = result == 'unassign' ? null : result as String;
      try {
        await context.read<FuelService>().assignDriver(vehicle.id, newDriverId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newDriverId == null
                ? '${vehicle.plateNumber} unassigned'
                : 'Driver assigned to ${vehicle.plateNumber}'),
            backgroundColor: AppConstants.fuelGood,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    });
  }

  Future<void> _showAddVehicleDialog() async {
    final plateCtrl = TextEditingController();
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());
    final tankCtrl = TextEditingController();
    String vehicleType = _vehicleTypes.first;
    String fuelType = _fuelTypes.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Vehicle',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Plate Number *',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: makeCtrl,
                      decoration: const InputDecoration(labelText: 'Make *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(labelText: 'Model *'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: tankCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tank Capacity (L) *'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: vehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: _vehicleTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => vehicleType = v ?? vehicleType),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: fuelType,
                  decoration: const InputDecoration(labelText: 'Fuel Type'),
                  items: _fuelTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => fuelType = v ?? fuelType),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (plateCtrl.text.trim().isEmpty ||
                    makeCtrl.text.trim().isEmpty ||
                    modelCtrl.text.trim().isEmpty ||
                    int.tryParse(yearCtrl.text.trim()) == null ||
                    double.tryParse(tankCtrl.text.trim()) == null) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<FuelService>().addVehicle(
            plateNumber: plateCtrl.text.trim().toUpperCase(),
            make: makeCtrl.text.trim(),
            model: modelCtrl.text.trim(),
            year: int.parse(yearCtrl.text.trim()),
            vehicleType: vehicleType,
            fuelType: fuelType,
            tankCapacityL: double.parse(tankCtrl.text.trim()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${plateCtrl.text.trim().toUpperCase()} added to fleet'),
          backgroundColor: AppConstants.fuelGood,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await context.read<FuelService>().fetchVehicles();
    if (mounted) setState(() => _loading = false);
  }

  List<Vehicle> get _filtered {
    final vehicles = context.read<FuelService>().vehicles;
    if (_query.isEmpty) return vehicles;
    final q = _query.toLowerCase();
    return vehicles
        .where((v) =>
            v.plateNumber.toLowerCase().contains(q) ||
            v.make.toLowerCase().contains(q) ||
            v.model.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().currentProfile;
    final isAdmin = profile?.isAdmin ?? false;
    final vehicles = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fleet Vehicles',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: AppConstants.primaryOrange,
              onPressed: _showAddVehicleDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by plate, make or model...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerLoader(count: 5)
                : RefreshIndicator(
                    color: AppConstants.primaryOrange,
                    onRefresh: _load,
                    child: vehicles.isEmpty
                        ? _empty()
                        : ListView.builder(
                            itemCount: vehicles.length,
                            itemBuilder: (_, i) => isAdmin
                                ? Stack(children: [
                                    VehicleCard(vehicle: vehicles[i]),
                                    Positioned(
                                      top: 4, right: 4,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _showAssignDriverDialog(vehicles[i]),
                                        icon: const Icon(Icons.person_add_outlined, size: 16),
                                        label: Text(
                                          vehicles[i].assignedDriverId == null
                                              ? 'Assign driver'
                                              : 'Change driver',
                                          style: GoogleFonts.poppins(fontSize: 11),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppConstants.primaryOrange,
                                          backgroundColor:
                                              AppConstants.lightOrangeBg,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                    ),
                                  ])
                                : VehicleCard(vehicle: vehicles[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 56, color: AppConstants.mediumText),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty ? 'No vehicles found' : 'No results for "$_query"',
              style: GoogleFonts.poppins(color: AppConstants.mediumText),
            ),
          ],
        ),
      );
}
