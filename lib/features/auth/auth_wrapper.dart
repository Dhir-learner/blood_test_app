import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
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
          return const _SplashScreen();
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<String?>(
            future: firestoreService.getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const _SplashScreen();
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

/// Branded loading screen, shown while auth state and role are resolving.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, AppTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.bloodtype_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 22),
            Text(
              "HomeLab",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
