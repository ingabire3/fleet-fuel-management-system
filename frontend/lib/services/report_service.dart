import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/vehicle.dart';
import '../models/fuel_transaction.dart';
import '../models/fuel_request.dart';
import '../models/alert.dart';

/// Generates branded PDF reports for the Admin and Finance (Fleet Manager)
/// dashboards, styled with NPD's orange theme and an official report stamp.
class ReportService {
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _dayFmt = DateFormat('dd/MM/yyyy');
  static final _moneyFmt = NumberFormat('#,###');

  // NPD brand colors (mirrors AppConstants in lib/utils/constants.dart)
  static final _orange = PdfColor.fromInt(0xFFE8690A);
  static final _darkOrange = PdfColor.fromInt(0xFFC45500);
  static final _lightOrangeBg = PdfColor.fromInt(0xFFFFF3E0);
  static final _orangeBorder = PdfColor.fromInt(0xFFFFB74D);

  static pw.MemoryImage? _logo;

  static Future<pw.MemoryImage> _getLogo() async {
    final cached = _logo;
    if (cached != null) return cached;
    final bytes = await rootBundle.load('assets/logo.png');
    final img = pw.MemoryImage(bytes.buffer.asUint8List());
    _logo = img;
    return img;
  }

  static String _rwf(double? amount) =>
      'RWF ${_moneyFmt.format(amount ?? 0)}';

  /// Fleet-wide report for Admins: vehicles, consumption, requests, alerts.
  static Future<Uint8List> generateFleetReport({
    required String generatedBy,
    required List<Vehicle> vehicles,
    required List<FuelTransaction> transactions,
    required List<FuelRequest> requests,
    required List<Alert> alerts,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final logo = await _getLogo();

    final monthlyRefills = transactions.where((t) =>
        t.transactionType == 'refill' &&
        t.recordedAt.isAfter(DateTime(now.year, now.month, 1)));
    final monthlyLiters =
        monthlyRefills.fold(0.0, (sum, t) => sum + t.quantityL);
    final monthlyCost =
        monthlyRefills.fold(0.0, (sum, t) => sum + (t.totalCostRwf ?? 0));

    final pendingReq = requests.where((r) => r.status == 'pending').length;
    final approvedReq = requests.where((r) => r.status == 'approved').length;
    final rejectedReq = requests.where((r) => r.status == 'rejected').length;

    final openAlerts = alerts.where((a) => a.status == 'open').length;
    final ackAlerts = alerts.where((a) => a.status == 'acknowledged').length;
    final resolvedAlerts = alerts.where((a) => a.status == 'resolved').length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        header: (ctx) =>
            _header(logo, 'Fleet Management Report', now, generatedBy),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _sectionTitle('Fleet Overview'),
          _summaryRow([
            _summaryStat('Total Vehicles', '${vehicles.length}'),
            _summaryStat('Active', '${vehicles.where((v) => v.status == 'active').length}'),
            _summaryStat('Maintenance', '${vehicles.where((v) => v.status == 'maintenance').length}'),
          ]),
          pw.SizedBox(height: 10),
          _vehicleTable(vehicles),
          pw.SizedBox(height: 16),
          _sectionTitle('Fuel Consumption (This Month)'),
          _summaryRow([
            _summaryStat('Total Refills', '${monthlyRefills.length}'),
            _summaryStat('Total Litres', '${monthlyLiters.toStringAsFixed(1)} L'),
            _summaryStat('Total Cost', _rwf(monthlyCost)),
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Fuel Requests Summary'),
          _summaryRow([
            _summaryStat('Pending', '$pendingReq'),
            _summaryStat('Approved', '$approvedReq'),
            _summaryStat('Rejected', '$rejectedReq'),
          ]),
          pw.SizedBox(height: 10),
          _requestTable(requests.take(15).toList()),
          pw.SizedBox(height: 16),
          _sectionTitle('AI Alerts Summary'),
          _summaryRow([
            _summaryStat('Open', '$openAlerts'),
            _summaryStat('Acknowledged', '$ackAlerts'),
            _summaryStat('Resolved', '$resolvedAlerts'),
          ]),
          pw.SizedBox(height: 10),
          _alertTable(alerts.take(15).toList()),
          pw.SizedBox(height: 28),
          _stamp(now),
        ],
      ),
    );

    return doc.save();
  }

  /// Finance (Fleet Manager) report: prices, budgets, transactions, requests.
  static Future<Uint8List> generateFinanceReport({
    required String generatedBy,
    required List<Vehicle> vehicles,
    required List<FuelTransaction> transactions,
    required List<FuelRequest> requests,
    required double petrolPrice,
    required double dieselPrice,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final logo = await _getLogo();

    final monthlyRefills = transactions.where((t) =>
        t.transactionType == 'refill' && t.recordedAt.isAfter(firstOfMonth));
    final monthlyCost =
        monthlyRefills.fold(0.0, (sum, t) => sum + (t.totalCostRwf ?? 0));

    final pendingReq = requests.where((r) => r.status == 'pending').toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        header: (ctx) => _header(logo, 'Finance Report', now, generatedBy),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _sectionTitle('Current Fuel Prices'),
          _summaryRow([
            _summaryStat('Petrol', '${_rwf(petrolPrice)}/L'),
            _summaryStat('Diesel', '${_rwf(dieselPrice)}/L'),
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Monthly Spend Summary'),
          _summaryRow([
            _summaryStat('Refills This Month', '${monthlyRefills.length}'),
            _summaryStat('Total Spend', _rwf(monthlyCost)),
            _summaryStat('Pending Requests', '${pendingReq.length}'),
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Monthly Spend by Vehicle'),
          _vehicleSpendTable(vehicles, transactions, firstOfMonth),
          pw.SizedBox(height: 16),
          _sectionTitle('Pending Fuel Requests'),
          _requestTable(pendingReq),
          pw.SizedBox(height: 16),
          _sectionTitle('Recent Fuel Transactions'),
          _transactionTable(transactions.take(20).toList()),
          pw.SizedBox(height: 28),
          _stamp(now),
        ],
      ),
    );

    return doc.save();
  }

  // ── Shared layout pieces ────────────────────────────────────────────────

  static pw.Widget _header(
      pw.MemoryImage logo, String title, DateTime generatedAt, String generatedBy) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: _orangeBorder, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('NPD Ltd Rwanda',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _darkOrange)),
                    pw.Text('Fleet & Fuel Management System',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900)),
                  pw.SizedBox(height: 2),
                  pw.Text('Generated: ${_dateFmt.format(generatedAt)}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('By: $generatedBy',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ),
        pw.Container(height: 2, color: _orange),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Column(children: [
      pw.Container(height: 0.75, color: _orangeBorder),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('NPD Ltd Rwanda — Confidential',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ]);
  }

  /// Official-looking report stamp (rotated bordered seal) placed at the
  /// end of the document, similar to a company stamp on a printed report.
  static pw.Widget _stamp(DateTime now) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Transform.rotate(
        angle: -0.12,
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _orange, width: 2),
            borderRadius: pw.BorderRadius.circular(8),
            color: _lightOrangeBg,
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('NPD LTD RWANDA',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkOrange,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 2),
              pw.Text('OFFICIAL REPORT',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _orange,
                      letterSpacing: 2)),
              pw.SizedBox(height: 2),
              pw.Text(_dayFmt.format(now),
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.only(left: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _darkOrange)),
      );

  static pw.Widget _summaryRow(List<pw.Widget> stats) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: stats,
      );

  static pw.Widget _summaryStat(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _lightOrangeBg,
          border: pw.Border.all(color: _orangeBorder, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: _darkOrange)),
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      );

  static pw.TableRow _tableHeaderRow(List<String> labels) => pw.TableRow(
        decoration: pw.BoxDecoration(color: _orange),
        children: labels
            .map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(l,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ))
            .toList(),
      );

  static pw.TableRow _tableRow(List<String> cells, {bool shaded = false}) => pw.TableRow(
        decoration: pw.BoxDecoration(color: shaded ? _lightOrangeBg : PdfColors.white),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(c, style: const pw.TextStyle(fontSize: 8)),
                ))
            .toList(),
      );

  static pw.Widget _emptyNote(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );

  // ── Tables ───────────────────────────────────────────────────────────────

  static pw.Widget _vehicleTable(List<Vehicle> vehicles) {
    if (vehicles.isEmpty) return _emptyNote('No vehicles registered.');
    return pw.Table(
      border: pw.TableBorder.all(color: _orangeBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.3),
        5: pw.FlexColumnWidth(1.6),
      },
      children: [
        _tableHeaderRow(
            ['Plate', 'Make/Model', 'Type', 'Fuel %', 'Status', 'Driver']),
        for (var i = 0; i < vehicles.length; i++)
          _tableRow([
            vehicles[i].plateNumber,
            '${vehicles[i].make} ${vehicles[i].model}',
            vehicles[i].vehicleType,
            '${(vehicles[i].fuelPercent * 100).toStringAsFixed(0)}%',
            vehicles[i].status,
            vehicles[i].assignedDriverName ?? '—',
          ], shaded: i.isOdd),
      ],
    );
  }

  static pw.Widget _vehicleSpendTable(
      List<Vehicle> vehicles, List<FuelTransaction> transactions, DateTime since) {
    if (vehicles.isEmpty) return _emptyNote('No vehicles registered.');
    return pw.Table(
      border: pw.TableBorder.all(color: _orangeBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeaderRow(['Plate', 'Make/Model', 'Refills', 'Spent']),
        for (var i = 0; i < vehicles.length; i++)
          _tableRow(() {
            final v = vehicles[i];
            final vTx = transactions.where((t) =>
                t.vehicleId == v.id &&
                t.transactionType == 'refill' &&
                t.recordedAt.isAfter(since));
            final spent = vTx.fold(0.0, (sum, t) => sum + (t.totalCostRwf ?? 0));
            return [
              v.plateNumber,
              '${v.make} ${v.model}',
              '${vTx.length}',
              _rwf(spent),
            ];
          }(), shaded: i.isOdd),
      ],
    );
  }

  static pw.Widget _requestTable(List<FuelRequest> requests) {
    if (requests.isEmpty) return _emptyNote('No fuel requests.');
    return pw.Table(
      border: pw.TableBorder.all(color: _orangeBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.6),
      },
      children: [
        _tableHeaderRow(['Date', 'Driver', 'Vehicle', 'Qty (L)', 'Status']),
        for (var i = 0; i < requests.length; i++)
          _tableRow([
            _dayFmt.format(requests[i].createdAt),
            requests[i].driverName ?? '—',
            requests[i].vehiclePlate ?? '—',
            requests[i].requestedQuantityL.toStringAsFixed(1),
            requests[i].statusLabel,
          ], shaded: i.isOdd),
      ],
    );
  }

  static pw.Widget _alertTable(List<Alert> alerts) {
    if (alerts.isEmpty) return _emptyNote('No AI alerts.');
    return pw.Table(
      border: pw.TableBorder.all(color: _orangeBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        _tableHeaderRow(['Date', 'Title', 'Severity', 'Status']),
        for (var i = 0; i < alerts.length; i++)
          _tableRow([
            _dayFmt.format(alerts[i].createdAt),
            alerts[i].title,
            alerts[i].severityLabel,
            alerts[i].statusLabel,
          ], shaded: i.isOdd),
      ],
    );
  }

  static pw.Widget _transactionTable(List<FuelTransaction> transactions) {
    if (transactions.isEmpty) return _emptyNote('No fuel transactions.');
    return pw.Table(
      border: pw.TableBorder.all(color: _orangeBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        _tableHeaderRow(['Date', 'Type', 'Qty (L)', 'Cost']),
        for (var i = 0; i < transactions.length; i++)
          _tableRow([
            _dayFmt.format(transactions[i].recordedAt),
            transactions[i].transactionType,
            transactions[i].quantityL.toStringAsFixed(1),
            _rwf(transactions[i].totalCostRwf),
          ], shaded: i.isOdd),
      ],
    );
  }
}
