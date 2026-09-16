import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/me/data/me_repository.dart';
import 'package:student_mobile/features/me/domain/me_models.dart';
import 'package:student_mobile/features/organization/presentation/screens/org_picker_screen.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

/// S-70 Me — profile summary, preferences, institute switch, sign out.
class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    this.meRepository,
  });

  final MeGateway? meRepository;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late final MeGateway _me = widget.meRepository ?? MeRepository();

  bool _loading = true;
  bool _savingNotify = false;
  bool _savingHours = false;
  bool _signingOut = false;
  String? _error;
  MeSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _me.loadMe();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load profile. Pull to retry.';
      });
    }
  }

  Future<void> _toggleEmail(bool enabled) async {
    final snapshot = _snapshot;
    final profileId = snapshot?.studentProfile?.id;
    if (snapshot == null || profileId == null || profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student profile is required to save notifications.'),
        ),
      );
      return;
    }
    setState(() {
      _savingNotify = true;
      _snapshot = snapshot.copyWith(emailNotificationsEnabled: enabled);
    });
    try {
      await _me.setEmailNotifications(
        studentProfileId: profileId,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() => _savingNotify = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingNotify = false;
        _snapshot = snapshot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save notification preference.")),
      );
    }
  }

  Future<void> _saveStudyHours(double hours) async {
    final snapshot = _snapshot;
    final profileId = snapshot?.studentProfile?.id;
    if (snapshot == null || profileId == null || profileId.isEmpty) return;
    setState(() {
      _savingHours = true;
      _snapshot = snapshot.copyWith(dailyStudyHours: hours);
    });
    try {
      await _me.setDailyStudyHours(
        studentProfileId: profileId,
        hours: hours,
      );
      if (!mounted) return;
      setState(() => _savingHours = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingHours = false;
        _snapshot = snapshot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save study hours.")),
      );
    }
  }

  Future<void> _switchInstitute() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const OrgPickerScreen(
          autoSelectSingle: false,
          allowBack: true,
          afterSelectRoute: AppRoutes.home,
          clearStackOnSelect: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
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
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await _me.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't sign out. Try again.")),
      );
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
          title: const Text('Me'),
          actions: [
            IconButton(
              tooltip: 'Quick search',
              onPressed: () => showQuickSearchSheet(context),
              icon: const Icon(Icons.search_rounded, color: AppColors.ink),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.brand)),
        ],
      );
    }

    if (_error != null && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
        ],
      );
    }

    final snapshot = _snapshot!;
    final profile = snapshot.studentProfile;
    final hoursLabel = snapshot.dailyStudyHours ==
            snapshot.dailyStudyHours.roundToDouble()
        ? snapshot.dailyStudyHours.round().toString()
        : snapshot.dailyStudyHours.toStringAsFixed(1);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        _ProfileHero(
          name: snapshot.displayName,
          email: snapshot.user.email,
          organizationName: snapshot.organizationName,
          studentCode: profile?.studentCode,
          status: profile?.status,
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Preferences'),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Email notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Tests, scores, and evaluation updates',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                value: snapshot.emailNotificationsEnabled,
                activeThumbColor: AppColors.brand,
                onChanged: (profile == null || _savingNotify)
                    ? null
                    : _toggleEmail,
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily study hours',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Used for planning tips',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_savingHours)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  else
                    Text(
                      hoursLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
              Slider(
                value: snapshot.dailyStudyHours.clamp(0, 16),
                min: 0,
                max: 16,
                divisions: 32,
                activeColor: AppColors.brand,
                label: hoursLabel,
                onChanged: profile == null || _savingHours
                    ? null
                    : (value) {
                        setState(() {
                          _snapshot = snapshot.copyWith(dailyStudyHours: value);
                        });
                      },
                onChangeEnd: profile == null || _savingHours
                    ? null
                    : _saveStudyHours,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Account'),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'AI Mentor',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Ask doubts and get study guidance',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.aiMentor),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.track_changes_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Weak Topics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Focus areas from your mastery map',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.weakTopics),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Study Planner',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Weekly plans, sessions, and goals',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.studyPlanner),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Recommendations',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'AI next actions from your learning signals',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.recommendations),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.collections_bookmark_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Notes & Bookmarks',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Notes, saved content, and AI feedback',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.notesBookmarks),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.insights_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'My Performance',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Scores, streak, and subject analytics',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.performance),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Exam Workspace',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Practice hub and exam readiness',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.examWorkspace),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.library_books_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Question Bank',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Exam series packs and included tests',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.examSeries),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'My Attendance',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Present, absent, and late marks',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.attendance),
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.apartment_outlined,
                  color: AppColors.brand,
                ),
                title: const Text(
                  'Switch institute',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  snapshot.organizationName?.isNotEmpty == true
                      ? snapshot.organizationName!
                      : 'Choose another academy',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _switchInstitute,
              ),
              const Divider(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  _signingOut ? 'Signing out…' : 'Sign out',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                onTap: _signingOut ? null : _signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    this.organizationName,
    this.studentCode,
    this.status,
  });

  final String name;
  final String email;
  final String? organizationName;
  final String? studentCode;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (studentCode != null && studentCode!.isNotEmpty) studentCode!,
      if (status != null && status!.isNotEmpty) status!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brandSoft,
            child: Text(
              _initialLetter(name),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          if (organizationName != null && organizationName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              organizationName!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta.join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: AppColors.muted,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brandSoft),
        ),
        child: child,
      ),
    );
  }
}

String _initialLetter(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
