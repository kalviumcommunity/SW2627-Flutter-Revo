import 'package:flutter/material.dart';
import '../../core/constants/revo_colors.dart';
import '../../core/constants/revo_spacing.dart';
import '../../core/constants/revo_typography.dart';
import '../../core/enums/revo_enums.dart';
import '../../core/widgets/app_brand_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_service.dart';
import '../../services/mock_auth_service.dart';

/// FR-01 & Issue #8: Revo Register Screen.
/// Built with Revo Design System shared widgets, role selection controls,
/// and guarded Admin self-registration.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogin;
  final AuthService? authService;

  const RegisterScreen({
    super.key,
    required this.onNavigateToLogin,
    this.authService,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminPasscodeController = TextEditingController();

  UserRole _selectedRole = UserRole.cast;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminPasscodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        adminPasscode: _selectedRole == UserRole.admin
            ? _adminPasscodeController.text.trim()
            : null,
      );
      // On success, role_based_router's stream listener automatically routes to the appropriate dashboard
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e
              .toString()
              .replaceFirst('RevoException: ', '')
              .replaceFirst('Exception: ', '');
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
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Sign In',
          onPressed: widget.onNavigateToLogin,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: RevoSpacing.xl,
              vertical: RevoSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    const AppBrandHeader(
                      iconSize: 42,
                      title: 'Join Revo',
                      subtitle: 'Register your production account',
                    ),
                    const SizedBox(height: 24),

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
                            'Account Details',
                            style: RevoTypography.title2.copyWith(
                              fontWeight: FontWeight.w700,
                              color: RevoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your profile information and select your system role.',
                            style: RevoTypography.bodyMedium.copyWith(
                              color: RevoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),

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

                          // Full Name
                          AppTextField(
                            label: 'Full Name',
                            hint: 'e.g., Sarah Jenkins',
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: RevoColors.textSecondary,
                              size: 20,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Email
                          AppTextField(
                            label: 'Email Address',
                            hint: 'name@theatre.org',
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
                                return 'Please enter your email.';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          AppTextField(
                            label: 'Password',
                            hint: 'At least 6 characters',
                            controller: _passwordController,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: RevoColors.textSecondary,
                              size: 20,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a password.';
                              }
                              if (value.trim().length < 6) {
                                return 'Password must be at least 6 characters long.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirm Password
                          AppTextField(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            textInputAction: _selectedRole == UserRole.admin
                                ? TextInputAction.next
                                : TextInputAction.done,
                            prefixIcon: const Icon(
                              Icons.lock_reset_rounded,
                              color: RevoColors.textSecondary,
                              size: 20,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please confirm your password.';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Role Selector
                          Text(
                            'Select System Role',
                            style: RevoTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: RevoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRoleSelector(),
                          const SizedBox(height: 16),

                          // Admin Authorization Passcode (Guarded Registration)
                          if (_selectedRole == UserRole.admin) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: RevoColors.warningSurface,
                                borderRadius: RevoSpacing.borderRadiusButton,
                                border: Border.all(
                                  color: RevoColors.warningAmber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: RevoColors.warningText,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Theatre Admin accounts require administrative authorization code (${MockAuthService.validAdminPasscode}).',
                                      style: const TextStyle(
                                        color: RevoColors.warningText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              label: 'Admin Authorization Code',
                              hint: 'Enter ADMIN-2026',
                              controller: _adminPasscodeController,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              prefixIcon: const Icon(
                                Icons.verified_user_outlined,
                                color: RevoColors.warningText,
                                size: 20,
                              ),
                              validator: (value) {
                                if (_selectedRole == UserRole.admin) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Admin authorization code is required.';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Submit Button
                          PrimaryButton(
                            label: 'Create Account & Sign In',
                            isLoading: _isLoading,
                            icon: Icons.person_add_rounded,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Back to Login
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: RevoTypography.bodyMedium.copyWith(
                            color: RevoColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onNavigateToLogin,
                          child: const Text('Sign In Here'),
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

  Widget _buildRoleSelector() {
    return SegmentedButton<UserRole>(
      segments: const [
        ButtonSegment<UserRole>(
          value: UserRole.director,
          label: Text('Director'),
          icon: Icon(Icons.movie_creation_outlined, size: 18),
        ),
        ButtonSegment<UserRole>(
          value: UserRole.cast,
          label: Text('Cast'),
          icon: Icon(Icons.groups_outlined, size: 18),
        ),
        ButtonSegment<UserRole>(
          value: UserRole.admin,
          label: Text('Admin'),
          icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
        ),
      ],
      selected: {_selectedRole},
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: RevoSpacing.borderRadiusButton,
          ),
        ),
      ),
      onSelectionChanged: (Set<UserRole> newSelection) {
        setState(() {
          _selectedRole = newSelection.first;
        });
      },
    );
  }
}
