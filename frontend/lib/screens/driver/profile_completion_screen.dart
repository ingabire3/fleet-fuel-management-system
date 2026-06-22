import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

/// Shown once after first driver login when profile setup is incomplete.
/// Driver picks home and work GPS coordinates on OpenStreetMap.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _homeAddressCtrl = TextEditingController();
  final _workSiteNameCtrl = TextEditingController();

  LatLng? _homePick;
  LatLng? _workPick;
  bool _pickingHome = true; // true = next tap sets home, false = sets work
  bool _submitting = false;

  static const _defaultCenter = LatLng(-1.9441, 30.0619); // Kigali
  static const _defaultZoom = 13.0;

  @override
  void dispose() {
    _homeAddressCtrl.dispose();
    _workSiteNameCtrl.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_pickingHome) {
        _homePick = point;
      } else {
        _workPick = point;
      }
    });
  }

  Future<void> _submit() async {
    if (_homePick == null || _workPick == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pin both home and work locations on the map')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      await auth.completeDriverProfile(
        homeLat: _homePick!.latitude,
        homeLng: _homePick!.longitude,
        homeAddress: _homeAddressCtrl.text.trim().isEmpty ? null : _homeAddressCtrl.text.trim(),
        workSiteLat: _workPick!.latitude,
        workSiteLng: _workPick!.longitude,
        workSiteName: _workSiteNameCtrl.text.trim().isEmpty ? null : _workSiteNameCtrl.text.trim(),
      );
      // Auth service updated _currentProfile — Navigator pops handled by
      // the root widget watching AuthService.currentProfile.isProfileComplete.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile complete! Welcome aboard.'),
            backgroundColor: AppConstants.fuelGood,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bothPicked = _homePick != null && _workPick != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Complete Your Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppConstants.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Instruction banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppConstants.lightOrangeBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set your locations to enable fuel allocation.',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppConstants.darkText)),
                const SizedBox(height: 4),
                Row(children: [
                  _StepChip(
                    label: '1. Home',
                    done: _homePick != null,
                    active: _pickingHome,
                  ),
                  const SizedBox(width: 8),
                  _StepChip(
                    label: '2. Work',
                    done: _workPick != null,
                    active: !_pickingHome,
                  ),
                ]),
              ],
            ),
          ),
          // Toggle which pin to place
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(
                child: _ToggleBtn(
                  label: 'Place Home Pin',
                  icon: Icons.home_outlined,
                  active: _pickingHome,
                  onTap: () => setState(() => _pickingHome = true),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleBtn(
                  label: 'Place Work Pin',
                  icon: Icons.work_outline,
                  active: !_pickingHome,
                  onTap: () => setState(() => _pickingHome = false),
                  color: Colors.green,
                ),
              ),
            ]),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: _defaultZoom,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'rw.npd.npd_fuel_monitor',
                ),
                MarkerLayer(markers: [
                  if (_homePick != null)
                    Marker(
                      point: _homePick!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.home, color: Colors.blue, size: 36),
                    ),
                  if (_workPick != null)
                    Marker(
                      point: _workPick!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.work, color: Colors.green, size: 36),
                    ),
                ]),
              ],
            ),
          ),
          // Address labels + submit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _homeAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Home Address (optional)',
                    prefixIcon: Icon(Icons.home_outlined, color: Colors.blue),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _workSiteNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Work Site Name (optional)',
                    prefixIcon: Icon(Icons.work_outline, color: Colors.green),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (_homePick != null)
                  _CoordRow(
                    icon: Icons.home,
                    color: Colors.blue,
                    label: 'Home',
                    lat: _homePick!.latitude,
                    lng: _homePick!.longitude,
                  ),
                if (_workPick != null)
                  _CoordRow(
                    icon: Icons.work,
                    color: Colors.green,
                    label: 'Work',
                    lat: _workPick!.latitude,
                    lng: _workPick!.longitude,
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: bothPicked && !_submitting ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_submitting ? 'Saving…' : 'Complete Profile'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: bothPicked ? AppConstants.primaryOrange : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  const _StepChip({required this.label, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppConstants.fuelGood
        : active
            ? AppConstants.primaryOrange
            : AppConstants.mediumText;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color color;
  const _ToggleBtn({required this.label, required this.icon, required this.active, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          border: Border.all(color: active ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? color : Colors.grey, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: active ? color : Colors.grey,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double lat;
  final double lng;
  const _CoordRow({required this.icon, required this.color, required this.label, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$label: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText)),
      ]),
    );
  }
}
