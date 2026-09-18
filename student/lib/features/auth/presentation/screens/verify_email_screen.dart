import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/app_text_field.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';

/// Route args for email verification (from register, sign-in, or deep link).
class VerifyEmailArgs {
  const VerifyEmailArgs({
    this.email,
    this.id,
    this.token,
  });

  final String? email;
  final String? id;
  final String? token;

  static VerifyEmailArgs fromObject(Object? value) {
    if (value is VerifyEmailArgs) return value;
    if (value is Map) {
      return VerifyEmailArgs(
        email: value['email']?.toString(),
        id: value['id']?.toString(),
        token: value['token']?.toString(),
      );
    }
    return const VerifyEmailArgs();
  }
}

/// Email verification — confirm link (`id`+`token`) or resend.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.args = const VerifyEmailArgs(),
    this.authRepository,
  });

  final VerifyEmailArgs args;
  final AuthGateway? authRepository;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _VerifyStatus { idle, verifying, success, error }

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final AuthGateway _auth =
      widget.authRepository ?? AuthRepository();
  late final TextEditingController _emailController;

  _VerifyStatus _status = _VerifyStatus.idle;
  String _message = 'Confirm your email to activate your account.';
  bool _resending = false;
  String? _emailError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.args.email ?? '');
    final id = widget.args.id?.trim() ?? '';
    final token = widget.args.token?.trim() ?? '';
    if (id.isNotEmpty && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirm(id: id, token: token);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _confirm({
    required String id,
    required String token,
  }) async {
    setState(() {
      _status = _VerifyStatus.verifying;
      _formError = null;
      _message = 'Verifying your email…';
    });
    try {
      await _auth.verifyEmail(id: id, token: token);
      if (!mounted) return;
      setState(() {
        _status = _VerifyStatus.success;
        _message = 'Your email has been verified. You can sign in now.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _VerifyStatus.error;
        _message = error.message;
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _VerifyStatus.error;
        _message = 'Verification link is invalid or expired.';
        _formError = _message;
      });
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!_isEmail(email) ? 'Enter a valid email' : null);
      _formError = null;
    });
    if (_emailError != null) return;

    setState(() => _resending = true);
    try {
      await _auth.resendVerification(email: email);
      if (!mounted) return;
      setState(() {
        _message =
            'If an account exists for $email, a verification email has been sent.';
        _formError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists, a verification email has been sent.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailError = error.fieldErrors['email'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Unable to resend verification email. Try again.';
      });
    } finally {
      if (mounted) setState(() => _resending = false);
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

  void _goSignIn() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.signIn,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _status == _VerifyStatus.verifying || _resending;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Email verification'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: busy ? null : _backToSignIn,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                if (_status == _VerifyStatus.verifying) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
                if (_status == _VerifyStatus.success) ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.brand,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Continue to sign in',
                    onPressed: _goSignIn,
                  ),
                ],
                if (_status != _VerifyStatus.verifying &&
                    _status != _VerifyStatus.success) ...[
                  if (_formError != null) ...[
                    _ErrorBanner(message: _formError!),
                    const SizedBox(height: 16),
                  ],
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@institute.edu',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    enabled: !_resending,
                    errorText: _emailError,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _resend(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _resending
                        ? 'Sending…'
                        : 'Resend verification email',
                    onPressed: _resending ? null : _resend,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _resending ? null : _backToSignIn,
                    child: const Text('Back to sign in'),
                  ),
                ],
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
