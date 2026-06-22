import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
import '../../services/api_analytics_service.dart';
import '../../services/fuel_price_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../utils/driver_analytics.dart';

class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({super.key});

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final priceSvc = context.read<FuelPriceService>();
    final analyticsSvc = context.read<AnalyticsService>();
    final apiAnalytics = context.read<ApiAnalyticsService>();
    final notifSvc = context.read<NotificationService>();
    try {
      await priceSvc.fetchCurrentPrices();
      await Future.wait([
        analyticsSvc.fetchFleetInsights(
          priceForFuelType: priceSvc.getPrice,
          notificationService: notifSvc,
        ),
        apiAnalytics.fetchFleetSummary(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsService>();
    final insights = analytics.fleetInsights;
    final monthly = analytics.monthlyTotals;
    final locations = analytics.locationFrequency;
    final fleet = context.watch<ApiAnalyticsService>().fleetSummary;

    final hasData = fleet != null || insights.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Management Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
              ? _empty()
              : RefreshIndicator(
                  color: AppConstants.primaryOrange,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // ── Backend fleet allocation summary ────────────────────
                      if (fleet != null) ...[
                        _SectionLabel('Fleet Fuel Allocation — ${_monthLabel(fleet.month, fleet.year)}'),
                        _FleetAllocationCard(fleet: fleet),

                        _SectionLabel('Allocation by Driver'),
                        _AllocationDriverList(drivers: fleet.driverBreakdown),

                        if (fleet.monthlyTrends.isNotEmpty) ...[
                          _SectionLabel('Monthly Fuel Expenditure (6 months)'),
                          _BackendMonthlyTrendChart(trends: fleet.monthlyTrends),
                        ],

                        if (fleet.fuelUsageByDepartment.isNotEmpty) ...[
                          _SectionLabel('Fuel Usage by Department'),
                          _DeptBreakdownChart(depts: fleet.fuelUsageByDepartment),
                        ],
                      ],

                      // ── Supabase-based analytics (shown when data present) ──
                      if (insights.isNotEmpty) ...[
                        _SectionLabel('Fleet Overview'),
                        _OverviewGrid(insights: insights),

                        _SectionLabel('Fuel Consumption by Driver'),
                        _DriverFuelChart(insights: insights),

                        _SectionLabel('Fuel Consumption by Vehicle'),
                        _VehicleFuelChart(insights: insights),

                        _SectionLabel('Monthly Spending Trends'),
                        _MonthlyTrendChart(monthly: monthly),

                        _SectionLabel('Budget Utilization'),
                        _BudgetUtilizationChart(insights: insights),

                        _SectionLabel('AI Risk Analysis'),
                        _RiskAnalysisChart(insights: insights),

                        _SectionLabel('Route Frequency Analysis'),
                        _RouteFrequencyChart(locations: locations),

                        _SectionLabel('Most Efficient Drivers'),
                        _RankingList(
                          insights: _topBy(
                              insights, (a, b) => b.efficiencyScore.compareTo(a.efficiencyScore)),
                          valueLabel: (i) => '${i.efficiencyScore.toStringAsFixed(0)}%',
                          valueColor: (i) => AppConstants.fuelGood,
                        ),

                        _SectionLabel('Highest Consumers'),
                        _RankingList(
                          insights: _topBy(insights,
                              (a, b) => b.spentMonthToDate.compareTo(a.spentMonthToDate)),
                          valueLabel: (i) => AppConstants.formatRWF(i.spentMonthToDate),
                          valueColor: (i) => AppConstants.severityHigh,
                        ),

                        _SectionLabel('Suspicious / High-Risk Drivers'),
                        _suspiciousList(insights),

                        _SectionLabel('All Drivers (${insights.length})'),
                        ...insights.map((i) => _DriverRow(insights: i)),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<DriverInsights> _topBy(
      List<DriverInsights> insights, int Function(DriverInsights, DriverInsights) cmp,
      {int top = 5}) {
    final sorted = [...insights]..sort(cmp);
    return sorted.take(top).toList();
  }

  Widget _suspiciousList(List<DriverInsights> insights) {
    final flagged = insights
        .where((i) =>
            i.category == DriverCategory.suspicious ||
            i.category == DriverCategory.highConsumption)
        .toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
    if (flagged.isEmpty) {
      return const _EmptyRow(message: 'No suspicious activity detected');
    }
    return Column(
      children: flagged
          .take(8)
          .map((i) => _RankingRow(
                insights: i,
                valueLabel: '${i.riskScore.toStringAsFixed(0)} risk',
                valueColor: i.category.color,
              ))
          .toList(),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 56, color: AppConstants.mediumText),
            const SizedBox(height: 12),
            Text('No analytics data available',
                style: GoogleFonts.poppins(color: AppConstants.mediumText)),
          ],
        ),
      );

  static String _monthLabel(int m, int y) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${names[m]} $y';
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.darkText)),
      );
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(message,
            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.mediumText)),
      );
}

String _firstName(String fullName) {
  final parts = fullName.trim().split(' ');
  return parts.isNotEmpty ? parts.first : fullName;
}

// ── Overview grid ────────────────────────────────────────────────────────────

class _OverviewGrid extends StatelessWidget {
  final List<DriverInsights> insights;
  const _OverviewGrid({required this.insights});

  @override
  Widget build(BuildContext context) {
    final totalSpend = insights.fold(0.0, (s, i) => s + i.spentMonthToDate);
    final totalBudget = insights.fold(0.0, (s, i) => s + i.budgetRwf);
    final avgPercent = insights.isNotEmpty
        ? insights.fold(0.0, (s, i) => s + i.percentUsed) / insights.length
        : 0.0;
    final suspiciousCount =
        insights.where((i) => i.category == DriverCategory.suspicious).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _OverviewCard(
            label: 'Fleet Spend (Month)',
            value: AppConstants.formatRWF(totalSpend),
            icon: Icons.attach_money,
          ),
          _OverviewCard(
            label: 'Total Budget',
            value: AppConstants.formatRWF(totalBudget),
            icon: Icons.account_balance_wallet_outlined,
          ),
          _OverviewCard(
            label: 'Avg Budget Used',
            value: '${avgPercent.toStringAsFixed(0)}%',
            icon: Icons.speed,
            valueColor: avgPercent > 100
                ? AppConstants.severityCritical
                : avgPercent > 75
                    ? AppConstants.severityMedium
                    : AppConstants.fuelGood,
          ),
          _OverviewCard(
            label: 'Suspicious Drivers',
            value: '$suspiciousCount',
            icon: Icons.report_gmailerrorred_outlined,
            valueColor: suspiciousCount > 0
                ? AppConstants.severityCritical
                : AppConstants.fuelGood,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _OverviewCard(
      {required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppConstants.primaryOrange, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppConstants.darkText)),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.mediumText)),
        ],
      ),
    );
  }
}

// ── Charts ────────────────────────────────────────────────────────────────────

class _DriverFuelChart extends StatelessWidget {
  final List<DriverInsights> insights;
  const _DriverFuelChart({required this.insights});

  @override
  Widget build(BuildContext context) {
    final sorted = [...insights]
      ..sort((a, b) => b.totalFuelMonth.compareTo(a.totalFuelMonth));
    final top = sorted.take(10).toList();
    final maxY = top.isEmpty
        ? 10.0
        : (top.first.totalFuelMonth * 1.2).clamp(10.0, double.infinity);

    return _ChartCard(
      child: top.isEmpty
          ? const Center(child: Text('No data'))
          : BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) =>
                          Text('${v.toInt()}L', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_firstName(top[idx].driverName),
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < top.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: top[i].totalFuelMonth,
                        color: AppConstants.primaryOrange,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
    );
  }
}

class _VehicleFuelChart extends StatelessWidget {
  final List<DriverInsights> insights;
  const _VehicleFuelChart({required this.insights});

  @override
  Widget build(BuildContext context) {
    final withVehicle = insights.where((i) => i.vehicle != null).toList()
      ..sort((a, b) => b.totalFuelMonth.compareTo(a.totalFuelMonth));
    final top = withVehicle.take(10).toList();
    final maxY = top.isEmpty
        ? 10.0
        : (top.first.totalFuelMonth * 1.2).clamp(10.0, double.infinity);

    return _ChartCard(
      child: top.isEmpty
          ? const Center(child: Text('No data'))
          : BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) =>
                          Text('${v.toInt()}L', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(top[idx].vehicle!.plateNumber,
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < top.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: top[i].totalFuelMonth,
                        color: AppConstants.severityLow,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyTotal> monthly;
  const _MonthlyTrendChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < monthly.length; i++) FlSpot(i.toDouble(), monthly[i].costRwf)
    ];
    final maxY = monthly.isEmpty
        ? 10.0
        : (monthly.map((m) => m.costRwf).reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(10.0, double.infinity);

    return _ChartCard(
      child: monthly.isEmpty
          ? const Center(child: Text('No data'))
          : LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, m) => Text('${(v / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= monthly.length) return const SizedBox.shrink();
                        return Text(monthly[idx].label, style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppConstants.primaryOrange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true,
                        color: AppConstants.primaryOrange.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BudgetUtilizationChart extends StatelessWidget {
  final List<DriverInsights> insights;
  const _BudgetUtilizationChart({required this.insights});

  @override
  Widget build(BuildContext context) {
    final sorted = [...insights]
      ..sort((a, b) => b.percentUsed.compareTo(a.percentUsed));
    final top = sorted.take(10).toList();

    return _ChartCard(
      child: top.isEmpty
          ? const Center(child: Text('No data'))
          : BarChart(
              BarChartData(
                maxY: 150,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: 100,
                    color: AppConstants.severityCritical.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [6, 4],
                  ),
                ]),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) =>
                          Text('${v.toInt()}%', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_firstName(top[idx].driverName),
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < top.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: top[i].percentUsed.clamp(0, 150),
                        color: top[i].percentUsed >= 100
                            ? AppConstants.severityCritical
                            : top[i].percentUsed >= 75
                                ? AppConstants.severityMedium
                                : AppConstants.fuelGood,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
    );
  }
}

class _RiskAnalysisChart extends StatelessWidget {
  final List<DriverInsights> insights;
  const _RiskAnalysisChart({required this.insights});

  @override
  Widget build(BuildContext context) {
    final counts = <DriverCategory, int>{for (final c in DriverCategory.values) c: 0};
    for (final i in insights) {
      counts[i.category] = (counts[i.category] ?? 0) + 1;
    }
    final total = insights.length;

    return _ChartCard(
      child: total == 0
          ? const Center(child: Text('No data'))
          : Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (final c in DriverCategory.values)
                          if ((counts[c] ?? 0) > 0)
                            PieChartSectionData(
                              value: (counts[c] ?? 0).toDouble(),
                              color: c.color,
                              title: '${counts[c]}',
                              radius: 56,
                              titleStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in DriverCategory.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration:
                                    BoxDecoration(color: c.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('${c.label} (${counts[c]})',
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RouteFrequencyChart extends StatelessWidget {
  final List<LocationFrequency> locations;
  const _RouteFrequencyChart({required this.locations});

  @override
  Widget build(BuildContext context) {
    final maxY = locations.isEmpty
        ? 10.0
        : (locations.first.count * 1.2).clamp(10.0, double.infinity);

    return _ChartCard(
      child: locations.isEmpty
          ? const Center(child: Text('No data'))
          : BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) =>
                          Text('${v.toInt()}', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= locations.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(locations[idx].name,
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < locations.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: locations[i].count.toDouble(),
                        color: AppConstants.fuelGood,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
    );
  }
}

// ── Rankings & driver list ───────────────────────────────────────────────────

class _RankingList extends StatelessWidget {
  final List<DriverInsights> insights;
  final String Function(DriverInsights) valueLabel;
  final Color Function(DriverInsights) valueColor;

  const _RankingList({
    required this.insights,
    required this.valueLabel,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const _EmptyRow(message: 'No data');
    return Column(
      children: insights
          .map((i) => _RankingRow(
                insights: i,
                valueLabel: valueLabel(i),
                valueColor: valueColor(i),
              ))
          .toList(),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final DriverInsights insights;
  final String valueLabel;
  final Color valueColor;

  const _RankingRow({
    required this.insights,
    required this.valueLabel,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insights.driverName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppConstants.darkText)),
                Text(insights.vehicle?.plateNumber ?? 'No vehicle',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: insights.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(insights.category.label,
                style: GoogleFonts.poppins(
                    fontSize: 9, fontWeight: FontWeight.bold, color: insights.category.color)),
          ),
          const SizedBox(width: 8),
          Text(valueLabel,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final DriverInsights insights;
  const _DriverRow({required this.insights});

  @override
  Widget build(BuildContext context) {
    final pct = insights.percentUsed;
    final barColor = pct >= 100
        ? AppConstants.severityCritical
        : pct >= 75
            ? AppConstants.severityMedium
            : AppConstants.fuelGood;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(insights.driverName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppConstants.darkText)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: insights.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(insights.category.label,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: insights.category.color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            insights.vehicle != null
                ? '${insights.vehicle!.make} ${insights.vehicle!.model} • ${insights.vehicle!.plateNumber}'
                : 'No vehicle assigned',
            style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppConstants.formatRWF(insights.spentMonthToDate)} / ${AppConstants.formatRWF(insights.budgetRwf)}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText),
              ),
              Text('${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.bold, color: barColor)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Backend fleet summary widgets ────────────────────────────────────────────

class _FleetAllocationCard extends StatelessWidget {
  final FleetSummaryData fleet;
  const _FleetAllocationCard({required this.fleet});

  @override
  Widget build(BuildContext context) {
    final pctConsumed = fleet.fleetPercentConsumed;
    final barColor = pctConsumed >= 100
        ? AppConstants.severityCritical
        : pctConsumed >= 75
            ? AppConstants.severityMedium
            : AppConstants.fuelGood;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.primaryOrange, AppConstants.primaryOrange.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppConstants.primaryOrange.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${fleet.driverCount} active drivers',
              style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _WhiteStat(label: 'Total Allocated', value: '${fleet.totalAvailableL.toStringAsFixed(0)} L')),
            Expanded(child: _WhiteStat(label: 'Consumed So Far', value: '${fleet.totalConsumedL.toStringAsFixed(0)} L')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _WhiteStat(label: 'Remaining', value: '${(fleet.totalAvailableL - fleet.totalConsumedL).clamp(0, double.infinity).toStringAsFixed(0)} L')),
            Expanded(child: _WhiteStat(label: 'Projected Cost', value: AppConstants.formatRWF(fleet.totalProjectedCostRwf))),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pctConsumed / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text('${pctConsumed.toStringAsFixed(0)}% of fleet allocation consumed',
              style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
        ],
      ),
    );
  }
}

class _WhiteStat extends StatelessWidget {
  final String label;
  final String value;
  const _WhiteStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      );
}

class _AllocationDriverList extends StatelessWidget {
  final List<FleetDriverBreakdown> drivers;
  const _AllocationDriverList({required this.drivers});

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) return const _EmptyRow(message: 'No allocation data');
    final sorted = [...drivers]..sort((a, b) => b.percentConsumed.compareTo(a.percentConsumed));
    return Column(
      children: sorted.map((d) => _AllocationDriverRow(driver: d)).toList(),
    );
  }
}

class _AllocationDriverRow extends StatelessWidget {
  final FleetDriverBreakdown driver;
  const _AllocationDriverRow({required this.driver});

  @override
  Widget build(BuildContext context) {
    final pct = driver.percentConsumed;
    final barColor = pct >= 100
        ? AppConstants.severityCritical
        : pct >= 75
            ? AppConstants.severityMedium
            : AppConstants.fuelGood;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(driver.driverName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppConstants.darkText)),
            ),
            Text('${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
          ]),
          if (driver.vehiclePlate != null)
            Text(driver.vehiclePlate!,
                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.mediumText)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: driver.consumedFraction,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${driver.consumedL.toStringAsFixed(1)} / ${driver.totalAvailableL.toStringAsFixed(1)} L',
                style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.mediumText)),
            Text(AppConstants.formatRWF(driver.projectedCostRwf),
                style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.mediumText)),
          ]),
        ],
      ),
    );
  }
}

class _BackendMonthlyTrendChart extends StatelessWidget {
  final List<FleetMonthlyTrend> trends;
  const _BackendMonthlyTrendChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < trends.length; i++) FlSpot(i.toDouble(), trends[i].totalCostRwf),
    ];
    final maxY = trends.isEmpty
        ? 10.0
        : (trends.map((m) => m.totalCostRwf).reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(10.0, double.infinity);

    return _ChartCard(
      child: trends.isEmpty
          ? const Center(child: Text('No data'))
          : LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, m) =>
                          Text('${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= trends.length) return const SizedBox.shrink();
                        return Text(trends[idx].label, style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppConstants.primaryOrange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true, color: AppConstants.primaryOrange.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DeptBreakdownChart extends StatelessWidget {
  final List<FleetDeptBreakdown> depts;
  const _DeptBreakdownChart({required this.depts});

  @override
  Widget build(BuildContext context) {
    final total = depts.fold(0.0, (s, d) => s + d.totalCostRwf);
    if (total == 0) return const _EmptyRow(message: 'No department data');

    return _ChartCard(
      child: Row(children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: [
                for (var i = 0; i < depts.length; i++)
                  PieChartSectionData(
                    value: depts[i].totalCostRwf,
                    color: _deptColor(i),
                    title: '${(depts[i].totalCostRwf / total * 100).toStringAsFixed(0)}%',
                    radius: 56,
                    titleStyle: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < depts.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: _deptColor(i), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${depts[i].departmentName}\n${depts[i].totalQuantityL.toStringAsFixed(0)} L',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  static Color _deptColor(int i) {
    const colors = [
      AppConstants.primaryOrange,
      AppConstants.fuelGood,
      AppConstants.severityMedium,
      AppConstants.severityLow,
      AppConstants.severityCritical,
    ];
    return colors[i % colors.length];
  }
}
