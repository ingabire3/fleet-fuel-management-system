import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_dashboard.dart';
import '../vehicles_screen.dart';
import '../fuel_log_screen.dart';
import '../trips_screen.dart';
import '../alerts_screen.dart';
import '../finance/fuel_approval_screen.dart';
import '../../widgets/lazy_indexed_stack.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _screens = [
    AdminDashboard(),
    FuelApprovalScreen(),
    VehiclesScreen(),
    FuelLogScreen(),
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
      icon: Icon(Icons.directions_car_outlined),
      activeIcon: Icon(Icons.directions_car),
      label: 'Vehicles',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_gas_station_outlined),
      activeIcon: Icon(Icons.local_gas_station),
      label: 'Fuel Log',
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
