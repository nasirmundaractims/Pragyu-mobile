import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/app_text_field.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

/// Route args for password reset (from forgot-password or email deep link).
class ResetPasswordArgs {
  const ResetPasswordArgs({
    this.email,
    this.token,
  });

  final String? email;
  final String? token;

  static ResetPasswordArgs fromObject(Object? value) {
    if (value is ResetPasswordArgs) return value;
    if (value is Map) {
      return ResetPasswordArgs(
        email: value['email']?.toString(),
        token: value['token']?.toString(),
      );
    }
    return const ResetPasswordArgs();
  }
}

/// Completes password reset with email + token from the reset link.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.args = const ResetPasswordArgs(),
    this.authRepository,
  });

  final ResetPasswordArgs args;
  final AuthGateway? authRepository;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final AuthGateway _auth =
      widget.authRepository ?? AuthRepository();
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _emailError;
  String? _tokenError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.args.email ?? '');
    _tokenController = TextEditingController(text: widget.args.token ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final token = _tokenController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!_isEmail(email) ? 'Enter a valid email' : null);
      _tokenError = token.isEmpty ? 'Enter the reset token from your email' : null;
      _passwordError = validateRegisterPassword(password);
      _confirmError = confirm != password ? 'Passwords do not match' : null;
      _formError = null;
    });
    if (_emailError != null ||
        _tokenError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await _auth.resetPassword(
        email: email,
        token: token,
        password: password,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can sign in now.'),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailError = error.fieldErrors['email'];
        _tokenError = error.fieldErrors['token'];
        _passwordError = error.fieldErrors['password'];
        _confirmError = error.fieldErrors['password_confirmation'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Unable to reset password. Try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static bool _isEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  void _backToSignIn() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Reset password'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _submitting ? null : _backToSignIn,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose a new password for your student account. '
                  'Paste the token from your reset email if it was not filled in.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                if (_formError != null) ...[
                  _ErrorBanner(message: _formError!),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@institute.edu',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  errorText: _emailError,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _tokenController,
                  label: 'Reset token',
                  hint: 'Token from email link',
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  errorText: _tokenError,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: 'New password',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  errorText: _passwordError,
                  autofillHints: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmController,
                  label: 'Confirm password',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  errorText: _confirmError,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _submitting ? 'Updating…' : 'Update password',
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : _backToSignIn,
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          height: 1.4,
          fontSize: 14,
        ),
      ),
    );
  }
}
