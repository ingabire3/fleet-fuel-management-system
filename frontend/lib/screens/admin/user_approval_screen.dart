import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class UserApprovalScreen extends StatefulWidget {
  const UserApprovalScreen({super.key});

  @override
  State<UserApprovalScreen> createState() => _UserApprovalScreenState();
}

class _UserApprovalScreenState extends State<UserApprovalScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pending = await context.read<AuthService>().fetchPendingDrivers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve Driver',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Approve $name as a driver?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AuthService>().approveDriver(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name approved'),
          backgroundColor: AppConstants.fuelGood,
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Approvals',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppConstants.primaryOrange))
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: _pending.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 56, color: AppConstants.fuelGood),
                          const SizedBox(height: 12),
                          Text('No pending approvals',
                              style: GoogleFonts.poppins(
                                  color: AppConstants.mediumText)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pending.length,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemBuilder: (_, i) {
                        final p = _pending[i];
                        final name = (p['fullName'] ?? p['full_name']) as String? ?? 'Unknown';
                        final email = p['email'] as String? ?? '';
                        final phone = p['phone'] as String? ?? '';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppConstants.lightOrangeBg,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryOrange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      if (email.isNotEmpty)
                                        Text(email,
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppConstants.mediumText)),
                                      if (phone.isNotEmpty)
                                        Text(phone,
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: AppConstants.mediumText)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _approve(p['id'] as String, name),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
