import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin/admin_shell.dart';
import 'finance/finance_shell.dart';
import 'driver/driver_shell.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveProfile();
  }

  Future<void> _resolveProfile() async {
    try {
      await context.read<AuthService>().getCurrentProfile();
    } catch (_) {
      // Network unavailable or session invalid — fall through to login screen.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = context.watch<AuthService>().currentProfile;
    if (profile == null) return const LoginScreen();

    if (profile.isAdmin) return const AdminShell();
    if (profile.isFinance) return const FinanceShell();
    return const DriverShell();
  }
}
