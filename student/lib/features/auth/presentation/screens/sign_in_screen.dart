import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/config/app_config.dart';
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
  static const _blue = Color(0xFF4A7DFF);
  static const _purple = Color(0xFF7C5CFF);
  static const _fieldBorder = Color(0xFFE4E8F0);
  static const _cardShadow = Color(0xFF1A2B4C);

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

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need help?'),
        content: const Text(
          'Use the email and password from your institute invite. '
          'If you can’t sign in, tap Forgot password or ask your institute admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
    final appName = AppConfig.instance.appName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF3F0FF),
                Color(0xFFF7F8FC),
                Color(0xFFEEF4FF),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _submitting ? null : _onBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: _ink,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _submitting ? null : _showHelp,
                        style: TextButton.styleFrom(
                          foregroundColor: _purple,
                        ),
                        child: const Text(
                          'Need help?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            appName: appName,
                            mfaStep: _mfaStep,
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: _cardShadow.withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
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
                                        prefix: Icons.pin_outlined,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  _LabeledField(
                                    label: 'Email',
                                    errorText: _emailError,
                                    child: TextField(
                                      controller: _emailController,
                                      enabled: !_submitting,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: _inputDecoration(
                                        hint: 'you@institute.edu',
                                        prefix: Icons.mail_outline_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LabeledField(
                                    label: 'Password',
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
                                        prefix: Icons.lock_outline_rounded,
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
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: _muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch.adaptive(
                                            value: _rememberMe,
                                            activeThumbColor: _blue,
                                            activeTrackColor:
                                                _blue.withValues(alpha: 0.45),
                                            onChanged: _submitting
                                                ? null
                                                : (value) => setState(
                                                      () =>
                                                          _rememberMe = value,
                                                    ),
                                          ),
                                          const Text(
                                            'Keep me signed in',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: _submitting
                                            ? null
                                            : () {
                                                Navigator.of(context).pushNamed(
                                                  AppRoutes.forgotPassword,
                                                );
                                              },
                                        style: TextButton.styleFrom(
                                          foregroundColor: _purple,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _GradientSignInButton(
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
                                  const SizedBox(height: 16),
                                  const _OrDivider(),
                                  const SizedBox(height: 16),
                                  _GoogleButton(onPressed: _googleStub),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'New to $appName? ',
                                          style: const TextStyle(
                                            fontSize: 13,
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
                                            'Create an account',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: _purple,
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
                            const _FeatureHighlights(),
                            const SizedBox(height: 18),
                            const _FooterMotto(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAEB6C5), fontSize: 14),
      prefixIcon: Icon(prefix, color: _muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appName,
    required this.mfaStep,
  });

  final String appName;
  final bool mfaStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PragyuLogo(height: 40),
        const SizedBox(height: 8),
        const Text(
          'LEARN  ·  PRACTICE  ·  IMPROVE  ·  SUCCEED',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.0,
            color: _SignInScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!mfaStep) ...[
          const SizedBox(height: 16),
          const _SignInHeroBanner(),
        ],
        const SizedBox(height: 16),
        if (mfaStep)
          const Text(
            'Verify sign-in',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _SignInScreenState._ink,
              height: 1.15,
            ),
          )
        else
          const Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: _SignInScreenState._ink,
              ),
              children: [
                TextSpan(text: 'Welcome '),
                TextSpan(
                  text: 'Back!',
                  style: TextStyle(
                    color: _SignInScreenState._purple,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          mfaStep
              ? 'Enter the code from your authenticator app.'
              : 'Sign in to continue your learning journey with $appName.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: _SignInScreenState._muted,
          ),
        ),
      ],
    );
  }
}

class _SignInHeroBanner extends StatelessWidget {
  const _SignInHeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home_hero.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, 0),
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, stackTrace) => Container(
                color: const Color(0xFFE8EEFF),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE6142033),
                    Color(0x99142033),
                    Color(0x33142033),
                    Color(0x00142033),
                  ],
                  stops: [0, 0.38, 0.72, 1],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KEEP LEARNING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFFB8C7FF),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'A brighter future\nstarts '),
                        TextSpan(
                          text: 'with you',
                          style: TextStyle(color: Color(0xFF9EC0FF)),
                        ),
                      ],
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _SignInScreenState._ink,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFC0392B),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientSignInButton extends StatelessWidget {
  const _GradientSignInButton({
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
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      _SignInScreenState._purple,
                      _SignInScreenState._blue,
                    ]
                  : const [
                      Color(0xFFB8B4D8),
                      Color(0xFFA8B8E0),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color:
                          _SignInScreenState._blue.withValues(alpha: 0.28),
                      blurRadius: 14,
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
        Expanded(child: Divider(color: Color(0xFFE6EAF2))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA0A8B8),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE6EAF2))),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _SignInScreenState._ink,
          side: const BorderSide(color: Color(0xFFE4E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          backgroundColor: Colors.white,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleG(),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Continue with Google',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.84,
    );
    stroke.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.6, false, stroke);
    stroke.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.2, 1.2, false, stroke);
    stroke.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.4, 0.9, false, stroke);
    stroke.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.3, 1.1, false, stroke);
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.48,
        size.height * 0.42,
        size.width * 0.44,
        size.height * 0.16,
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureHighlights extends StatelessWidget {
  const _FeatureHighlights();

  @override
  Widget build(BuildContext context) {
    Widget item({
      required Color bg,
      required Color iconColor,
      required IconData icon,
      required String label,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF5)),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: _SignInScreenState._ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item(
          bg: const Color(0xFFE8F0FF),
          iconColor: _SignInScreenState._blue,
          icon: Icons.menu_book_rounded,
          label: 'Learn\nAnywhere',
        ),
        const SizedBox(width: 8),
        item(
          bg: const Color(0xFFF0EBFF),
          iconColor: _SignInScreenState._purple,
          icon: Icons.bar_chart_rounded,
          label: 'Track Your\nProgress',
        ),
        const SizedBox(width: 8),
        item(
          bg: const Color(0xFFE8F8EF),
          iconColor: const Color(0xFF1F8A5B),
          icon: Icons.school_rounded,
          label: 'Achieve Your\nGoals',
        ),
      ],
    );
  }
}

class _FooterMotto extends StatelessWidget {
  const _FooterMotto();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD8DEEA))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'TOGETHER FOR A SMARTER FUTURE',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: Color(0xFFA0A8B8),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD8DEEA))),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC0392B).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFC0392B),
          height: 1.4,
          fontSize: 13,
        ),
      ),
    );
  }
}
