import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/presentation/screens/reset_password_screen.dart';

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
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueDeep = Color(0xFF1E5FE0);
  static const _fieldBorder = Color(0xFFE2E8F0);
  static const _heroAsset = 'assets/images/auth/hero_forgot_password.png';

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
    final size = MediaQuery.sizeOf(context);
    final short = size.height < 700;
    final narrow = size.width < 360;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned.fill(child: _SoftBlobsBackground()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      narrow ? 8 : 12,
                      4,
                      narrow ? 12 : 16,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _submitting ? null : _backToSignIn,
                        style: TextButton.styleFrom(
                          foregroundColor: _ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Back'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 16 : 22,
                        short ? 6 : 10,
                        narrow ? 16 : 22,
                        24,
                      ),
                      child: _sent
                          ? _SentState(
                              email: _emailController.text.trim(),
                              short: short,
                              onBackToSignIn: _backToSignIn,
                              onHaveToken: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.resetPassword,
                                  arguments: ResetPasswordArgs(
                                    email: _emailController.text.trim(),
                                  ),
                                );
                              },
                            )
                          : _FormState(
                              short: short,
                              narrow: narrow,
                              emailController: _emailController,
                              submitting: _submitting,
                              emailError: _emailError,
                              formError: _formError,
                              onSubmit: _submit,
                              onBackToSignIn: _backToSignIn,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  const _FormState({
    required this.short,
    required this.narrow,
    required this.emailController,
    required this.submitting,
    required this.emailError,
    required this.formError,
    required this.onSubmit,
    required this.onBackToSignIn,
  });

  final bool short;
  final bool narrow;
  final TextEditingController emailController;
  final bool submitting;
  final String? emailError;
  final String? formError;
  final VoidCallback onSubmit;
  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroHeader(short: short, narrow: narrow),
        SizedBox(height: short ? 16 : 22),
        Container(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 20,
            short ? 18 : 22,
            narrow ? 16 : 20,
            short ? 16 : 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _ForgotPasswordScreenState._ink.withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (formError != null) ...[
                _ErrorBanner(message: formError!),
                const SizedBox(height: 14),
              ],
              _LabeledField(
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                errorText: emailError,
                child: TextField(
                  controller: emailController,
                  enabled: !submitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => onSubmit(),
                  decoration: _inputDecoration(
                    hint: 'you@email.com',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _GradientButton(
                label: submitting ? 'Sending…' : 'Send reset link',
                showArrow: !submitting,
                onPressed: submitting ? null : onSubmit,
              ),
              const SizedBox(height: 14),
              const _SecurityBanner(),
            ],
          ),
        ),
        SizedBox(height: short ? 18 : 22),
        const _OrDivider(),
        SizedBox(height: short ? 14 : 16),
        _BackToLoginButton(onPressed: submitting ? null : onBackToSignIn),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAEB6C5), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _ForgotPasswordScreenState._fieldBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _ForgotPasswordScreenState._fieldBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _ForgotPasswordScreenState._blue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC0392B)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _ForgotPasswordScreenState._fieldBorder,
        ),
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  const _SentState({
    required this.email,
    required this.short,
    required this.onBackToSignIn,
    required this.onHaveToken,
  });

  final String email;
  final bool short;
  final VoidCallback onBackToSignIn;
  final VoidCallback onHaveToken;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PragyuLogo(height: 40),
        const SizedBox(height: 4),
        const Text(
          'Learn • Practice • Grow',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A93A8),
          ),
        ),
        SizedBox(height: short ? 20 : 28),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF5FF),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: _ForgotPasswordScreenState._blue,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Check your inbox',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _ForgotPasswordScreenState._ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'If an account exists for $email, '
          'password reset instructions are on the way.',
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            height: 1.45,
            color: _ForgotPasswordScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: short ? 22 : 28),
        _BackToLoginButton(onPressed: onBackToSignIn),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onHaveToken,
          style: TextButton.styleFrom(
            foregroundColor: _ForgotPasswordScreenState._blue,
          ),
          child: const Text(
            'I have a reset token',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SoftBlobsBackground extends StatelessWidget {
  const _SoftBlobsBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlobPainter());
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()
      ..color = const Color(0xFFDDEBFF).withValues(alpha: 0.7);
    final purple = Paint()
      ..color = const Color(0xFFE8E0FF).withValues(alpha: 0.55);

    final topRight = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.08,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topRight, blue);

    final bottomLeft = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.9,
        size.width * 0.48,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomLeft, purple);

    final bottomRight = Path()
      ..moveTo(size.width, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.92,
        size.width * 0.55,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(bottomRight, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.short, required this.narrow});

  final bool short;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PragyuLogo(height: 40),
        const SizedBox(height: 4),
        const Text(
          'Learn • Practice • Grow',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A93A8),
          ),
        ),
        SizedBox(height: short ? 14 : 18),
        Text(
          'Forgot Password?',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 26 : 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: _ForgotPasswordScreenState._ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No worries! Enter your email and we’ll send you a link to reset your password.',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: short ? 13 : 14.5,
            height: 1.4,
            color: _ForgotPasswordScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final hero = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: narrow ? 130 : 160,
        maxHeight: short ? 120 : 150,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          _ForgotPasswordScreenState._heroAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Password reset illustration',
          errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          copy,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: hero),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        const SizedBox(width: 8),
        hero,
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.icon,
    required this.child,
    this.errorText,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _ForgotPasswordScreenState._muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ForgotPasswordScreenState._ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFC0392B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      _ForgotPasswordScreenState._blueDeep,
                      _ForgotPasswordScreenState._blue,
                    ]
                  : const [
                      Color(0xFFB8C0D6),
                      Color(0xFFA8B4CC),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _ForgotPasswordScreenState._blue
                          .withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
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

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: _ForgotPasswordScreenState._blueDeep,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'For your security, we’ll send a password reset link to your registered email.',
              softWrap: true,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _ForgotPasswordScreenState._ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? _ForgotPasswordScreenState._blue
                  : const Color(0xFFB8C0D6),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: enabled
                    ? _ForgotPasswordScreenState._ink
                    : const Color(0xFFB8C0D6),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Back to Login',
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? _ForgotPasswordScreenState._ink
                        : const Color(0xFFB8C0D6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9AA3B5),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFC0392B),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
