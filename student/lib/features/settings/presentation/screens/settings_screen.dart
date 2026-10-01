import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/me/data/me_repository.dart';
import 'package:student_mobile/features/settings/data/settings_repository.dart';
import 'package:student_mobile/features/settings/domain/settings_models.dart';

/// S-71 Settings — password, sessions, language, and devices.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.settingsRepository,
    this.meRepository,
  });

  final SettingsGateway? settingsRepository;
  final MeGateway? meRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsGateway _repo =
      widget.settingsRepository ?? SettingsRepository();
  late final MeGateway _me = widget.meRepository ?? MeRepository();

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = true;
  bool _savingPassword = false;
  bool _savingLocale = false;
  bool _revokingOthers = false;
  bool _loggingOut = false;
  bool _ready = false;
  String? _busySessionId;
  String? _busyDeviceId;
  String? _error;
  SettingsSnapshot _snapshot = const SettingsSnapshot();
  late String _locale;
  late String _timezone;

  @override
  void initState() {
    super.initState();
    _locale = _snapshot.localeTimezone.locale;
    _timezone = _snapshot.localeTimezone.timezone;
    _load();
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _repo.loadSettings();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _locale = snapshot.localeTimezone.locale;
        _timezone = snapshot.localeTimezone.timezone;
        _loading = false;
        _ready = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load settings.';
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitPassword() async {
    if (_savingPassword) return;
    setState(() => _savingPassword = true);
    try {
      await _repo.changePassword(
        PasswordChangeRequest(
          currentPassword: _currentPassword.text,
          password: _newPassword.text,
          passwordConfirmation: _confirmPassword.text,
        ),
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _toast('Password updated.');
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Unable to change password.',
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _saveLocale() async {
    if (_savingLocale) return;
    setState(() => _savingLocale = true);
    try {
      await _repo.saveLocaleTimezone(
        LocaleTimezoneSettings(locale: _locale, timezone: _timezone),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = SettingsSnapshot(
          localeTimezone:
              LocaleTimezoneSettings(locale: _locale, timezone: _timezone),
          sessions: _snapshot.sessions,
          devices: _snapshot.devices,
          sessionsUnavailable: _snapshot.sessionsUnavailable,
          devicesUnavailable: _snapshot.devicesUnavailable,
        );
      });
      _toast('Locale and timezone saved.');
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException
            ? error.message
            : "Couldn't save locale settings.",
      );
    } finally {
      if (mounted) setState(() => _savingLocale = false);
    }
  }

  Future<void> _revokeSession(AuthSessionItem item) async {
    setState(() => _busySessionId = item.id);
    try {
      await _repo.revokeSession(item.id);
      if (!mounted) return;
      setState(() {
        _snapshot = SettingsSnapshot(
          localeTimezone: _snapshot.localeTimezone,
          sessions:
              _snapshot.sessions.where((s) => s.id != item.id).toList(),
          devices: _snapshot.devices,
          sessionsUnavailable: _snapshot.sessionsUnavailable,
          devicesUnavailable: _snapshot.devicesUnavailable,
        );
      });
      _toast('Session revoked.');
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Unable to revoke session.',
      );
    } finally {
      if (mounted) setState(() => _busySessionId = null);
    }
  }

  Future<void> _revokeOthers() async {
    if (_revokingOthers) return;
    setState(() => _revokingOthers = true);
    try {
      await _repo.revokeOtherSessions();
      if (!mounted) return;
      _toast('Other sessions signed out.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException
            ? error.message
            : 'Unable to sign out other sessions.',
      );
    } finally {
      if (mounted) setState(() => _revokingOthers = false);
    }
  }

  Future<void> _revokeDevice(TrustedDeviceItem item) async {
    setState(() => _busyDeviceId = item.id);
    try {
      await _repo.revokeDevice(item.id);
      if (!mounted) return;
      setState(() {
        _snapshot = SettingsSnapshot(
          localeTimezone: _snapshot.localeTimezone,
          sessions: _snapshot.sessions,
          devices: _snapshot.devices.where((d) => d.id != item.id).toList(),
          sessionsUnavailable: _snapshot.sessionsUnavailable,
          devicesUnavailable: _snapshot.devicesUnavailable,
        );
      });
      _toast('Device removed.');
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Unable to revoke device.',
      );
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w800,
            color: StudentHubColors.ink,
          ),
        ),
        content: const Text(
          "You'll need to sign in again to access your courses and tests.",
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: StudentHubColors.muted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: StudentHubColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await _me.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      _toast("Couldn't log out. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Settings',
        body: !_ready && _loading
            ? const AppLoadingState(padding: EdgeInsets.zero)
            : !_ready && _error != null
                ? Center(
                    child: AppErrorState(
                      message: _error!,
                      onRetry: _load,
                      retryLabel: 'Retry',
                    ),
                  )
                : RefreshIndicator(
                    color: StudentHubColors.blue,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _IntroCard(),
                          const SizedBox(height: 18),
                          _PasswordCard(
                            currentController: _currentPassword,
                            newController: _newPassword,
                            confirmController: _confirmPassword,
                            saving: _savingPassword,
                            onSubmit: _submitPassword,
                          ),
                          const SizedBox(height: 12),
                          _LocaleCard(
                            locale: _locale,
                            timezone: _timezone,
                            saving: _savingLocale,
                            onLocaleChanged: (value) =>
                                setState(() => _locale = value),
                            onTimezoneChanged: (value) =>
                                setState(() => _timezone = value),
                            onSave: _saveLocale,
                          ),
                          const SizedBox(height: 12),
                          _SessionsCard(
                            sessions: _snapshot.sessions,
                            unavailable: _snapshot.sessionsUnavailable,
                            busySessionId: _busySessionId,
                            revokingOthers: _revokingOthers,
                            onRevoke: _revokeSession,
                            onRevokeOthers: _revokeOthers,
                          ),
                          const SizedBox(height: 12),
                          _DevicesCard(
                            devices: _snapshot.devices,
                            unavailable: _snapshot.devicesUnavailable,
                            busyDeviceId: _busyDeviceId,
                            onRevoke: _revokeDevice,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _loggingOut ? null : _logout,
                              icon: Icon(
                                Icons.logout_rounded,
                                color: _loggingOut
                                    ? StudentHubColors.muted
                                    : StudentHubColors.danger,
                              ),
                              label: Text(
                                _loggingOut ? 'Logging out…' : 'Logout',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _loggingOut
                                      ? StudentHubColors.muted
                                      : StudentHubColors.danger,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _loggingOut
                                      ? StudentHubColors.muted
                                          .withValues(alpha: 0.4)
                                      : StudentHubColors.danger
                                          .withValues(alpha: 0.45),
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconWell(
            icon: Icons.settings_outlined,
            tint: Color(0xFF22A06B),
            soft: Color(0xFFE8F8F0),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your account secure',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: StudentHubColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Password, sessions, language, and trusted devices.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    height: 1.4,
                    color: StudentHubColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.saving,
    required this.onSubmit,
  });

  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.lock_outline_rounded,
      tint: StudentHubColors.blue,
      soft: StudentHubColors.blueSoft,
      title: 'Change password',
      subtitle: 'Update your sign-in password.',
      child: Column(
        children: [
          _PasswordField(
            controller: currentController,
            label: 'Current password',
          ),
          const SizedBox(height: 10),
          _PasswordField(controller: newController, label: 'New password'),
          const SizedBox(height: 10),
          _PasswordField(
            controller: confirmController,
            label: 'Confirm new password',
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: saving ? 'Updating…' : 'Update password',
            onPressed: saving ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: StudentHubColors.ink,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: StudentHubColors.muted,
        ),
        filled: true,
        fillColor: StudentHubColors.pageBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StudentHubColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StudentHubColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: StudentHubColors.blue, width: 1.5),
        ),
      ),
    );
  }
}

class _LocaleCard extends StatelessWidget {
  const _LocaleCard({
    required this.locale,
    required this.timezone,
    required this.saving,
    required this.onLocaleChanged,
    required this.onTimezoneChanged,
    required this.onSave,
  });

  final String locale;
  final String timezone;
  final bool saving;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onTimezoneChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final localeValue = kLocaleOptions.any((o) => o.$1 == locale)
        ? locale
        : kLocaleOptions.first.$1;
    final timezoneValue = kTimezoneOptions.contains(timezone)
        ? timezone
        : (timezone.isEmpty ? kTimezoneOptions.first : timezone);
    final timezoneItems = {
      ...kTimezoneOptions,
      if (!kTimezoneOptions.contains(timezone) && timezone.isNotEmpty) timezone,
    }.toList();

    return _SectionCard(
      icon: Icons.language_rounded,
      tint: const Color(0xFFF08A3C),
      soft: const Color(0xFFFFF2E8),
      title: 'Language & timezone',
      subtitle: 'Used across your profile and study tools.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: localeValue,
            decoration: _fieldDecoration('Language'),
            items: [
              for (final option in kLocaleOptions)
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
            ],
            onChanged: (value) {
              if (value != null) onLocaleChanged(value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: timezoneValue,
            decoration: _fieldDecoration('Timezone'),
            items: [
              for (final option in timezoneItems)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              if (value != null) onTimezoneChanged(value);
            },
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            label: saving ? 'Saving…' : 'Save locale',
            onPressed: saving ? null : onSave,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: StudentHubColors.muted,
      ),
      filled: true,
      fillColor: StudentHubColors.pageBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentHubColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentHubColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentHubColors.blue, width: 1.5),
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({
    required this.sessions,
    required this.unavailable,
    required this.busySessionId,
    required this.revokingOthers,
    required this.onRevoke,
    required this.onRevokeOthers,
  });

  final List<AuthSessionItem> sessions;
  final bool unavailable;
  final String? busySessionId;
  final bool revokingOthers;
  final ValueChanged<AuthSessionItem> onRevoke;
  final VoidCallback onRevokeOthers;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.devices_rounded,
      tint: const Color(0xFF7B61FF),
      soft: const Color(0xFFF0EBFF),
      title: 'Active sessions',
      subtitle: 'Review and revoke signed-in sessions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: revokingOthers ? null : onRevokeOthers,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: Text(
                revokingOthers ? 'Signing out…' : 'Sign out other devices',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: StudentHubColors.ink,
                side: const BorderSide(color: StudentHubColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (unavailable)
            const _EmptyHint('Sessions are unavailable.')
          else if (sessions.isEmpty)
            const _EmptyHint('No sessions returned.')
          else
            for (var i = 0; i < sessions.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ListRow(
                title: sessions[i].title,
                subtitle: sessions[i].subtitle,
                busy: busySessionId == sessions[i].id,
                onRevoke: () => onRevoke(sessions[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({
    required this.devices,
    required this.unavailable,
    required this.busyDeviceId,
    required this.onRevoke,
  });

  final List<TrustedDeviceItem> devices;
  final bool unavailable;
  final String? busyDeviceId;
  final ValueChanged<TrustedDeviceItem> onRevoke;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.phonelink_lock_rounded,
      tint: const Color(0xFFE85D75),
      soft: const Color(0xFFFFEEF1),
      title: 'Trusted devices',
      subtitle: 'Devices remembered for sign-in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unavailable)
            const _EmptyHint('Devices are unavailable.')
          else if (devices.isEmpty)
            const _EmptyHint('No trusted devices yet.')
          else
            for (var i = 0; i < devices.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ListRow(
                title: devices[i].name,
                subtitle: devices[i].subtitle,
                busy: busyDeviceId == devices[i].id,
                onRevoke: () => onRevoke(devices[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onRevoke,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: StudentHubColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: StudentHubColors.ink,
                    fontSize: 14,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: StudentHubColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRevoke,
            style: TextButton.styleFrom(
              foregroundColor: StudentHubColors.danger,
            ),
            child: Text(
              busy ? '…' : 'Revoke',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: StudentHubColors.muted,
        fontSize: 13,
        height: 1.35,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.tint,
    required this.soft,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color tint;
  final Color soft;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconWell(icon: icon, tint: tint, soft: soft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        height: 1.35,
                        color: StudentHubColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.tint,
    required this.soft,
  });

  final IconData icon;
  final Color tint;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: tint, size: 20),
    );
  }
}
