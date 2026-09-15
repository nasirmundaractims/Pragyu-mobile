import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/app_text_field.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/app/widgets/secondary_button.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';

/// S-04 Forgot password — request a secure reset link by email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.authRepository,
    this.initialEmail,
  });

  final AuthGateway? authRepository;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AuthGateway _auth =
      widget.authRepository ?? AuthRepository();
  late final TextEditingController _emailController;

  bool _submitting = false;
  bool _sent = false;
  String? _emailError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!_isEmail(email) ? 'Enter a valid email' : null);
      _formError = null;
    });
    if (_emailError != null) return;

    setState(() => _submitting = true);
    try {
      await _auth.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _formError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailError = error.fieldErrors['email'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Unable to send reset email. Try again.';
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
          title: const Text('Forgot password'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _submitting ? null : _backToSignIn,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: _sent ? _buildSentState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your email and we will send a secure reset link if an account exists.',
          style: TextStyle(
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
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'you@institute.edu',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !_submitting,
          errorText: _emailError,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: _submitting ? 'Sending…' : 'Send reset link',
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _submitting ? null : _backToSignIn,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const Text(
          'Check your inbox',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'If an account exists for ${_emailController.text.trim()}, '
          'password reset instructions are on the way.',
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        SecondaryButton(
          label: 'Back to sign in',
          onPressed: _backToSignIn,
        ),
      ],
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
