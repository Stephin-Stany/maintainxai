import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() {
  runApp(const MaintainXApp());
}

class MaintainXApp extends StatelessWidget {
  const MaintainXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaintainX AI',
      debugShowCheckedModeBanner: false,
      
      // --- THEME CONFIGURATION ---
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        
        // Using a modern font for that AI-driven aesthetic
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        
        // Customizing the global card and button styles
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent.withOpacity(0.7),
          surface: const Color(0xFF161618),
        ),
        
        useMaterial3: true,
      ),

      // --- ROUTING ---
      // We start at the Login Page
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

// Backwards compatibility for tests expecting `MyApp`
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaintainXApp();
  }
}