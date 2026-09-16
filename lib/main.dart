import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
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

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    ChangeNotifierProvider.value(
      value: themeController,
      child: BloodTestApp(initializationError: error),
    ),
  );
}

class BloodTestApp extends StatelessWidget {
  final String? initializationError;
  const BloodTestApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    if (initializationError != null) {
      return MaterialApp(
        title: 'Blood Test App',
        theme: AppTheme.light(),
        home: _StartupErrorScreen(error: initializationError!),
      );
    }

    final themeMode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'Blood Test App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
              const SizedBox(height: 20),
              Text(
                "Firebase Init Error",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                "The app could not connect to Firebase. Check that "
                "google-services.json is in android/app/.",
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
