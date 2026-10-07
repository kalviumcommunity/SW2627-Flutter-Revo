import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../services/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onNavigateToRegister;

  const LoginScreen({
    super.key,
    required this.onNavigateToRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'director@revo.com');
  final _passwordController = TextEditingController(text: 'password123');
  bool _isLoading = false;
  String? _errorMessage;

  final _authService = FirebaseAuthService();

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAlignment.stretch,
                  children: [
                    // Brand Icon & Title
                    Icon(
                      Icons.theater_comedy,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Revo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Theatre Production Management System',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email input
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email address.';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password input
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Demo Credentials helper
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAlignment.start,
                          children: [
                            Text(
                              'Demo Test Accounts:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('Director'),
                                  onPressed: () {
                                    _emailController.text = 'director@revo.com';
                                  },
                                ),
                                ActionChip(
                                  label: const Text('Cast Member'),
                                  onPressed: () {
                                    _emailController.text = 'cast@revo.com';
                                  },
                                ),
                                ActionChip(
                                  label: const Text('Admin'),
                                  onPressed: () {
                                    _emailController.text = 'admin@revo.com';
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Navigate to Register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: widget.onNavigateToRegister,
                          child: const Text('Register Here'),
                        ),
                      ],
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
