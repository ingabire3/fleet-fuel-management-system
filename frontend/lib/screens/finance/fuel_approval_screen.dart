import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/fuel_request_service.dart';
import '../../services/fuel_price_service.dart';
import '../../services/auth_service.dart';
import '../../models/fuel_request.dart';
import '../../utils/constants.dart';
import '../../widgets/shimmer_loader_widget.dart';

class FuelApprovalScreen extends StatefulWidget {
  const FuelApprovalScreen({super.key});

  @override
  State<FuelApprovalScreen> createState() => _FuelApprovalScreenState();
}

class _FuelApprovalScreenState extends State<FuelApprovalScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        context.read<FuelRequestService>().fetchPending(),
        context.read<FuelPriceService>().fetchCurrentPrices(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve(FuelRequest req) async {
    final priceService = context.read<FuelPriceService>();
    final reqService = context.read<FuelRequestService>();
    final auth = context.read<AuthService>();

    final vehicle = req.vehiclePlate ?? 'vehicle';
    final price = priceService.petrolPrice;
    final total = req.requestedQuantityL * price;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve Fuel Request',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('Vehicle', vehicle),
            _InfoRow('Driver', req.driverName ?? 'Unknown'),
            _InfoRow('Quantity', '${req.requestedQuantityL}L'),
            _InfoRow('Unit Price', AppConstants.formatRWF(price)),
            _InfoRow('Total Cost', AppConstants.formatRWF(total)),
            if (req.purpose != null) _InfoRow('Purpose', req.purpose!),
            const SizedBox(height: 8),
            Text('Approving will create a fuel transaction.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppConstants.mediumText)),
          ],
        ),
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
      await reqService.approve(
        requestId: req.id,
        status: req.status,
        approvedBy: auth.currentUserId ?? 'unknown',
        unitPriceRwf: price,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request approved — fuel transaction created'),
              backgroundColor: AppConstants.fuelGood),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject(FuelRequest req) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject Request',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reason for rejection:',
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                  hintText: 'Enter reason...'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.severityCritical),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await context.read<FuelRequestService>().reject(
            requestId: req.id,
            status: req.status,
            reason: reasonCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
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
    final requests = context.watch<FuelRequestService>().requests;
    final priceService = context.watch<FuelPriceService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Fuel Approvals',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const ShimmerLoader(count: 4)
          : RefreshIndicator(
              color: AppConstants.primaryOrange,
              onRefresh: _load,
              child: requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 56, color: AppConstants.mediumText),
                          const SizedBox(height: 12),
                          Text('No pending requests',
                              style: GoogleFonts.poppins(
                                  color: AppConstants.mediumText)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requests.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (_, i) => _RequestCard(
                        request: requests[i],
                        currentPrice: priceService.petrolPrice,
                        onApprove: () => _approve(requests[i]),
                        onReject: () => _reject(requests[i]),
                      ),
                    ),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FuelRequest request;
  final double currentPrice;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard(
      {required this.request,
      required this.currentPrice,
      required this.onApprove,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    final total = request.requestedQuantityL * currentPrice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request.vehiclePlate ?? 'Unknown Vehicle',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppConstants.primaryOrange)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConstants.severityMedium.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Pending',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.severityMedium)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow('Driver', request.driverName ?? 'Unknown'),
            _InfoRow('Quantity', '${request.requestedQuantityL}L'),
            _InfoRow('Est. Cost', AppConstants.formatRWF(total)),
            if (request.purpose != null && request.purpose!.isNotEmpty)
              _InfoRow('Purpose', request.purpose!),
            _InfoRow('Requested', AppConstants.formatDate(request.createdAt)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close,
                      size: 16, color: AppConstants.severityCritical),
                  label: const Text('Reject',
                      style: TextStyle(color: AppConstants.severityCritical)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppConstants.severityCritical),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppConstants.mediumText)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.darkText)),
          ),
        ],
      ),
    );
  }
}
