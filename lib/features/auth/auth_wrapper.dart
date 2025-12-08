import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import 'login_screen.dart';
import '../patient/patient_home.dart';
import '../admin/admin_home.dart';
import '../phlebotomist/phlebotomist_home.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<String?>(
            future: firestoreService.getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final role = roleSnapshot.data;
              if (role == 'admin') {
                return const AdminHome();
              } else if (role == 'phlebotomist') {
                return const PhlebotomistHome();
              } else {
                return const PatientHome(); // Default to patient
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
