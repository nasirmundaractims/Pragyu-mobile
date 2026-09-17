import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        title: const Text('Logout?'),
        content: const Text(
          "You'll need to sign in again to access your courses and tests.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
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
        AppRoutes.welcome,
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Settings'),
        ),
        body: SafeArea(
          child: !_ready && _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : !_ready && _error != null
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Password, sessions, language, and trusted devices.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PasswordCard(
                              currentController: _currentPassword,
                              newController: _newPassword,
                              confirmController: _confirmPassword,
                              saving: _savingPassword,
                              onSubmit: _submitPassword,
                            ),
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            _SessionsCard(
                              sessions: _snapshot.sessions,
                              unavailable: _snapshot.sessionsUnavailable,
                              busySessionId: _busySessionId,
                              revokingOthers: _revokingOthers,
                              onRevoke: _revokeSession,
                              onRevokeOthers: _revokeOthers,
                            ),
                            const SizedBox(height: 14),
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
                                      ? AppColors.muted
                                      : AppColors.danger,
                                ),
                                label: Text(
                                  _loggingOut ? 'Logging out…' : 'Logout',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _loggingOut
                                        ? AppColors.muted
                                        : AppColors.danger,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _loggingOut
                                        ? AppColors.muted
                                            .withValues(alpha: 0.4)
                                        : AppColors.danger
                                            .withValues(alpha: 0.55),
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
      title: 'Change password',
      subtitle: 'Update your sign-in password.',
      child: Column(
        children: [
          _PasswordField(controller: currentController, label: 'Current password'),
          const SizedBox(height: 10),
          _PasswordField(controller: newController, label: 'New password'),
          const SizedBox(height: 10),
          _PasswordField(
            controller: confirmController,
            label: 'Confirm new password',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: Text(saving ? 'Updating…' : 'Update password'),
            ),
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
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      title: 'Language & timezone',
      subtitle: 'Used across your profile and study tools.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: localeValue,
            decoration: InputDecoration(
              labelText: 'Language',
              filled: true,
              fillColor: AppColors.background,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
            decoration: InputDecoration(
              labelText: 'Timezone',
              filled: true,
              fillColor: AppColors.background,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              for (final option in timezoneItems)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              if (value != null) onTimezoneChanged(value);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : onSave,
              child: Text(saving ? 'Saving…' : 'Save locale'),
            ),
          ),
        ],
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
      title: 'Active sessions',
      subtitle: 'Review and revoke signed-in sessions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: revokingOthers ? null : onRevokeOthers,
              child: Text(
                revokingOthers ? 'Signing out…' : 'Sign out other devices',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (unavailable)
            const Text(
              'Sessions are unavailable.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else if (sessions.isEmpty)
            const Text(
              'No sessions returned.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            for (var i = 0; i < sessions.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessions[i].title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sessions[i].subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: busySessionId == sessions[i].id
                        ? null
                        : () => onRevoke(sessions[i]),
                    child: Text(
                      busySessionId == sessions[i].id ? '…' : 'Revoke',
                    ),
                  ),
                ],
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
      title: 'Trusted devices',
      subtitle: 'Devices remembered for sign-in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unavailable)
            const Text(
              'Devices are unavailable.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else if (devices.isEmpty)
            const Text(
              'No trusted devices yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            for (var i = 0; i < devices.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          devices[i].name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          devices[i].subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: busyDeviceId == devices[i].id
                        ? null
                        : () => onRevoke(devices[i]),
                    child: Text(
                      busyDeviceId == devices[i].id ? '…' : 'Revoke',
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
