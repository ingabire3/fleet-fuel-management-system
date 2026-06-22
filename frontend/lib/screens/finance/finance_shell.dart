import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'finance_dashboard.dart';
import 'fuel_approval_screen.dart';
import '../trips_screen.dart';
import '../alerts_screen.dart';
import '../../widgets/lazy_indexed_stack.dart';

class FinanceShell extends StatefulWidget {
  const FinanceShell({super.key});

  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  int _index = 0;

  static const _screens = [
    FinanceDashboard(),
    FuelApprovalScreen(),
    TripsScreen(),
    AlertsScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.approval_outlined),
      activeIcon: Icon(Icons.approval),
      label: 'Approvals',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: 'Trips',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications_outlined),
      activeIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LazyIndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
        selectedLabelStyle:
            GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
      ),
    );
  }
}
