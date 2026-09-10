import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    error = e.toString();
    debugPrint("Firebase initialization failed: $e");
  }
  
  runApp(BloodTestApp(initializationError: error));
}

class BloodTestApp extends StatelessWidget {
  final String? initializationError;
  const BloodTestApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    if (initializationError != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Firebase Init Error:\n$initializationError\n\nDid you add google-services.json?",
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Blood Test App',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}
