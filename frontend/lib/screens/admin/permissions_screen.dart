import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../utils/constants.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  List<Map<String, dynamic>> _managers = [];
  bool _loading = true;

  static const _perms = [
    ('VEHICLE_MANAGEMENT', 'Vehicle Management', Icons.directions_car_outlined),
    ('FINANCIAL_MANAGEMENT', 'Financial Management', Icons.account_balance_outlined),
    ('DRIVER_MANAGEMENT', 'Driver Management', Icons.people_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/users', query: {
        'role': 'FLEET_MANAGER',
        'isApproved': 'true',
        'pageSize': '100',
      });
      final list = (r['data'] as List?) ?? [];
      // For each FM, also load their permissions
      final managers = list.cast<Map<String, dynamic>>();
      for (final m in managers) {
        try {
          final pr = await ApiClient.instance.get('/users/${m['id']}/permissions');
          m['_permissions'] = (pr['data'] as List?) ?? [];
        } catch (_) {
          m['_permissions'] = <dynamic>[];
        }
      }
      if (mounted) setState(() { _managers = managers; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  bool _hasPermission(Map<String, dynamic> manager, String perm) {
    final perms = manager['_permissions'] as List? ?? [];
    return perms.any((p) =>
        p['permission'] == perm && p['revokedAt'] == null);
  }

  Future<void> _toggle(Map<String, dynamic> manager, String perm, bool current) async {
    final name = (manager['fullName'] ?? manager['full_name']) as String? ?? 'this user';
    final permLabel = _perms.firstWhere((p) => p.$1 == perm).$2;
    final action = current ? 'Revoke' : 'Grant';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action Permission',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            '$action "$permLabel" ${current ? 'from' : 'to'} $name?',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: current ? Colors.red : AppConstants.primaryOrange),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      if (current) {
        await ApiClient.instance.delete('/users/${manager['id']}/permissions/$perm');
      } else {
        await ApiClient.instance.post('/users/${manager['id']}/permissions',
            body: {'permission': perm});
      }
      await _load();
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
        title: Text('FM Permissions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryOrange))
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: _managers.isEmpty
                  ? Center(
                      child: Text('No Fleet Managers found',
                          style: GoogleFonts.poppins(color: AppConstants.mediumText)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _managers.length,
                      itemBuilder: (_, i) {
                        final m = _managers[i];
                        final name = (m['fullName'] ?? m['full_name']) as String? ?? 'Unknown';
                        final email = m['email'] as String? ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                    backgroundColor: AppConstants.lightOrangeBg,
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: GoogleFonts.poppins(
                                            color: AppConstants.primaryOrange,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold, fontSize: 14)),
                                        if (email.isNotEmpty)
                                          Text(email,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11, color: AppConstants.mediumText)),
                                      ],
                                    ),
                                  ),
                                ]),
                                const Divider(height: 20),
                                Text('Permissions',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.mediumText)),
                                const SizedBox(height: 6),
                                ..._perms.map((p) {
                                  final has = _hasPermission(m, p.$1);
                                  return SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    secondary: Icon(p.$3,
                                        color: has ? AppConstants.primaryOrange : Colors.grey,
                                        size: 20),
                                    title: Text(p.$2,
                                        style: GoogleFonts.poppins(fontSize: 13)),
                                    value: has,
                                    activeThumbColor: AppConstants.primaryOrange,
                                    onChanged: (_) => _toggle(m, p.$1, has),
                                  );
                                }),
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
