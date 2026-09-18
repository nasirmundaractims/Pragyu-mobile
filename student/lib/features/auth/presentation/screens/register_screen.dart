import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/verify_email_screen.dart';

/// S-04 Create account — student registration with phone OTP.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.authRepository,
  });

  final AuthGateway? authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueDeep = Color(0xFF1E5FE0);
  static const _fieldBorder = Color(0xFFE2E8F0);
  static const _success = Color(0xFF22A06B);
  static const _reqBg = Color(0xFFEEF5FF);
  static const _heroAsset = 'assets/images/auth/hero_create_account.png';

  late final AuthGateway _auth =
      widget.authRepository ?? AuthRepository();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _submitting = false;
  bool _sendingOtp = false;
  bool _confirmingOtp = false;
  bool _otpSent = false;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  String? _phoneVerificationToken;
  String? _verifiedPhone;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  String? _otpError;
  String? _passwordError;
  String? _confirmError;
  String? _termsError;
  String? _formError;

  bool get _phoneVerified =>
      _phoneVerificationToken != null && _phoneVerificationToken!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    AuthNavigation.redirectIfAuthenticated(context);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    setState(() => _otpCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpCooldown <= 1) {
        timer.cancel();
        setState(() => _otpCooldown = 0);
        return;
      }
      setState(() => _otpCooldown -= 1);
    });
  }

  void _resetPhoneVerification() {
    _phoneVerificationToken = null;
    _verifiedPhone = null;
    _otpSent = false;
    _otpController.clear();
    _otpError = null;
  }

  Future<void> _sendOtp() async {
    if (_sendingOtp || _phoneVerified) return;
    final phone = _phoneController.text.trim();
    setState(() {
      _phoneError = phone.length < 7 ? 'Enter a valid mobile number' : null;
      _formError = null;
    });
    if (_phoneError != null) return;

    setState(() => _sendingOtp = true);
    try {
      await _auth.requestRegistrationPhoneOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpError = null;
      });
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your mobile number.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _phoneError = error.fieldErrors['phone'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Could not send OTP. Check the number and try again.';
      });
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _confirmOtp() async {
    if (_confirmingOtp || _phoneVerified) return;
    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();
    setState(() {
      _otpError = code.isEmpty ? 'Enter the OTP code' : null;
      _formError = null;
    });
    if (_otpError != null) return;

    setState(() => _confirmingOtp = true);
    try {
      final result = await _auth.confirmRegistrationPhoneOtp(
        phone: phone,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _phoneVerificationToken = result.phoneVerificationToken;
        _verifiedPhone = result.phone;
        _otpError = null;
        _phoneError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number verified.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _otpError = error.fieldErrors['code'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'That OTP didn’t work. Try again.';
      });
    } finally {
      if (mounted) setState(() => _confirmingOtp = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = (_verifiedPhone ?? _phoneController.text).trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _firstNameError = firstName.isEmpty ? 'Enter your first name' : null;
      _lastNameError = lastName.isEmpty ? 'Enter your last name' : null;
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!_isEmail(email) ? 'Enter a valid email' : null);
      _phoneError = !_phoneVerified ? 'Verify your mobile number' : null;
      _passwordError = validateRegisterPassword(password);
      _confirmError = confirm != password ? 'Passwords do not match' : null;
      _termsError =
          !_acceptTerms ? 'Accept the terms to continue' : null;
      _formError = null;
    });

    if (_firstNameError != null ||
        _lastNameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _confirmError != null ||
        _termsError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _auth.register(
        RegisterRequest(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          phoneVerificationToken: _phoneVerificationToken!,
          password: password,
          passwordConfirmation: confirm,
          acceptTerms: _acceptTerms,
        ),
      );
      if (!mounted) return;

      switch (result) {
        case RegisterSuccess():
          AuthNavigation.goAndClear(context, AppRoutes.orgPicker);
        case RegisterEmailVerificationRequired(:final message, :final email):
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Verify your email'),
              content: Text('$message\n\nWe sent a link to $email.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.verifyEmail,
            arguments: VerifyEmailArgs(email: email),
          );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _firstNameError = error.fieldErrors['first_name'];
        _lastNameError = error.fieldErrors['last_name'];
        _emailError = error.fieldErrors['email'];
        _phoneError = error.fieldErrors['phone'] ??
            error.fieldErrors['phone_verification_token'];
        _passwordError = error.fieldErrors['password'];
        _confirmError = error.fieldErrors['password_confirmation'];
        _termsError = error.fieldErrors['accept_terms'];
        _formError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError =
            'Registration didn’t work. Check your details and try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _socialStub(String provider) {
    _toast('$provider sign-up is coming soon. Use email for now.');
  }

  Future<void> _openConfigUrl(String? url) async {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) {
      _toast('Link is not configured for this build.');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _toast('Invalid link.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open link.');
  }

  static bool _isEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _sendingOtp || _confirmingOtp;
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
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).maybePop(),
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
                          onTap: () => _toast(
                            'More languages coming soon.',
                          ),
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
                            _HeroHeader(short: short, narrow: narrow),
                            SizedBox(height: short ? 16 : 20),
                            if (_formError != null) ...[
                              _ErrorBanner(message: _formError!),
                              const SizedBox(height: 14),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledField(
                                    label: 'First Name',
                                    icon: Icons.person_outline_rounded,
                                    errorText: _firstNameError,
                                    child: TextField(
                                      controller: _firstNameController,
                                      enabled: !_submitting,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [
                                        AutofillHints.givenName,
                                      ],
                                      decoration: _inputDecoration(
                                        hint: 'e.g. Nasir',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledField(
                                    label: 'Last Name',
                                    icon: Icons.badge_outlined,
                                    errorText: _lastNameError,
                                    child: TextField(
                                      controller: _lastNameController,
                                      enabled: !_submitting,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [
                                        AutofillHints.familyName,
                                      ],
                                      decoration: _inputDecoration(
                                        hint: 'e.g. Munda',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _LabeledField(
                              label: 'Email Address',
                              icon: Icons.mail_outline_rounded,
                              errorText: _emailError,
                              child: TextField(
                                controller: _emailController,
                                enabled: !_submitting,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: _inputDecoration(
                                  hint: 'e.g. nasir@example.com',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LabeledField(
                              label: 'Mobile Number',
                              icon: Icons.phone_outlined,
                              errorText: _phoneError,
                              child: TextField(
                                controller: _phoneController,
                                enabled: !_submitting && !_phoneVerified,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                onChanged: (_) {
                                  if (_phoneVerified || _otpSent) {
                                    setState(_resetPhoneVerification);
                                  }
                                },
                                decoration: _inputDecoration(
                                  hint: '+919876543210',
                                  suffix: _phoneVerified
                                      ? const Icon(
                                          Icons.verified_rounded,
                                          color: _success,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_phoneVerified) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: (_sendingOtp ||
                                          _otpCooldown > 0 ||
                                          _submitting)
                                      ? null
                                      : _sendOtp,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _blue,
                                    side: const BorderSide(color: _blue),
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _sendingOtp
                                        ? 'Sending…'
                                        : (_otpCooldown > 0
                                            ? 'Resend in ${_otpCooldown}s'
                                            : (_otpSent
                                                ? 'Resend OTP'
                                                : 'Send OTP')),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (_otpSent) ...[
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'OTP code',
                                  icon: Icons.pin_outlined,
                                  errorText: _otpError,
                                  child: TextField(
                                    controller: _otpController,
                                    enabled:
                                        !_submitting && !_confirmingOtp,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    decoration: _inputDecoration(
                                      hint: 'Enter OTP',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed:
                                      (_confirmingOtp || _submitting)
                                          ? null
                                          : _confirmOtp,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _confirmingOtp
                                        ? 'Verifying…'
                                        : 'Verify mobile',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Mobile number verified',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _success,
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
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: _inputDecoration(
                                  hint: 'Create a strong password',
                                  suffix: IconButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
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
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _passwordController,
                              builder: (context, value, _) {
                                return _PasswordRequirements(
                                  password: value.text,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _LabeledField(
                              label: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              errorText: _confirmError,
                              child: TextField(
                                controller: _confirmController,
                                enabled: !_submitting,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: _inputDecoration(
                                  hint: 'Re-enter password',
                                  suffix: IconButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                              () => _obscureConfirm =
                                                  !_obscureConfirm,
                                            ),
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TermsRow(
                              accepted: _acceptTerms,
                              enabled: !_submitting,
                              errorText: _termsError,
                              onChanged: (value) => setState(
                                () => _acceptTerms = value ?? false,
                              ),
                              onTerms: () => _openConfigUrl(
                                AppConfig.instance.termsUrl,
                              ),
                              onPrivacy: () => _openConfigUrl(
                                AppConfig.instance.privacyUrl,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CreateAccountButton(
                              label: _submitting
                                  ? 'Creating account…'
                                  : 'Create account',
                              showArrow: !_submitting,
                              onPressed: _submitting ? null : _submit,
                            ),
                            const SizedBox(height: 18),
                            const _OrDivider(),
                            const SizedBox(height: 14),
                            _SocialRow(
                              narrow: narrow,
                              onGoogle: () => _socialStub('Google'),
                              onApple: () => _socialStub('Apple'),
                              onPhone: () => _socialStub('Phone'),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _muted,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: busy
                                        ? null
                                        : () {
                                            Navigator.of(context).pushNamed(
                                              AppRoutes.signIn,
                                            );
                                          },
                                    child: const Text(
                                      'Sign In',
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
    final blue = Paint()..color = const Color(0xFFDDEBFF).withValues(alpha: 0.7);
    final purple =
        Paint()..color = const Color(0xFFE8E0FF).withValues(alpha: 0.55);

    final topRight = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.08,
        size.width,
        size.height * 0.18,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topRight, blue);

    final bottomLeft = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.88,
        size.width * 0.42,
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

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: const Color(0xFFE2E8F0)),
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
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF7A8499)),
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
    final title = Text(
      'Create Your Account',
      softWrap: true,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: narrow ? 24 : 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: _RegisterScreenState._ink,
      ),
    );
    final subtitle = Text(
      'Join thousands of learners and start your preparation journey today.',
      softWrap: true,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: short ? 13 : 14,
        height: 1.4,
        color: _RegisterScreenState._muted,
        fontWeight: FontWeight.w500,
      ),
    );

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
        title,
        const SizedBox(height: 8),
        subtitle,
      ],
    );

    final hero = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: narrow ? 140 : 168,
        maxHeight: short ? 128 : 156,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          _RegisterScreenState._heroAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Student illustration',
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
            Icon(icon, size: 16, color: _RegisterScreenState._muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _RegisterScreenState._ink,
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

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('At least 8 characters', password.length >= 8),
      ('One number', RegExp(r'[0-9]').hasMatch(password)),
      ('One uppercase', RegExp(r'[A-Z]').hasMatch(password)),
      ('One special character', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
    ];

    Widget rowItem((String, bool) item) {
      final met = item.$2;
      final color = met
          ? _RegisterScreenState._success
          : const Color(0xFFA0AEC0);
      return Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.$1,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _RegisterScreenState._reqBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = constraints.maxWidth >= 280;
          if (!twoCol) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  rowItem(items[i]),
                ],
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: rowItem(items[0])),
                  const SizedBox(width: 8),
                  Expanded(child: rowItem(items[1])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: rowItem(items[2])),
                  const SizedBox(width: 8),
                  Expanded(child: rowItem(items[3])),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.accepted,
    required this.enabled,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
    this.errorText,
  });

  final bool accepted;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: accepted,
              activeColor: _RegisterScreenState._blue,
              onChanged: enabled ? onChanged : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'I agree to the ',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: _RegisterScreenState._ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: onTerms,
                      child: const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: _RegisterScreenState._blueDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      ' and ',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: _RegisterScreenState._ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: onPrivacy,
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: _RegisterScreenState._blueDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({
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
                ? _RegisterScreenState._blue
                : const Color(0xFFB8C0D6),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _RegisterScreenState._blue.withValues(alpha: 0.32),
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
        foregroundColor: _RegisterScreenState._ink,
        side: const BorderSide(color: _RegisterScreenState._fieldBorder),
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
          Icon(icon, size: 22, color: _RegisterScreenState._ink),
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
