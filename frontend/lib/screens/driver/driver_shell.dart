import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'driver_dashboard.dart';
import 'fuel_request_screen.dart';
import '../trips_screen.dart';
import '../../widgets/lazy_indexed_stack.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  static const _screens = [
    DriverDashboard(),
    FuelRequestScreen(),
    TripsScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_gas_station_outlined),
      activeIcon: Icon(Icons.local_gas_station),
      label: 'Request Fuel',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: 'My Trips',
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
