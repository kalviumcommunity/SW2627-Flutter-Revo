import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/widgets/app_brand_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_service.dart';
import '../../services/mock_auth_service.dart';

/// FR-01 & Issue #8: Revo Login Screen.
/// Built with Revo Design System shared widgets and isolated mock authentication.
class LoginScreen extends StatefulWidget {
  final VoidCallback onNavigateToRegister;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    required this.onNavigateToRegister,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? MockAuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDemoCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _errorMessage = null;
    });
  }

  Future<void> _handleLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // Prevent duplicate submissions

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // On success, role_based_router's stream listener automatically routes to the appropriate dashboard
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('RevoException: ', '').replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RevoColors.surfaceBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: RevoSpacing.xl,
              vertical: RevoSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Revo Brand Header
                    const AppBrandHeader(
                      iconSize: 48,
                      showSubtitle: true,
                    ),
                    const SizedBox(height: 28),

                    // Card Container
                    Container(
                      padding: const EdgeInsets.all(RevoSpacing.xl),
                      decoration: BoxDecoration(
                        color: RevoColors.surfaceContainerLowest,
                        borderRadius: RevoSpacing.borderRadiusCard,
                        border: Border.all(color: RevoColors.surfaceDim),
                        boxShadow: RevoSpacing.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign In',
                            style: RevoTypography.title2.copyWith(
                              fontWeight: FontWeight.w700,
                              color: RevoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your credentials to access your production hub.',
                            style: RevoTypography.bodyMedium.copyWith(
                              color: RevoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: RevoColors.errorSurface,
                                borderRadius: RevoSpacing.borderRadiusButton,
                                border: Border.all(
                                  color: RevoColors.errorCrimson.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: RevoColors.errorCrimson,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: RevoColors.errorCrimson,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Input
                          AppTextField(
                            label: 'Email Address',
                            hint: 'director@revo.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: RevoColors.textSecondary,
                              size: 20,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email address.';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Input
                          AppTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passwordController,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: RevoColors.textSecondary,
                              size: 20,
                            ),
                            onFieldSubmitted: (_) => _handleLogin(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Sign In Button
                          PrimaryButton(
                            label: 'Sign In',
                            isLoading: _isLoading,
                            icon: Icons.login_rounded,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Demo Accounts Helper Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: RevoColors.surfaceContainerLow,
                        borderRadius: RevoSpacing.borderRadiusCard,
                        border: Border.all(color: RevoColors.surfaceDim),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.key_outlined,
                                size: 16,
                                color: RevoColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mock Demo Accounts (Quick Fill):',
                                  style: RevoTypography.captionBadge.copyWith(
                                    color: RevoColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _demoChip(
                                label: 'Director',
                                email: 'director@revo.com',
                                color: RevoColors.primary,
                              ),
                              _demoChip(
                                label: 'Cast Member',
                                email: 'cast@revo.com',
                                color: RevoColors.successGreen,
                              ),
                              _demoChip(
                                label: 'Theatre Admin',
                                email: 'admin@revo.com',
                                color: RevoColors.warningText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Register Link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account yet?",
                          style: RevoTypography.bodyMedium.copyWith(
                            color: RevoColors.textSecondary,
                          ),
                        ),
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

  Widget _demoChip({
    required String label,
    required String email,
    required Color color,
  }) {
    return ActionChip(
      avatar: CircleAvatar(
        radius: 6,
        backgroundColor: color,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: RevoColors.surfaceContainerLowest,
      side: const BorderSide(color: RevoColors.surfaceDim),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => _fillDemoCredentials(email, 'password123'),
    );
  }
}
