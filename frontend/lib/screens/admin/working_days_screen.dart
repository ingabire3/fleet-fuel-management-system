import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../utils/constants.dart';

class WorkingDaysScreen extends StatefulWidget {
  const WorkingDaysScreen({super.key});

  @override
  State<WorkingDaysScreen> createState() => _WorkingDaysScreenState();
}

double _n(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class _WorkingDaysScreenState extends State<WorkingDaysScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/users', query: {
        'role': 'DRIVER',
        'isApproved': 'true',
        'pageSize': '100',
      });
      final list = (r['data'] as List?) ?? [];
      if (mounted) setState(() { _drivers = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> driver) async {
    final name = (driver['fullName'] ?? driver['full_name']) as String? ?? 'driver';
    final currentDays = driver['workingDaysPerMonth'] as int?;
    final currentBudget = _n(driver['monthlyBudgetRwf']);
    final currentStipend = _n(driver['monthlyFuelStipendRwf']);
    final daysCtrl = TextEditingController(text: currentDays?.toString() ?? '');
    final budgetCtrl = TextEditingController(
        text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');
    final stipendCtrl = TextEditingController(
        text: currentStipend > 0 ? currentStipend.toStringAsFixed(0) : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Allocation — $name',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.lightOrangeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Working days and budget determine the monthly fuel allocation.\n'
                  'Formula: (Home↔Work × days) + 20% buffer',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Working days per month',
                  hintText: '1–31',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly budget (RWF)',
                  hintText: 'e.g. 400000',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stipendCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly fuel stipend (RWF)',
                  hintText: 'e.g. 150000',
                  prefixIcon: Icon(Icons.local_gas_station_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final days = int.tryParse(daysCtrl.text.trim());
    if (days != null && (days < 1 || days > 31)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Working days must be 1–31')));
      return;
    }

    final budget = double.tryParse(budgetCtrl.text.trim());
    final stipend = double.tryParse(stipendCtrl.text.trim());

    try {
      // Update working days via PATCH /users/:id
      if (days != null && days != currentDays) {
        await ApiClient.instance.patch('/users/${driver['id']}',
            body: {'workingDaysPerMonth': days});
      }
      // Update budget/stipend via PATCH /users/:id/stipend
      if (budget != null || stipend != null) {
        final stipendBody = <String, dynamic>{};
        if (stipend != null) stipendBody['monthlyFuelStipendRwf'] = stipend;
        if (budget != null) stipendBody['monthlyBudgetRwf'] = budget;
        await ApiClient.instance.patch('/users/${driver['id']}/stipend', body: stipendBody);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name allocation updated'),
          backgroundColor: AppConstants.fuelGood,
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Allocation Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryOrange))
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: _drivers.isEmpty
                  ? Center(
                      child: Text('No approved drivers',
                          style: GoogleFonts.poppins(color: AppConstants.mediumText)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _drivers.length,
                      itemBuilder: (_, i) {
                        final d = _drivers[i];
                        final name = (d['fullName'] ?? d['full_name']) as String? ?? 'Unknown';
                        final email = d['email'] as String? ?? '';
                        final days = d['workingDaysPerMonth'] as int?;
                        final rawBudget = _n(d['monthlyBudgetRwf']);
                        final budget = rawBudget > 0 ? rawBudget : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppConstants.lightOrangeBg,
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                      color: AppConstants.primaryOrange,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(name,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: AppConstants.mediumText)),
                                if (budget != null && budget > 0)
                                  Text(
                                    'Budget: ${AppConstants.formatRWF(budget)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 10, color: AppConstants.primaryOrange),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: days != null
                                        ? AppConstants.primaryOrange.withValues(alpha: 0.12)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    days != null ? '$days days' : 'Not set',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: days != null
                                            ? AppConstants.primaryOrange
                                            : AppConstants.mediumText),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined,
                                    size: 18, color: AppConstants.mediumText),
                              ],
                            ),
                            onTap: () => _edit(d),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
