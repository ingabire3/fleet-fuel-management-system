import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppConstants {
  // Overridable via --dart-define=SUPABASE_URL=... / --dart-define=SUPABASE_ANON_KEY=...
  // Defaults below are the project's anon (public) key — safe to ship client-side.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://awsptthnbjixoyujwvyk.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3c3B0dGhuYmppeG95dWp3dnlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3MDEzOTAsImV4cCI6MjA5NjI3NzM5MH0.tEx18YH1Zb8ETNrAPFsabgxPMzvrgi7_b1jq_Ig3Xfc',
  );

  static const Color primaryOrange = Color(0xFFE8690A);
  static const Color primaryDarkOrange = Color(0xFFC45500);
  static const Color lightOrangeBg = Color(0xFFFFF3E0);
  static const Color orangeBorder = Color(0xFFFFB74D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGreyBg = Color(0xFFF5F5F5);
  static const Color darkText = Color(0xFF1A1A1A);
  static const Color mediumText = Color(0xFF5D4037);
  static const Color bottomBarBg = Color(0xFF1A1A1A);
  static const Color bottomBarSelected = Color(0xFFE8690A);
  static const Color bottomBarUnselected = Color(0xFF9E9E9E);

  static const Color severityCritical = Color(0xFFD32F2F);
  static const Color severityHigh = Color(0xFFF57C00);
  static const Color severityMedium = Color(0xFFFBC02D);
  static const Color severityLow = Color(0xFF1976D2);
  static const Color severityResolved = Color(0xFF388E3C);

  static const Color fuelGood = Color(0xFF388E3C);
  static const Color fuelWarning = Color(0xFFF57C00);
  static const Color fuelCritical = Color(0xFFD32F2F);

  static String formatRWF(double amount) =>
      'RWF ${NumberFormat('#,###').format(amount)}';

  static String formatDate(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt);

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
