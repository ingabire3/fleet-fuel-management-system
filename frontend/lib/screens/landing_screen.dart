import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

const _githubUrl = 'https://github.com/ingabire3/fleet-fuel-management-system';

Future<void> _openGithub() => launchUrl(Uri.parse(_githubUrl), webOnlyWindowName: '_blank');

/// Web-only marketing/landing page shown before login. Gives recruiters
/// context (features, stack, architecture, demo creds) without needing
/// the README open in a second tab.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.white,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(onLaunch: () => Navigator.of(context).pushNamed('/login')),
                  const SizedBox(height: 56),
                  const _Section(title: 'Features', child: _FeaturesGrid()),
                  const SizedBox(height: 48),
                  const _Section(title: 'Technology Stack', child: _TechStack()),
                  const SizedBox(height: 48),
                  const _Section(title: 'Architecture', child: _ArchitectureDiagram()),
                  const SizedBox(height: 48),
                  _Section(
                    title: 'Demo Credentials',
                    child: _DemoCredentials(onLaunch: () => Navigator.of(context).pushNamed('/login')),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} Fleet Fuel Management System',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onLaunch;
  const _Hero({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.primaryOrange, AppConstants.primaryDarkOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet Fuel Management System',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppConstants.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Smart fleet management system with GPS tracking, fuel calculations, '
            'analytics, notifications, and role-based access.',
            style: GoogleFonts.poppins(fontSize: 16, color: AppConstants.white.withValues(alpha: 0.92)),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: onLaunch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.white,
                  foregroundColor: AppConstants.primaryDarkOrange,
                  minimumSize: const Size(180, 48),
                ),
                child: const Text('Launch Live Demo'),
              ),
              OutlinedButton(
                onPressed: _openGithub,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: AppConstants.white,
                  minimumSize: const Size(180, 48),
                ),
                child: const Text('View on GitHub'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Note: demo server may take 30-60 seconds on first load due to free-tier hosting.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppConstants.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppConstants.darkText,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  const _FeaturesGrid();

  static const _features = [
    ('GPS Route Tracking', Icons.map_outlined),
    ('Dynamic Fuel Calculation', Icons.local_gas_station_outlined),
    ('PDF Reports', Icons.picture_as_pdf_outlined),
    ('Push Notifications', Icons.notifications_outlined),
    ('OTP Authentication', Icons.verified_user_outlined),
    ('Analytics Dashboard', Icons.bar_chart_outlined),
    ('Role-based Access', Icons.admin_panel_settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _features
          .map((f) => _Chip(label: f.$1, icon: f.$2))
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.lightOrangeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.orangeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryDarkOrange),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TechStack extends StatelessWidget {
  const _TechStack();

  static const _groups = [
    ('Frontend', ['Flutter', 'Dart', 'Provider']),
    ('Backend', ['Node.js', 'TypeScript', 'Express', 'Prisma']),
    ('Database', ['PostgreSQL']),
    ('Services', ['Firebase', 'Supabase']),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: _groups.map((g) {
        return SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.$1, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...g.$2.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $t', style: GoogleFonts.poppins(fontSize: 13, color: AppConstants.mediumText)),
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ArchitectureDiagram extends StatelessWidget {
  const _ArchitectureDiagram();

  static const _steps = [
    'Flutter App',
    'Node/Express API',
    'Prisma ORM',
    'PostgreSQL',
    'Firebase Notifications',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.lightGreyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Chip(label: Text(_steps[i], style: GoogleFonts.poppins(fontSize: 12))),
            if (i != _steps.length - 1) const Icon(Icons.arrow_downward, size: 16),
          ],
        ],
      ),
    );
  }
}

class _DemoCredentials extends StatelessWidget {
  final VoidCallback onLaunch;
  const _DemoCredentials({required this.onLaunch});

  static const _rows = [
    ('Admin', 'admin@example.com'),
    ('Fleet Manager', 'manager@example.com'),
    ('Driver', 'driver@example.com'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.lightOrangeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${r.$1}: ${r.$2}', style: GoogleFonts.poppins(fontSize: 14)),
            ),
          const SizedBox(height: 4),
          Text(
            'Password autofills on the login screen — just tap a role.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.mediumText),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onLaunch, child: const Text('Try it now')),
        ],
      ),
    );
  }
}
