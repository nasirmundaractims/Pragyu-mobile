import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/app_text_field.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

/// S-03 Sign in — email + password against Identity API (optional MFA step).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.authRepository,
  });

  final AuthGateway? authRepository;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AuthGateway _auth =
      widget.authRepository ?? AuthRepository();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _mfaError;
  String? _formError;
  String? _mfaChallengeToken;

  bool get _mfaStep => _mfaChallengeToken != null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (_mfaStep) {
      await _submitMfa();
      return;
    }
    await _submitPassword();
  }

  Future<void> _submitPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!_isEmail(email) ? 'Enter a valid email' : null);
      _passwordError = password.isEmpty ? 'Enter your password' : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      final result = await _auth.login(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;

      switch (result) {
        case LoginSuccess():
          Navigator.of(context).pushReplacementNamed(AppRoutes.authSuccessStub);
        case LoginMfaRequired(:final challengeToken):
          setState(() {
            _mfaChallengeToken = challengeToken;
            _mfaController.clear();
            _mfaError = null;
            _formError = null;
          });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailError = error.fieldErrors['email'];
        _passwordError = error.fieldErrors['password'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError =
            'Sign-in didn’t work. Check email and password, then try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitMfa() async {
    final code = _mfaController.text.trim();
    setState(() {
      _mfaError = code.isEmpty ? 'Enter your authentication code' : null;
      _formError = null;
    });
    if (_mfaError != null) return;

    setState(() => _submitting = true);
    try {
      await _auth.verifyMfaLogin(
        challengeToken: _mfaChallengeToken!,
        code: code,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.authSuccessStub);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _mfaError = error.fieldErrors['code'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'That code didn’t work. Try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _cancelMfa() {
    setState(() {
      _mfaChallengeToken = null;
      _mfaController.clear();
      _mfaError = null;
      _formError = null;
    });
  }

  static bool _isEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(_mfaStep ? 'Verify sign-in' : 'Sign in'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _submitting
                ? null
                : () {
                    if (_mfaStep) {
                      _cancelMfa();
                      return;
                    }
                    Navigator.of(context).maybePop();
                  },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _mfaStep
                        ? 'Enter the code from your authenticator app.'
                        : 'Welcome back. Use your student email and password.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_formError != null) ...[
                    _ErrorBanner(message: _formError!),
                    const SizedBox(height: 16),
                  ],
                  if (_mfaStep) ...[
                    AppTextField(
                      controller: _mfaController,
                      label: 'Authentication code',
                      hint: '6-digit code',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      enabled: !_submitting,
                      errorText: _mfaError,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onSubmitted: (_) => _submit(),
                    ),
                  ] else ...[
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
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Your password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_submitting,
                      errorText: _passwordError,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.forgotPasswordStub);
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Keep me signed in',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                      value: _rememberMe,
                      activeThumbColor: AppColors.brand,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _rememberMe = value),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _submitting
                        ? (_mfaStep ? 'Verifying…' : 'Signing in…')
                        : (_mfaStep ? 'Verify and continue' : 'Sign in'),
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
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
