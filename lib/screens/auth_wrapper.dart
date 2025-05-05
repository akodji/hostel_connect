import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostel_connect/screens/auth/login_screen.dart';
import 'package:hostel_connect/screens/student/home_screen.dart';
import 'package:hostel_connect/screens/owner/owner_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // If no user is logged in, show login screen
    if (currentUser == null) {
      return const LoginScreen();
    } else {
      // User is logged in, check profile to determine their role
      return FutureBuilder(
        future: Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', currentUser.id)
            .single(),
        builder: (context, snapshot) {
          // Show loading spinner while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF3498db)),
              ),
            );
          }
          
          // Error handling
          if (snapshot.hasError || !snapshot.hasData) {
            // If we can't determine user type, default to student view
            return const HomeScreen();
          }
          
          // Route to appropriate home screen based on user_type
          final userType = snapshot.data?['role'] as String?;
          if (userType == 'owner') {
            return const OwnerHomeScreen();
          } else {
            return const HomeScreen();
          }
        },
      );
    }
  }
}

class AuthController {
  static Future<void> handleAuthStateChange(BuildContext context) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    if (currentUser == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      
      final userType = response['role'] as String?;
      
      if (userType == 'owner') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OwnerHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      // If error occurs, default to student view
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}