import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hostel_connect/screens/auth_wrapper.dart';
import 'package:hostel_connect/screens/auth/onboarding_screen.dart';
import 'package:hostel_connect/services/hive_models.dart';
import 'package:hostel_connect/services/local_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();



  // ✅ Initialize Hive
  await Hive.initFlutter();

  // ✅ Register Hive adapters (only once)
  Hive.registerAdapter(HostelModelAdapter());
  Hive.registerAdapter(RoomModelAdapter());
  Hive.registerAdapter(FavoriteModelAdapter());
  Hive.registerAdapter(BookingModelAdapter());

  // ✅ Open Hive boxes
  await Hive.openBox<HostelModel>('hostels');
  await Hive.openBox<RoomModel>('rooms');
  await Hive.openBox<FavoriteModel>('favorites');
  await Hive.openBox<BookingModel>('bookings');

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://jnqgjjifhspweluvnuwz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpucWdqamlmaHNwd2VsdXZudXd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU1NDM5OTAsImV4cCI6MjA2MTExOTk5MH0.hhWYfO1KcIt7VI_NhkJhYYPBwvMuF06ScjZHnN6r0_w',
  );

  runApp(const HostelBookingApp());
}

class HostelBookingApp extends StatelessWidget {
  const HostelBookingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Hostels',
      theme: ThemeData(
        primaryColor: const Color(0xFF3498db),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3498db),
          secondary: const Color(0xFF2ecc71),
          tertiary: const Color(0xFFf39c12),
          background: const Color(0xFFf5f8fa),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFF2c3e50),
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFF2c3e50),
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Color(0xFF2c3e50)),
          bodyMedium: TextStyle(color: Color(0xFF2c3e50)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498db),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3498db), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool _isLoading = true;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunchedBefore = prefs.getBool('has_launched_before') ?? false;

    setState(() {
      _isFirstLaunch = !hasLaunchedBefore;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isFirstLaunch ? const OnboardingScreen() : const AuthWrapper();
  }
}
