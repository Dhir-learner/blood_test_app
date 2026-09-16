import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Generic messages for credential failures so the UI doesn't reveal which accounts exist.
  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Please enter a valid email address.";
      case 'weak-password':
        return "Password must be at least 6 characters.";
      case 'email-already-in-use':
        return "An account already exists for this email.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'network-request-failed':
        return "Network error. Please check your connection.";
      default:
        return _isLogin
            ? "Invalid email or password."
            : "Registration failed. Please try again.";
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text; // Passwords are never trimmed
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        // Register (always as a patient)
        final cred = await _authService.signUp(email, password);
        if (cred.user != null) {
          await _firestoreService.createUserProfile(
            cred.user!.uid,
            cred.user!.email ?? email,
            name,
            phone,
          );
        }
      }
      // Navigation is handled by AuthWrapper listening to stream
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authErrorMessage(e));
    } catch (e) {
      debugPrint("Auth error: $e");
      if (mounted) _showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Brand(scheme: scheme),
                    const SizedBox(height: 32),
                    Text(
                      _isLogin ? "Welcome back" : "Create your account",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? "Sign in to book tests and view your reports."
                          : "Book blood tests at home and get reports on your phone.",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: "Full name",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? "Please enter your name"
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Phone number",
                          helperText: "The collector will call you on this number",
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          final digits =
                              (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length < 10) {
                            return "Enter a valid phone number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return "Please enter your email";
                        if (!value.contains('@') || !value.contains('.')) {
                          return "Enter a valid email address";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return "Please enter your password";
                        if (!_isLogin && v!.length < 6) {
                          return "Use at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : Text(_isLogin ? "Sign in" : "Create account"),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isLogin = !_isLogin;
                                _formKey.currentState?.reset();
                              }),
                      child: Text(_isLogin
                          ? "New here? Create an account"
                          : "Already have an account? Sign in"),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Lab staff accounts are created by an administrator.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final ColorScheme scheme;
  const _Brand({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 14),
        Text(
          "HomeLab",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        Text(
          "Blood tests, collected at home",
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}
