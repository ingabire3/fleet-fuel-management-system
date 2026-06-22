import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/fuel_service.dart';
import 'services/trip_service.dart';
import 'services/alert_service.dart';
import 'services/fuel_request_service.dart';
import 'services/fuel_price_service.dart';
import 'services/analytics_service.dart';
import 'services/api_analytics_service.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await SupabaseService.initialize();
  await ApiClient.instance.init();
  runApp(NPDFuelApp(isLoggedIn: ApiClient.instance.isLoggedIn));
}

class NPDFuelApp extends StatelessWidget {
  final bool isLoggedIn;
  const NPDFuelApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FuelService()),
        ChangeNotifierProvider(create: (_) => TripService()),
        ChangeNotifierProvider(create: (_) => AlertService()),
        ChangeNotifierProvider(create: (_) => FuelRequestService()),
        ChangeNotifierProvider(create: (_) => FuelPriceService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()),
        ChangeNotifierProvider(create: (_) => ApiAnalyticsService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'NPD Fuel Management',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: isLoggedIn ? '/dashboard' : (kIsWeb ? '/landing' : '/login'),
        routes: {
          '/landing': (context) => const LandingScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const RoleRouter(),
        },
      ),
    );
  }
}
