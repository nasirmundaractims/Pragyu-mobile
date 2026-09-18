import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _blue = Color(0xFF4A7DFF);
  static const _purple = Color(0xFF7C5CFF);
  static const _fieldBorder = Color(0xFFE4E8F0);
  static const _cardShadow = Color(0xFF1A2B4C);

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

  static bool _isEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final appName = AppConfig.instance.appName;
    final busy = _submitting || _sendingOtp || _confirmingOtp;

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
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: _ink,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.signIn,
                                );
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: _purple,
                        ),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(appName: appName),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: _LabeledField(
                                        label: 'First name',
                                        errorText: _firstNameError,
                                        child: TextField(
                                          controller: _firstNameController,
                                          enabled: !_submitting,
                                          textInputAction:
                                              TextInputAction.next,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.givenName,
                                          ],
                                          decoration: _inputDecoration(
                                            hint: 'First',
                                            prefix: Icons.person_outline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _LabeledField(
                                        label: 'Last name',
                                        errorText: _lastNameError,
                                        child: TextField(
                                          controller: _lastNameController,
                                          enabled: !_submitting,
                                          textInputAction:
                                              TextInputAction.next,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.familyName,
                                          ],
                                          decoration: _inputDecoration(
                                            hint: 'Last',
                                            prefix: Icons.badge_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
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
                                      hint: 'you@email.com',
                                      prefix: Icons.mail_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Mobile number',
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
                                      prefix: Icons.phone_outlined,
                                      suffix: _phoneVerified
                                          ? const Icon(
                                              Icons.verified_rounded,
                                              color: Color(0xFF2EAE6B),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (!_phoneVerified) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: (_sendingOtp ||
                                                  _otpCooldown > 0 ||
                                                  _submitting)
                                              ? null
                                              : _sendOtp,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _purple,
                                            side: const BorderSide(
                                              color: _purple,
                                            ),
                                            minimumSize:
                                                const Size.fromHeight(44),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
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
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 12),
                                    _LabeledField(
                                      label: 'OTP code',
                                      errorText: _otpError,
                                      child: TextField(
                                        controller: _otpController,
                                        enabled: !_submitting &&
                                            !_confirmingOtp,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode,
                                        ],
                                        decoration: _inputDecoration(
                                          hint: 'Enter OTP',
                                          prefix: Icons.pin_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton(
                                      onPressed: (_confirmingOtp ||
                                              _submitting)
                                          ? null
                                          : _confirmOtp,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _blue,
                                        minimumSize:
                                            const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Text(
                                        _confirmingOtp
                                            ? 'Verifying…'
                                            : 'Verify mobile',
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
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2EAE6B),
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
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    decoration: _inputDecoration(
                                      hint: 'Create a strong password',
                                      prefix: Icons.lock_outline_rounded,
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
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Confirm password',
                                  errorText: _confirmError,
                                  child: TextField(
                                    controller: _confirmController,
                                    enabled: !_submitting,
                                    obscureText: _obscureConfirm,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    decoration: _inputDecoration(
                                      hint: 'Re-enter password',
                                      prefix: Icons.lock_outline_rounded,
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
                                const SizedBox(height: 8),
                                const Text(
                                  'Use 8+ characters with upper, lower, number, and special character.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _acceptTerms,
                                      activeColor: _blue,
                                      onChanged: _submitting
                                          ? null
                                          : (value) => setState(
                                                () => _acceptTerms =
                                                    value ?? false,
                                              ),
                                    ),
                                    const Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Text(
                                          'I agree to the Terms of Service and Privacy Policy',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            color: _ink,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_termsError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      _termsError!,
                                      style: const TextStyle(
                                        color: Color(0xFFC0392B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                _GradientButton(
                                  label: _submitting
                                      ? 'Creating account…'
                                      : 'Create account',
                                  showArrow: !_submitting,
                                  onPressed: _submitting ? null : _submit,
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _muted,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: busy
                                            ? null
                                            : () {
                                                Navigator.of(context)
                                                    .pushNamed(
                                                  AppRoutes.signIn,
                                                );
                                              },
                                        child: const Text(
                                          'Sign in',
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
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Together for a Smarter Future',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA0A8B8),
                              fontWeight: FontWeight.w500,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PragyuLogo(height: 36),
        const SizedBox(height: 14),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: _RegisterScreenState._ink,
            ),
            children: [
              TextSpan(text: 'Create your '),
              TextSpan(
                text: 'account',
                style: TextStyle(color: _RegisterScreenState._purple),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join as a student — verify your mobile, set a password, and start learning.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            height: 1.4,
            color: _RegisterScreenState._muted,
          ),
        ),
      ],
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
            color: _RegisterScreenState._ink,
          ),
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
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      _RegisterScreenState._purple,
                      _RegisterScreenState._blue,
                    ]
                  : const [
                      Color(0xFFB8C0D6),
                      Color(0xFFA8B4CC),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _RegisterScreenState._purple
                          .withValues(alpha: 0.28),
                      blurRadius: 16,
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
