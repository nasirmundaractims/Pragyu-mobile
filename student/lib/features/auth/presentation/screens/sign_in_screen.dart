import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/verify_email_screen.dart';

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
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _fieldBorder = Color(0xFFE2E8F0);
  static const _heroAsset = 'assets/images/auth/hero_sign_in.png';

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
  void initState() {
    super.initState();
    AuthNavigation.redirectIfAuthenticated(context);
  }

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
          AuthNavigation.goAndClear(context, AppRoutes.orgPicker);
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
      if (error.code == 'AUTH_011') {
        final email = _emailController.text.trim();
        final goVerify = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify your email'),
            content: Text(
              error.message.isNotEmpty
                  ? error.message
                  : 'Please verify your email address before signing in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Resend email'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (goVerify == true) {
          Navigator.of(context).pushNamed(
            AppRoutes.verifyEmail,
            arguments: VerifyEmailArgs(email: email),
          );
        }
      }
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
      AuthNavigation.goAndClear(context, AppRoutes.orgPicker);
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

  void _onBack() {
    if (_submitting) return;
    if (_mfaStep) {
      _cancelMfa();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _socialStub(String provider) {
    _toast('$provider sign-in is coming soon. Use email for now.');
  }

  void _googleStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google sign-in needs a native token API. Use email for now.',
        ),
      ),
    );
  }

  static bool _isEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
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
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _submitting ? null : _onBack,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                          ),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _LanguageChip(
                          onTap: () => _toast('More languages coming soon.'),
                        ),
                      ],
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
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_mfaStep)
                              _MfaHeader(short: short)
                            else
                              _HeroHeader(short: short, narrow: narrow),
                            SizedBox(height: short ? 14 : 18),
                            if (!_mfaStep) ...[
                              const _ValueProps(),
                              SizedBox(height: short ? 16 : 20),
                            ],
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
                                    color: _ink.withValues(alpha: 0.07),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_formError != null) ...[
                                    _ErrorBanner(message: _formError!),
                                    const SizedBox(height: 14),
                                  ],
                                  if (_mfaStep) ...[
                                    _LabeledField(
                                      label: 'Authentication code',
                                      icon: Icons.pin_outlined,
                                      errorText: _mfaError,
                                      child: TextField(
                                        controller: _mfaController,
                                        enabled: !_submitting,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode,
                                        ],
                                        onSubmitted: (_) => _submit(),
                                        decoration: _inputDecoration(
                                          hint: '6-digit code',
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    _LabeledField(
                                      label: 'Email',
                                      icon: Icons.mail_outline_rounded,
                                      errorText: _emailError,
                                      child: TextField(
                                        controller: _emailController,
                                        enabled: !_submitting,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                        decoration: _inputDecoration(
                                          hint: 'you@email.com',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _LabeledField(
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      errorText: _passwordError,
                                      child: TextField(
                                        controller: _passwordController,
                                        enabled: !_submitting,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => _submit(),
                                        decoration: _inputDecoration(
                                          hint: 'Your password',
                                          suffix: IconButton(
                                            onPressed: _submitting
                                                ? null
                                                : () {
                                                    setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    );
                                                  },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Switch.adaptive(
                                              value: _rememberMe,
                                              activeThumbColor: _blue,
                                              activeTrackColor: _blue
                                                  .withValues(alpha: 0.45),
                                              onChanged: _submitting
                                                  ? null
                                                  : (value) => setState(
                                                        () => _rememberMe =
                                                            value,
                                                      ),
                                            ),
                                            const Expanded(
                                              child: Text(
                                                'Keep me signed in',
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _ink,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _submitting
                                                ? null
                                                : () {
                                                    Navigator.of(context)
                                                        .pushNamed(
                                                      AppRoutes.forgotPassword,
                                                    );
                                                  },
                                            style: TextButton.styleFrom(
                                              foregroundColor: _blue,
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Forgot password?',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _PrimaryButton(
                                    label: _submitting
                                        ? (_mfaStep
                                            ? 'Verifying…'
                                            : 'Signing in…')
                                        : (_mfaStep
                                            ? 'Verify and continue'
                                            : 'Sign in'),
                                    showArrow: !_submitting && !_mfaStep,
                                    onPressed: _submitting ? null : _submit,
                                  ),
                                  if (!_mfaStep) ...[
                                    const SizedBox(height: 18),
                                    const _OrDivider(),
                                    const SizedBox(height: 14),
                                    _SocialRow(
                                      narrow: narrow,
                                      onGoogle: _googleStub,
                                      onApple: () => _socialStub('Apple'),
                                      onPhone: () => _socialStub('Phone'),
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text(
                                            "Don't have an account? ",
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: _muted,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _submitting
                                                ? null
                                                : () {
                                                    Navigator.of(context)
                                                        .pushNamed(
                                                      AppRoutes
                                                          .createAccountStub,
                                                    );
                                                  },
                                            child: const Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: _blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!_mfaStep) ...[
                              const SizedBox(height: 22),
                              const _TrustRow(),
                            ],
                          ],
                        ),
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

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAEB6C5), fontSize: 14),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC0392B)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
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
      ..color = const Color(0xFFDDEBFF).withValues(alpha: 0.75);
    final purple = Paint()
      ..color = const Color(0xFFE8E0FF).withValues(alpha: 0.55);
    final teal = Paint()
      ..color = const Color(0xFFD9F5EF).withValues(alpha: 0.5);

    final topRight = Path()
      ..moveTo(size.width * 0.5, 0)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.1,
        size.width,
        size.height * 0.22,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topRight, blue);

    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.35, 0)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.12,
        0,
        size.height * 0.2,
      )
      ..close();
    canvas.drawPath(topLeft, purple);

    final bottom = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.92,
        size.width * 0.55,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottom, teal);

    final bottomRight = Path()
      ..moveTo(size.width, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.9,
        size.width * 0.5,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(bottomRight, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 16, color: Color(0xFF2F7BFF)),
              SizedBox(width: 6),
              Text(
                'English',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF7A8499),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        SizedBox(height: short ? 12 : 16),
        Text(
          'Welcome Back',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 26 : 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: _SignInScreenState._ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let’s continue your learning journey!',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: short ? 13 : 14.5,
            height: 1.4,
            color: _SignInScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final hero = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: narrow ? 140 : 170,
        maxHeight: short ? 130 : 160,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          _SignInScreenState._heroAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Student learning illustration',
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

class _MfaHeader extends StatelessWidget {
  const _MfaHeader({required this.short});

  final bool short;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PragyuLogo(height: 40),
        SizedBox(height: short ? 14 : 18),
        const Text(
          'Verify sign-in',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: _SignInScreenState._ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the code from your authenticator app.',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            height: 1.4,
            color: _SignInScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ValueProps extends StatelessWidget {
  const _ValueProps();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, Color, String)>[
      (Icons.school_rounded, Color(0xFF2F7BFF), 'Learn Anytime'),
      (Icons.track_changes_rounded, Color(0xFF9B6BFF), 'Practice Smarter'),
      (Icons.bar_chart_rounded, Color(0xFF1DBA8A), 'Grow Faster'),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECF4)),
                boxShadow: [
                  BoxShadow(
                    color: _SignInScreenState._ink.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: items[i].$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(items[i].$1, size: 18, color: items[i].$2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    items[i].$3,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _SignInScreenState._ink,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            Icon(icon, size: 16, color: _SignInScreenState._muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _SignInScreenState._ink,
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
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
            color: enabled
                ? _SignInScreenState._blue
                : const Color(0xFFB8C0D6),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _SignInScreenState._blue.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.narrow,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
  });

  final bool narrow;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _SocialButton(
        label: 'Continue with Google',
        icon: Icons.g_mobiledata_rounded,
        onPressed: onGoogle,
      ),
      _SocialButton(
        label: 'Continue with Apple',
        icon: Icons.apple_rounded,
        onPressed: onApple,
      ),
      _SocialButton(
        label: 'Continue with Phone',
        icon: Icons.phone_iphone_rounded,
        onPressed: onPhone,
      ),
    ];

    if (narrow) {
      return Column(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _SignInScreenState._ink,
        side: const BorderSide(color: _SignInScreenState._fieldBorder),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: _SignInScreenState._ink),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, Color, String)>[
      (Icons.groups_rounded, Color(0xFF9B6BFF), '50K+ Happy Learners'),
      (Icons.star_rounded, Color(0xFF2F7BFF), '4.8 App Rating'),
      (Icons.verified_user_rounded, Color(0xFF1DBA8A), 'Trusted & Secure'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 340;
        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _TrustItem(item: items[i])),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _TrustItem(item: items[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.item});

  final (IconData, Color, String) item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(item.$1, size: 16, color: item.$2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.$3,
            softWrap: true,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
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
