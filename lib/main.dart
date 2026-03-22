import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t_percel/screens/dashboard_page.dart';
import 'package:t_percel/screens/debug_api_page.dart';
import 'package:t_percel/screens/login_page.dart';
import 'package:t_percel/screens/my_parcels_page.dart';
import 'package:t_percel/screens/profile_page.dart';
import 'package:t_percel/screens/scan_qr_page.dart';
import 'package:t_percel/screens/assign_qr_page.dart';
import 'package:t_percel/screens/search_parcel_page.dart';
import 'package:t_percel/services/api_service.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// Tilisho Safari–style colors
class AppColors {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color redBar = Color(0xFFB71C1C);
  static const Color darkRed = Color(0xFF8B0000);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tilisho Parcel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Colors.black87,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBlue,
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/debug-api': (context) => const DebugApiPage(),
        '/my-parcels': (context) => const MyParcelsPage(),
        '/profile': (context) => const ProfilePage(),
        '/scan-qr': (context) => const ScanQrPage(),
        '/assign-qr': (context) => const AssignQrPage(),
        '/search-parcel': (context) => const SearchParcelPage(),
      },
    );
  }
}

/// Simple splash that checks auth state and redirects accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      if (loggedIn) {
        // Verify user is still a staff member
        try {
          final isStaff = await ApiService.isStaff();
          if (!isStaff) {
            // User is not staff anymore, clear auth
            await ApiService.logout();
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }
          Navigator.pushReplacementNamed(context, '/dashboard');
        } catch (e) {
          // Error checking role, logout for safety
          await ApiService.logout();
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
